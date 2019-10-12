import AVFoundation

public protocol AudioConverterDelegate: class {
    func didSetFormatDescription(audio formatDescription: CMFormatDescription?)
    func sampleOutput(audio data: UnsafeMutableAudioBufferListPointer, presentationTimeStamp: CMTime)
}

// MARK: -
/**
 - seealse:
  - https://developer.apple.com/library/ios/technotes/tn2236/_index.html
 */
public class AudioConverter {
    enum Error: Swift.Error {
        case setPropertyError(id: AudioConverterPropertyID, status: OSStatus)
    }

    public enum Option: String, KeyPathRepresentable {
        case muted
        case bitrate
        case sampleRate
        case actualBitrate

        public var keyPath: AnyKeyPath {
            switch self {
            case .muted:
                return \AudioConverter.muted
            case .bitrate:
                return \AudioConverter.bitrate
            case .sampleRate:
                return \AudioConverter.sampleRate
            case .actualBitrate:
                return \AudioConverter.actualBitrate
            }
        }
    }

    public static let minimumBitrate: UInt32 = 8 * 1024
    public static let defaultBitrate: UInt32 = 32 * 1024
    /// 0 means according to a input source
    public static let defaultChannels: UInt32 = 0
    /// 0 means according to a input source
    public static let defaultSampleRate: Double = 0
    public static let defaultMaximumBuffers: Int = 1
    public static let defaultBufferListSize: Int = AudioBufferList.sizeInBytes(maximumBuffers: 1)

    public var destination: Destination = .AAC
    public weak var delegate: AudioConverterDelegate?
    public private(set) var isRunning: Atomic<Bool> = .init(false)
    public var settings: Setting<AudioConverter, Option> = [:] {
        didSet {
            settings.observer = self
        }
    }

    var muted: Bool = false
    var bitrate: UInt32 = AudioConverter.defaultBitrate {
        didSet {
            guard bitrate != oldValue else {
                return
            }
            lockQueue.async {
                if let format = self._inDestinationFormat {
                    self.setBitrateUntilNoErr(self.bitrate * format.mChannelsPerFrame)
                }
            }
        }
    }
    var sampleRate: Double = AudioConverter.defaultSampleRate
    var actualBitrate: UInt32 = AudioConverter.defaultBitrate {
        didSet {
            logger.info(actualBitrate)
        }
    }
    var channels: UInt32 = AudioConverter.defaultChannels
    var formatDescription: CMFormatDescription? {
        didSet {
            if !CMFormatDescriptionEqual(formatDescription, otherFormatDescription: oldValue) {
                delegate?.didSetFormatDescription(audio: formatDescription)
            }
        }
    }
    var lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioConverter.lock")
    var inSourceFormat: AudioStreamBasicDescription? {
        didSet {
            logger.info("\(String(describing: self.inSourceFormat))")
            guard let inSourceFormat: AudioStreamBasicDescription = self.inSourceFormat else {
                return
            }
            let nonInterleaved: Bool = inSourceFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
            maximumBuffers = nonInterleaved ? Int(inSourceFormat.mChannelsPerFrame) : AudioConverter.defaultMaximumBuffers
            bufferListSize = nonInterleaved ? AudioBufferList.sizeInBytes(maximumBuffers: maximumBuffers) : AudioConverter.defaultBufferListSize
        }
    }
    var effects: Set<AudioEffect> = []
    private var maximumBuffers: Int = AudioConverter.defaultMaximumBuffers {
        didSet {
            guard oldValue != maximumBuffers else {
                return
            }
            currentBufferList.unsafeMutablePointer.deallocate()
            currentBufferList = AudioBufferList.allocate(maximumBuffers: maximumBuffers)
        }
    }
    private var filled = false
    private var bufferListSize: Int = AudioConverter.defaultBufferListSize
    private lazy var currentBufferList: UnsafeMutableAudioBufferListPointer = {
        AudioBufferList.allocate(maximumBuffers: maximumBuffers)
    }()
    private var _inDestinationFormat: AudioStreamBasicDescription?
    private var inDestinationFormat: AudioStreamBasicDescription {
        get {
            if _inDestinationFormat == nil {
                _inDestinationFormat = destination.audioStreamBasicDescription(inSourceFormat, sampleRate: sampleRate, channels: channels)
                CMAudioFormatDescriptionCreate(
                    allocator: kCFAllocatorDefault,
                    asbd: &_inDestinationFormat!,
                    layoutSize: 0,
                    layout: nil,
                    magicCookieSize: 0,
                    magicCookie: nil,
                    extensions: nil,
                    formatDescriptionOut: &formatDescription
                )
            }
            return _inDestinationFormat!
        }
        set {
            _inDestinationFormat = newValue
        }
    }

