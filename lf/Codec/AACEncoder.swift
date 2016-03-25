import Foundation
import AVFoundation

// @reference https://developer.apple.com/library/ios/technotes/tn2236/_index.html
// @reference https://developer.apple.com/library/ios/documentation/AudioVideo/Conceptual/MultimediaPG/UsingAudio/UsingAudio.html
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
    static let defaultInClassDescriptions:[AudioClassDescription] = [
        AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleSoftwareAudioCodecManufacturer),
        AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleHardwareAudioCodecManufacturer)
    ]

    var bitrate:UInt32 = AACEncoder.defaultBitrate {
        didSet {
            dispatch_async(lockQueue) {
                self.setProperty(kAudioConverterEncodeBitRate, UInt32(sizeof(UInt32)), &self.bitrate)
            }
        }
    }

    var profile:UInt32 = AACEncoder.defaultProfile
    var running:Bool = false
    var channels:UInt32 = AACEncoder.defaultChannels
    var sampleRate:Double = AACEncoder.defaultSampleRate
    var currentBufferList:AudioBufferList? = nil
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

    private var inSourceFormat:AudioStreamBasicDescription?

    private var _inDestinationFormat:AudioStreamBasicDescription?
    var inDestinationFormat:AudioStreamBasicDescription {
        get {
            if (_inDestinationFormat == nil) {
                _inDestinationFormat = AudioStreamBasicDescription()
                _inDestinationFormat!.mSampleRate = min((sampleRate == 0) ? inSourceFormat!.mSampleRate : sampleRate, 44100)
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
        convert: AudioConverterRef,
        ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
        ioData: UnsafeMutablePointer<AudioBufferList>,
        outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>>,
        inUserData: UnsafeMutablePointer<Void>) in

        let encoder:AACEncoder = unsafeBitCast(inUserData, AACEncoder.self)

        guard let currentBufferList:AudioBufferList = encoder.currentBufferList else {
            ioNumberDataPackets.memory = 0
            return -1
        }

        ioData.memory.mBuffers.mNumberChannels = currentBufferList.mBuffers.mNumberChannels
        ioData.memory.mBuffers.mDataByteSize = currentBufferList.mBuffers.mDataByteSize
        ioData.memory.mBuffers.mData = currentBufferList.mBuffers.mData
        encoder.currentBufferList = nil
        ioNumberDataPackets.memory = 1

        return noErr
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
            print(status)
        }
        return _converter!
    }

    func fillComplexBuffer(
        ioOutputDataPacketSize: UnsafeMutablePointer<UInt32>,
        _ outOutputData: UnsafeMutablePointer<AudioBufferList>,
        _ outPacketDescription: UnsafeMutablePointer<AudioStreamPacketDescription>) -> OSStatus {
        return AudioConverterFillComplexBuffer(
            converter,
            inputDataProc,
            unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
            ioOutputDataPacketSize,
            outOutputData,
            outPacketDescription
        )
    }

    func createAudioBufferList(channels:UInt32, size:UInt32) -> AudioBufferList {
        return AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(
            mNumberChannels: channels, mDataByteSize: size, mData: UnsafeMutablePointer<Void>.alloc(Int(size))
        ))
    }

    func createAudioBufferList(sampleBuffer:CMSampleBufferRef) -> AudioBufferList {
        var blockBuffer:CMBlockBufferRef?
        var inAudioBufferList:AudioBufferList = AudioBufferList()
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer, nil, &inAudioBufferList, sizeof(AudioBufferList.self), nil, nil, 0, &blockBuffer
        )
        return inAudioBufferList
    }

    func getProperty(inPropertyID: AudioConverterPropertyID, _ ioPropertyDataSize: UnsafeMutablePointer<UInt32>, _ outPropertyData: UnsafeMutablePointer<Void>) -> OSStatus{
        guard let converter:AudioConverterRef = _converter else {
            return -1
        }
        return AudioConverterGetProperty(converter, inPropertyID, ioPropertyDataSize, outPropertyData)
    }

    func setProperty(inPropertyID: AudioConverterPropertyID, _ inPropertyDataSize: UInt32, _ inPropertyData: UnsafePointer<Void>) -> OSStatus {
        guard let converter:AudioConverterRef = _converter else {
            return -1
        }
        return AudioConverterSetProperty(converter, inPropertyID, inPropertyDataSize, inPropertyData)
    }
}

// MARK: - Encoder
extension AACEncoder: Encoder {
    func startRunning() {
        dispatch_async(lockQueue) {
            self.running = true
        }
    }
    func stopRunning() {
        dispatch_async(lockQueue) {
            if (self._converter != nil) {
                AudioConverterDispose(self._converter!)
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

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate
extension AACEncoder: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {

        guard running else {
            return
        }

        if (inSourceFormat == nil) {
            if let format:CMAudioFormatDescriptionRef = CMSampleBufferGetFormatDescription(sampleBuffer) {
                inSourceFormat = CMAudioFormatDescriptionGetStreamBasicDescription(format).memory
            } else {
                return
            }
        }

        var outputDataPacketSize:UInt32 = AACEncoder.packetSize
        var outputData:AudioBufferList = createAudioBufferList(
            inDestinationFormat.mChannelsPerFrame, size: AACEncoder.framesPerPacket
        )
        currentBufferList = createAudioBufferList(sampleBuffer)

        guard IsNoErr(fillComplexBuffer(&outputDataPacketSize, &outputData, nil)) else {
            return
        }

        var result:CMSampleBufferRef?
        var timing:CMSampleTimingInfo = CMSampleTimingInfo()
        let numSamples:CMItemCount = CMSampleBufferGetNumSamples(sampleBuffer)
        CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timing)
        CMSampleBufferCreate(kCFAllocatorDefault, nil, false, nil, nil, formatDescription, numSamples, 1, &timing, 0, nil, &result)
        CMSampleBufferSetDataBufferFromAudioBufferList(result!, kCFAllocatorDefault, kCFAllocatorDefault, 0, &outputData)

        delegate?.sampleOutput(audio: result!)
    
        let list:UnsafeMutableAudioBufferListPointer = UnsafeMutableAudioBufferListPointer(&outputData)
        for buffer in list {
            free(buffer.mData)
        }
    }
}
