import AVFoundation

/**
 * The interface a AudioCodec uses to inform its delegate.
 */
public protocol AudioCodecDelegate: AnyObject {
    /// Tells the receiver to set a formatDescription.
    func audioCodec(_ codec: AudioCodec, didSet formatDescription: CMFormatDescription?)
    /// Tells the receiver to output a encoded or decoded sampleBuffer.
    func audioCodec(_ codec: AudioCodec, didOutput sample: UnsafeMutableAudioBufferListPointer, presentationTimeStamp: CMTime)
}

// MARK: -
/**
 * The AudioCodec translate audio data to another format.
 * - seealso: https://developer.apple.com/library/ios/technotes/tn2236/_index.html
 */
public class AudioCodec {
    /// The AudioCodec  error domain codes.
    enum Error: Swift.Error {
        case setPropertyError(id: AudioConverterPropertyID, status: OSStatus)
    }

    /// The default minimum bitrate for an AudioCodec, value is 8000.
    public static let minimumBitrate: UInt32 = 8 * 1000
    /// The default channels for an AudioCodec, the value is 0 means  according to a input source.
    public static let defaultChannels: UInt32 = 0
    /// The default sampleRate for an AudioCodec, the value is 0 means according to a input source.
    public static let defaultSampleRate: Double = 0
    /// The default mamimu buffers for an AudioCodec.
    public static let defaultMaximumBuffers: Int = 1

    private static let numSamples: Int = 1024

    /// Specifies the output format.
    public var destination: AudioCodecFormat = .aac
    /// Specifies the delegate.
    public weak var delegate: AudioCodecDelegate?
    public private(set) var isRunning: Atomic<Bool> = .init(false)
    /// Specifies the settings for audio codec.
    public var settings: AudioCodecSettings = .default {
        didSet {
            if settings.bitRate != oldValue.bitRate {
                lockQueue.async {
                    if let format = self._inDestinationFormat {
                        self.setBitrateUntilNoErr(self.settings.bitRate * format.mChannelsPerFrame)
                    }
                }
            }
        }
    }

    var sampleRate: Double = AudioCodec.defaultSampleRate
    var actualBitrate: UInt32 = AudioCodecSettings.default.bitRate {
        didSet {
            logger.info(actualBitrate)
        }
    }
    var channels: UInt32 = AudioCodec.defaultChannels
    var formatDescription: CMFormatDescription? {
        didSet {
            guard !CMFormatDescriptionEqual(formatDescription, otherFormatDescription: oldValue) else {
                return
            }
            logger.info(formatDescription.debugDescription)
            delegate?.audioCodec(self, didSet: formatDescription)
        }
    }
    var lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioConverter.lock")
    var inSourceFormat: AudioStreamBasicDescription? {
        didSet {
            guard let inSourceFormat = inSourceFormat, inSourceFormat != oldValue else {
                return
            }
            _converter = nil
            formatDescription = nil
            _inDestinationFormat = nil
            logger.info("\(String(describing: inSourceFormat))")
            let nonInterleaved = inSourceFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
            maximumBuffers = nonInterleaved ? Int(inSourceFormat.mChannelsPerFrame) : AudioCodec.defaultMaximumBuffers
            currentAudioBuffer = AudioCodecBuffer(inSourceFormat, numSamples: AudioCodec.numSamples)
        }
    }
    var effects: Set<AudioEffect> = []
    private let numSamples = AudioCodec.numSamples
    private var maximumBuffers: Int = AudioCodec.defaultMaximumBuffers
    private var currentAudioBuffer = AudioCodecBuffer(AudioStreamBasicDescription(mSampleRate: 0, mFormatID: 0, mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: 0, mBytesPerFrame: 0, mChannelsPerFrame: 1, mBitsPerChannel: 0, mReserved: 0))
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