    private var audioStreamPacketDescription = AudioStreamPacketDescription(mStartOffset: 0, mVariableFramesInPacket: 0, mDataByteSize: 0) {
        didSet {
            audioStreamPacketDescriptionPointer = UnsafeMutablePointer<AudioStreamPacketDescription>(mutating: &audioStreamPacketDescription)
        }
    }
    private var audioStreamPacketDescriptionPointer: UnsafeMutablePointer<AudioStreamPacketDescription>?

    private let inputDataProc: AudioConverterComplexInputDataProc = {(
        converter: AudioConverterRef,
        ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
        ioData: UnsafeMutablePointer<AudioBufferList>,
        outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
        inUserData: UnsafeMutableRawPointer?) in
        Unmanaged<AudioConverter>.fromOpaque(inUserData!).takeUnretainedValue().onInputDataForAudioConverter(
            ioNumberDataPackets,
            ioData: ioData,
            outDataPacketDescription: outDataPacketDescription
        )
    }

    public init() {
        settings.observer = self
    }

    deinit {
        currentBufferList.unsafeMutablePointer.deallocate()
    }

    private var _converter: AudioConverterRef?
    private var converter: AudioConverterRef {
        var status: OSStatus = noErr
        if _converter == nil {
            var inClassDescriptions = destination.inClassDescriptions
            status = AudioConverterNewSpecific(
                &inSourceFormat!,
                &inDestinationFormat,
                UInt32(inClassDescriptions.count),
                &inClassDescriptions,
                &_converter
            )
            setBitrateUntilNoErr(bitrate * inDestinationFormat.mChannelsPerFrame)
        }
        if status != noErr {
            logger.warn("\(status)")
        }
        return _converter!
    }

    public func encodeBytes(_ bytes: UnsafeMutableRawPointer?, count: Int, presentationTimeStamp: CMTime) {
        currentBufferList.unsafeMutablePointer.pointee.mBuffers.mNumberChannels = 1
        currentBufferList.unsafeMutablePointer.pointee.mBuffers.mData = bytes
        currentBufferList.unsafeMutablePointer.pointee.mBuffers.mDataByteSize = UInt32(count)
        convert(Int(1024 * destination.bytesPerFrame), presentationTimeStamp: presentationTimeStamp)
    }

    public func encodeSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let format: CMAudioFormatDescription = sampleBuffer.formatDescription, isRunning.value else {
            return
        }

        if inSourceFormat == nil {
            inSourceFormat = format.streamBasicDescription?.pointee
        }

        var blockBuffer: CMBlockBuffer?
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: currentBufferList.unsafeMutablePointer,
            bufferListSize: bufferListSize,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        if blockBuffer == nil {
            logger.warn("IllegalState for blockBuffer")
            return
        }

        if !effects.isEmpty {
            for effect in effects {
                effect.execute(currentBufferList, format: inSourceFormat)
            }
        }

        if muted {
            for i in 0..<currentBufferList.count {
                memset(currentBufferList[i].mData, 0, Int(currentBufferList[i].mDataByteSize))
            }
        }

