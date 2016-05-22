import Foundation
import AVFoundation

/**
 - seealse:
  - https://developer.apple.com/library/ios/technotes/tn2236/_index.html
  - https://developer.apple.com/library/ios/documentation/AudioVideo/Conceptual/MultimediaPG/UsingAudio/UsingAudio.html
 */
final class AACEncoder: NSObject {
    static let supportedSettingsKeys:[String] = [
        "bitrate",
        "profile",
        "sampleRate",
    ]

    static let packetSize:UInt32 = 1
    static let framesPerPacket:UInt32 = 1024
    static let defaultProfile:UInt32 = UInt32(MPEG4ObjectID.AAC_LC.rawValue)
    static let defaultBitrate:UInt32 = 32 * 1024
    // 0 means according to a input source
    static let defaultChannels:UInt32 = 0
    // 0 means according to a input source
    static let defaultSampleRate:Double = 0
    #if os(iOS)
    static let defaultInClassDescriptions:[AudioClassDescription] = [
        AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleSoftwareAudioCodecManufacturer),
        AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleHardwareAudioCodecManufacturer)
    ]
    #else
    static let defaultInClassDescriptions:[AudioClassDescription] = [
    ]
    #endif

    var bitrate:UInt32 = AACEncoder.defaultBitrate {
        didSet {
            dispatch_async(lockQueue) {
                self.setProperty(kAudioConverterEncodeBitRate, UInt32(sizeof(UInt32)), &self.bitrate)
            }
        }
    }

    var profile:UInt32 = AACEncoder.defaultProfile
    var channels:UInt32 = AACEncoder.defaultChannels
    var sampleRate:Double = AACEncoder.defaultSampleRate
    var inClassDescriptions:[AudioClassDescription] = AACEncoder.defaultInClassDescriptions
    var formatDescription:CMFormatDescriptionRef? = nil {
        didSet {
            if (!CMFormatDescriptionEqual(formatDescription, oldValue)) {
                delegate?.didSetFormatDescription(audio: formatDescription)
            }
        }
    }
    var lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.AACEncoder.lock", DISPATCH_QUEUE_SERIAL
    )
    weak var delegate:AudioEncoderDelegate?
    internal(set) var running:Bool = false
    private var currentBufferList:AudioBufferList? = nil
    private var inSourceFormat:AudioStreamBasicDescription? {
        didSet {
            logger.info("\(inSourceFormat)")
        }
    }
    private var _inDestinationFormat:AudioStreamBasicDescription?
    private var inDestinationFormat:AudioStreamBasicDescription {
        get {
            if (_inDestinationFormat == nil) {
                _inDestinationFormat = AudioStreamBasicDescription()
                _inDestinationFormat!.mSampleRate = sampleRate == 0 ? inSourceFormat!.mSampleRate : sampleRate
                _inDestinationFormat!.mFormatID = kAudioFormatMPEG4AAC
                _inDestinationFormat!.mFormatFlags = profile
                _inDestinationFormat!.mBytesPerPacket = 0
                _inDestinationFormat!.mFramesPerPacket = AACEncoder.framesPerPacket
                _inDestinationFormat!.mBytesPerFrame = 0
                _inDestinationFormat!.mChannelsPerFrame = (channels == 0) ? inSourceFormat!.mChannelsPerFrame : channels
                _inDestinationFormat!.mBitsPerChannel = 0
                _inDestinationFormat!.mReserved = 0

                CMAudioFormatDescriptionCreate(
                    kCFAllocatorDefault, &_inDestinationFormat!, 0, nil, 0, nil, nil, &formatDescription
                )
            }
            return _inDestinationFormat!
        }
        set {
            _inDestinationFormat = newValue
        }
    }

    private var inputDataProc:AudioConverterComplexInputDataProc = {(
        converter:AudioConverterRef,
        ioNumberDataPackets:UnsafeMutablePointer<UInt32>,
        ioData:UnsafeMutablePointer<AudioBufferList>,
        outDataPacketDescription:UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>>,
        inUserData:UnsafeMutablePointer<Void>) in
        return unsafeBitCast(inUserData, AACEncoder.self).onInputDataForAudioConverter(
            ioNumberDataPackets,
            ioData: ioData,
            outDataPacketDescription: outDataPacketDescription
        )
    }

    private var _converter:AudioConverterRef?
    private var converter:AudioConverterRef {
        var status:OSStatus = noErr
        if (_converter == nil) {
            var converter:AudioConverterRef = nil
            status = AudioConverterNewSpecific(
                &inSourceFormat!,
                &inDestinationFormat,
                UInt32(inClassDescriptions.count),
                &inClassDescriptions,
                &converter
            )
            if (status == noErr) {
                var bitrate:UInt32 = self.bitrate * inDestinationFormat.mChannelsPerFrame
                setProperty(kAudioConverterEncodeBitRate, UInt32(sizeof(bitrate.dynamicType)), &bitrate)
            }
            _converter = converter
        }
        if (status != noErr) {
            logger.warning("\(status)")
        }
        return _converter!
    }

    func createAudioBufferList(channels:UInt32, size:UInt32) -> AudioBufferList {
        return AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(
            mNumberChannels: channels, mDataByteSize: size, mData: UnsafeMutablePointer<Void>.alloc(Int(size))
        ))
    }

    func getProperty(inPropertyID:AudioConverterPropertyID, _ ioPropertyDataSize:UnsafeMutablePointer<UInt32>, _ outPropertyData: UnsafeMutablePointer<Void>) -> OSStatus{
        guard let converter:AudioConverterRef = _converter else {
            return -1
        }
        return AudioConverterGetProperty(converter, inPropertyID, ioPropertyDataSize, outPropertyData)
    }

    func setProperty(inPropertyID:AudioConverterPropertyID, _ inPropertyDataSize:UInt32, _ inPropertyData: UnsafePointer<Void>) -> OSStatus {
        guard let converter:AudioConverterRef = _converter else {
            return -1
        }
        return AudioConverterSetProperty(converter, inPropertyID, inPropertyDataSize, inPropertyData)
    }

    func onInputDataForAudioConverter(
        ioNumberDataPackets:UnsafeMutablePointer<UInt32>,
        ioData:UnsafeMutablePointer<AudioBufferList>,
        outDataPacketDescription:UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>>) -> OSStatus {

        if (currentBufferList == nil) {
            ioNumberDataPackets.memory = 0
            return 100
        }

        let numBytes:UInt32 = min(
            ioNumberDataPackets.memory * inSourceFormat!.mBytesPerPacket,
            currentBufferList!.mBuffers.mDataByteSize
        )

        ioData.memory.mBuffers.mData = currentBufferList!.mBuffers.mData
        ioData.memory.mBuffers.mDataByteSize = numBytes
        ioNumberDataPackets.memory = numBytes / inSourceFormat!.mBytesPerPacket
        currentBufferList = nil

        return noErr
    }
}