    private var audioStreamPacketDescription = AudioStreamPacketDescription(mStartOffset: 0, mVariableFramesInPacket: 0, mDataByteSize: 0)
    private let inputDataProc: AudioConverterComplexInputDataProc = {(_: AudioConverterRef, ioNumberDataPackets: UnsafeMutablePointer<UInt32>, ioData: UnsafeMutablePointer<AudioBufferList>, outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?, inUserData: UnsafeMutableRawPointer?) in
        Unmanaged<AudioCodec>.fromOpaque(inUserData!).takeUnretainedValue().onInputDataForAudioConverter(
            ioNumberDataPackets,
            ioData: ioData,
            outDataPacketDescription: outDataPacketDescription
        )
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
            setBitrateUntilNoErr(settings.bitRate * inDestinationFormat.mChannelsPerFrame)
        }
        if status != noErr {
            logger.warn("\(status)")
        }
        return _converter!
    }

    /// Encodes bytes data.
    public func encodeBytes(_ bytes: UnsafeMutableRawPointer?, count: Int, presentationTimeStamp: CMTime) {
        guard isRunning.value else {
            currentAudioBuffer.clear()
            return
        }
        currentAudioBuffer.write(bytes, count: count, presentationTimeStamp: presentationTimeStamp)
        convert(numSamples * Int(destination.bytesPerFrame), presentationTimeStamp: presentationTimeStamp)
    }

    /// Encodes a CMSampleBuffer.
    public func encodeSampleBuffer(_ sampleBuffer: CMSampleBuffer, offset: Int = 0) {
        guard let format = sampleBuffer.formatDescription, CMSampleBufferDataIsReady(sampleBuffer) else {
            currentAudioBuffer.clear()
            return
        }
        inSourceFormat = format.streamBasicDescription?.pointee
        guard isRunning.value else {
            return
        }
        do {
            let numSamples = try currentAudioBuffer.write(sampleBuffer, offset: offset)
            if currentAudioBuffer.isReady {
                for effect in effects {
                    effect.execute(currentAudioBuffer.input, format: inSourceFormat)
                }
                convert(currentAudioBuffer.maxLength, presentationTimeStamp: currentAudioBuffer.presentationTimeStamp)
            }
            if offset + numSamples < sampleBuffer.numSamples {
                encodeSampleBuffer(sampleBuffer, offset: offset + numSamples)
            }
        } catch {
            logger.error(error)
        }
    }

    @inline(__always)
    private func convert(_ dataBytesSize: Int, presentationTimeStamp: CMTime) {
        var finished = false
        repeat {
            var ioOutputDataPacketSize: UInt32 = destination.packetSize

            let maximumBuffers = destination.maximumBuffers((channels == 0) ? inSourceFormat?.mChannelsPerFrame ?? 1 : channels)
            let outOutputData: UnsafeMutableAudioBufferListPointer = AudioBufferList.allocate(maximumBuffers: maximumBuffers)
            for i in 0..<maximumBuffers {
                outOutputData[i].mNumberChannels = inDestinationFormat.mChannelsPerFrame
                outOutputData[i].mDataByteSize = UInt32(dataBytesSize)
                outOutputData[i].mData = UnsafeMutableRawPointer.allocate(byteCount: dataBytesSize, alignment: 0)
            }

            let status = AudioConverterFillComplexBuffer(
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
                delegate?.audioCodec(self, didOutput: outOutputData, presentationTimeStamp: presentationTimeStamp)
            case -1:
                if destination == .pcm {
                    delegate?.audioCodec(self, didOutput: outOutputData, presentationTimeStamp: presentationTimeStamp)
                }
                finished = true
            default:
                finished = true
            }

            for i in 0..<outOutputData.count {
                if let mData = outOutputData[i].mData {
                    free(mData)
                }
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
        guard currentAudioBuffer.isReady else {
            ioNumberDataPackets.pointee = 0
            return -1
        }

        memcpy(ioData, currentAudioBuffer.input.unsafePointer, currentAudioBuffer.listSize)
        if destination == .pcm {
            ioNumberDataPackets.pointee = 1
        } else {
            ioNumberDataPackets.pointee = UInt32(numSamples)
        }

        if destination == .pcm && outDataPacketDescription != nil {
            audioStreamPacketDescription.mDataByteSize = currentAudioBuffer.input.unsafePointer.pointee.mBuffers.mDataByteSize
            outDataPacketDescription?.pointee = withUnsafeMutablePointer(to: &audioStreamPacketDescription) { $0 }
        }

        currentAudioBuffer.clear()

        return noErr
    }

    private func setBitrateUntilNoErr(_ bitrate: UInt32) {
        do {
            try setProperty(id: kAudioConverterEncodeBitRate, data: bitrate * inDestinationFormat.mChannelsPerFrame)
            actualBitrate = bitrate
        } catch {
            if Self.minimumBitrate < bitrate {
                setBitrateUntilNoErr(bitrate - Self.minimumBitrate)
            } else {
                actualBitrate = Self.minimumBitrate
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

extension AudioCodec: Running {
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
            self.currentAudioBuffer.clear()
            self.inSourceFormat = nil
            self.formatDescription = nil
            self._inDestinationFormat = nil
            self.isRunning.mutate { $0 = false }
        }
    }
}