        convert(blockBuffer!.dataLength, presentationTimeStamp: sampleBuffer.presentationTimeStamp)
    }

    @inline(__always)
    private func convert(_ dataBytesSize: Int, presentationTimeStamp: CMTime) {
        filled = false
        var finished: Bool = false
        repeat {
            var ioOutputDataPacketSize: UInt32 = destination.packetSize

            let mamimumBuffers = destination.mamimumBuffers((channels == 0) ? inSourceFormat?.mChannelsPerFrame ?? 1 : channels)
            let outOutputData: UnsafeMutableAudioBufferListPointer = AudioBufferList.allocate(maximumBuffers: mamimumBuffers)
            for i in 0..<mamimumBuffers {
                outOutputData[i].mNumberChannels = inDestinationFormat.mChannelsPerFrame
                outOutputData[i].mDataByteSize = UInt32(dataBytesSize)
                outOutputData[i].mData = UnsafeMutableRawPointer.allocate(byteCount: dataBytesSize, alignment: 0)
            }

            let status: OSStatus = AudioConverterFillComplexBuffer(
                converter,
                inputDataProc,
                Unmanaged.passUnretained(self).toOpaque(),
                &ioOutputDataPacketSize,
                outOutputData.unsafeMutablePointer,
                nil
            )

            switch status {
            // kAudioConverterErr_InvalidInputSize: perhaps mistake. but can support macOS BuiltIn Mic #61
            case noErr, kAudioConverterErr_InvalidInputSize:
                delegate?.sampleOutput(
                    audio: outOutputData,
                    presentationTimeStamp: presentationTimeStamp
                )
            case -1:
                if destination == .PCM {
                    delegate?.sampleOutput(
                        audio: outOutputData,
                        presentationTimeStamp: presentationTimeStamp
                    )
                }
                finished = true
            default:
                finished = true
            }

            for i in 0..<outOutputData.count {
                free(outOutputData[i].mData)
            }

            free(outOutputData.unsafeMutablePointer)
        } while !finished
    }

    func invalidate() {
        lockQueue.async {
            self.inSourceFormat = nil
            self._inDestinationFormat = nil
            if let converter: AudioConverterRef = self._converter {
                AudioConverterDispose(converter)
            }
            self._converter = nil
        }
    }

    func onInputDataForAudioConverter(
        _ ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
        ioData: UnsafeMutablePointer<AudioBufferList>,
        outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?) -> OSStatus {
        guard !filled else {
            ioNumberDataPackets.pointee = 0
            return -1
        }

        memcpy(ioData, currentBufferList.unsafePointer, bufferListSize)
        ioNumberDataPackets.pointee = 1

        if destination == .PCM && outDataPacketDescription != nil {
            audioStreamPacketDescription.mDataByteSize = currentBufferList.unsafePointer.pointee.mBuffers.mDataByteSize
            outDataPacketDescription?.pointee = audioStreamPacketDescriptionPointer
        }
        filled = true

        return noErr
    }

    private func setBitrateUntilNoErr(_ bitrate: UInt32) {
        do {
            try setProperty(id: kAudioConverterEncodeBitRate, data: bitrate * inDestinationFormat.mChannelsPerFrame)
            actualBitrate = bitrate
        } catch {
            if AudioConverter.minimumBitrate < bitrate {
                setBitrateUntilNoErr(bitrate - AudioConverter.minimumBitrate)
            } else {
                actualBitrate = AudioConverter.minimumBitrate
            }
        }
    }

    private func setProperty<T>(id: AudioConverterPropertyID, data: T) throws {
        guard let converter: AudioConverterRef = _converter else {
            return
        }
        let size = UInt32(MemoryLayout<T>.size)
        var buffer = data
        let status = AudioConverterSetProperty(converter, id, size, &buffer)
        guard status == 0 else {
            throw Error.setPropertyError(id: id, status: status)
        }
    }
}

extension AudioConverter: Running {
    // MARK: Running
    public func startRunning() {
        lockQueue.async {
            self.isRunning.mutate { $0 = true }
        }
    }

    public func stopRunning() {
        lockQueue.async {
            if let convert: AudioQueueRef = self._converter {
                AudioConverterDispose(convert)
                self._converter = nil
            }
            self.inSourceFormat = nil
            self.formatDescription = nil
            self._inDestinationFormat = nil
            self.isRunning.mutate { $0 = false }
        }
    }
}