// MARK: Encoder
extension AACEncoder: Encoder {
    func startRunning() {
        dispatch_async(lockQueue) {
            self.running = true
        }
    }
    func stopRunning() {
        dispatch_async(lockQueue) {
            if let convert:AudioQueueRef = self._converter {
                AudioConverterDispose(convert)
                self._converter = nil
            }
            self.inSourceFormat = nil
            self.formatDescription = nil
            self._inDestinationFormat = nil
            self.currentBufferList = nil
            self.running = false
        }
    }
}

// MARK: AVCaptureAudioDataOutputSampleBufferDelegate
extension AACEncoder: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(captureOutput:AVCaptureOutput!, didOutputSampleBuffer sampleBuffer:CMSampleBuffer!, fromConnection connection:AVCaptureConnection!) {

        guard running else {
            return
        }

        if (inSourceFormat == nil) {
            guard let format:CMAudioFormatDescriptionRef = sampleBuffer.formatDescription else {
                return
            }
            inSourceFormat = CMAudioFormatDescriptionGetStreamBasicDescription(format).memory
        }

        var ioOutputDataPacketSize:UInt32 = AACEncoder.packetSize
        var outOutputData:AudioBufferList = createAudioBufferList(
            inDestinationFormat.mChannelsPerFrame, size: AACEncoder.framesPerPacket
        )

        var blockBuffer:CMBlockBuffer? = nil
        currentBufferList = AudioBufferList()
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer, nil, &currentBufferList!, sizeof(AudioBufferList.self), nil, nil, 0, &blockBuffer
        )

        let status:OSStatus = AudioConverterFillComplexBuffer(
            converter,
            inputDataProc,
            unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
            &ioOutputDataPacketSize,
            &outOutputData,
            nil
        )

        if (status == noErr) {
            var result:CMSampleBufferRef?
            var timing:CMSampleTimingInfo = CMSampleTimingInfo()
            let numSamples:CMItemCount = CMSampleBufferGetNumSamples(sampleBuffer)
            CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timing)
            CMSampleBufferCreate(kCFAllocatorDefault, nil, false, nil, nil, formatDescription, numSamples, 1, &timing, 0, nil, &result)
            CMSampleBufferSetDataBufferFromAudioBufferList(result!, kCFAllocatorDefault, kCFAllocatorDefault, 0, &outOutputData)
            delegate?.sampleOutput(audio: result!)
        }

        let list:UnsafeMutableAudioBufferListPointer = UnsafeMutableAudioBufferListPointer(&outOutputData)
        for buffer in list {
            free(buffer.mData)
        }
    }
}
