import Foundation
import AVFoundation

final class AACEncoder:NSObject, Encoder, AVCaptureAudioDataOutputSampleBufferDelegate {
    static let supportedSettingsKeys:[String] = [
        "bitrate",
        "sampleRate",
    ]

    static let samplesPerFrame:UInt32 = 1024
    static let defaultBitrate:UInt32 = 32 * 1024
    static let defaultChannels:UInt32 = 1
    static let defaultSampleRate:Double = 44100
    static let defaultAACBufferSize:UInt32 = 1024

    static let defaultInClassDescriptions:[AudioClassDescription] = [
        AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleHardwareAudioCodecManufacturer),
        AudioClassDescription(mType: kAudioEncoderComponentType, mSubType: kAudioFormatMPEG4AAC, mManufacturer: kAppleSoftwareAudioCodecManufacturer),
    ]

    var bitrate:UInt32 = AACEncoder.defaultBitrate {
        didSet {
            dispatch_async(lockQueue) {
                guard let converter:AudioConverterRef = self._converter else {
                    return
                }
                let dataSize:UInt32 = UInt32(sizeof(UInt32))
                AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, dataSize, &self.bitrate)
            }
        }
    }
    var delegate:AudioEncoderDelegate?
    var channels:UInt32 = AACEncoder.defaultChannels
    var sampleRate:Double = AACEncoder.defaultSampleRate
    var sampleSize:UInt32 = AACEncoder.defaultAACBufferSize
    var currentBufferList:AudioBufferList? = nil
    var inClassDescriptions:[AudioClassDescription] = AACEncoder.defaultInClassDescriptions
    var formatDescription:CMFormatDescriptionRef? = nil {
        didSet {
            if (!CMFormatDescriptionEqual(formatDescription, oldValue)) {
                delegate?.didSetFormatDescription(audio: formatDescription)
            }
        }
    }
    
    let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.AACEncoder.lock", DISPATCH_QUEUE_SERIAL)
    
    private var inSourceFormat:AudioStreamBasicDescription?
    
    private var _inDestinationFormat:AudioStreamBasicDescription?
    var inDestinationFormat:AudioStreamBasicDescription {
        get {
            if (_inDestinationFormat == nil) {
                _inDestinationFormat = AudioStreamBasicDescription()
                _inDestinationFormat!.mSampleRate = sampleRate
                _inDestinationFormat!.mFormatID = kAudioFormatMPEG4AAC
                _inDestinationFormat!.mFormatFlags = UInt32(MPEG4ObjectID.AAC_LC.rawValue)
                _inDestinationFormat!.mBytesPerPacket = 0
                _inDestinationFormat!.mFramesPerPacket = AACEncoder.samplesPerFrame
                _inDestinationFormat!.mBytesPerFrame = 0
                _inDestinationFormat!.mChannelsPerFrame = channels
                _inDestinationFormat!.mBitsPerChannel = 0
                _inDestinationFormat!.mReserved = 0
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

        guard let audioBufferList:AudioBufferList = encoder.currentBufferList else {
            ioNumberDataPackets.memory = 0
            return -1
        }

        ioData.memory.mBuffers.mData = audioBufferList.mBuffers.mData
        ioData.memory.mBuffers.mDataByteSize = audioBufferList.mBuffers.mDataByteSize
        encoder.currentBufferList = nil
        ioNumberDataPackets.memory = 1

        return noErr
    }

    private var _converter:AudioConverterRef?
    private var converter:AudioConverterRef {
        var status:OSStatus = noErr
        if (_converter == nil) {
            var converter:AudioConverterRef = AudioConverterRef()
            status = AudioConverterNewSpecific(
                &inSourceFormat!,
                &inDestinationFormat,
                UInt32(inClassDescriptions.count),
                &inClassDescriptions,
                &converter
            )

            if (status == noErr) {
                let dataSize:UInt32 = UInt32(sizeof(UInt32))
                AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, dataSize, &bitrate)
            }

            _converter = converter
        }
        if (status != noErr) {
            print(status)
        }
        return _converter!
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {

        if (inSourceFormat == nil) {
            if let format:CMAudioFormatDescriptionRef = CMSampleBufferGetFormatDescription(sampleBuffer) {
                inSourceFormat = CMAudioFormatDescriptionGetStreamBasicDescription(format).memory
            } else {
                return
            }
        }

        var status:OSStatus = noErr
        var blockBuffer:CMBlockBufferRef?
        var inAudioBufferList:AudioBufferList = AudioBufferList()
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer, nil, &inAudioBufferList, sizeof(AudioBufferList.self), nil, nil, 0, &blockBuffer
        )
        
        var data:[UInt8] = [UInt8](count: Int(AACEncoder.defaultAACBufferSize), repeatedValue: 0)
        var outOutputData:AudioBufferList = AudioBufferList(
            mNumberBuffers: channels,
            mBuffers: AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: UInt32(data.count),
                mData: &data
            )
        )
        
        currentBufferList = inAudioBufferList
        var outputDataPacketSize:UInt32 = 1
        status = fillComplexBuffer(&outputDataPacketSize, &outOutputData, nil)

        if (status == noErr)
        {
            var result:CMSampleBufferRef?
            var format:CMAudioFormatDescriptionRef?
            var timing:CMSampleTimingInfo = CMSampleTimingInfo()
            let numSamples:CMItemCount = CMSampleBufferGetNumSamples(sampleBuffer)
            
            CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timing)
            CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &inDestinationFormat, 0, nil, 0, nil, nil, &format)
            formatDescription = format

            CMSampleBufferCreate(kCFAllocatorDefault, nil, false, nil, nil, format, numSamples, 1, &timing, 0, nil, &result)
            CMSampleBufferSetDataBufferFromAudioBufferList(result!, kCFAllocatorDefault, kCFAllocatorDefault, 0, &outOutputData)

            delegate?.sampleOuput(audio: result!)
        }
    }

    func fillComplexBuffer(inOutputDataPacketSize: UnsafeMutablePointer<UInt32>,
        _ outOutputData: UnsafeMutablePointer<AudioBufferList>,
        _ outPacketDescription: UnsafeMutablePointer<AudioStreamPacketDescription>) -> OSStatus {
        return AudioConverterFillComplexBuffer(
            converter,
            inputDataProc,
            unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
            inOutputDataPacketSize,
            outOutputData,
            outPacketDescription
        )
    }
    
    func dispose() {
        if (_converter != nil) {
            AudioConverterDispose(_converter!)
            _converter = nil
        }
        inSourceFormat = nil
        formatDescription = nil
        _inDestinationFormat = nil
        currentBufferList = nil
    }
}
