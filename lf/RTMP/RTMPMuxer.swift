import Foundation
import AVFoundation

protocol RTMPMuxerDelegate: class {
    func sampleOutput(muxer:RTMPMuxer, audio buffer:NSData, timestamp:Double)
    func sampleOutput(muxer:RTMPMuxer, video buffer:NSData, timestamp:Double)
}

final class RTMPMuxer: NSObject, VideoEncoderDelegate, AudioEncoderDelegate {
    var audioSettings:[String: AnyObject] {
        get {
            return audioEncoder.dictionaryWithValuesForKeys([])
        }
        set {
            videoEncoder.setValuesForKeysWithDictionary(audioSettings)
        }
    }

    var videoSettings:[String: AnyObject] {
        get {
            return videoEncoder.dictionaryWithValuesForKeys(AVCEncoder.dictionaryKeys)
        }
        set {
            videoEncoder.setValuesForKeysWithDictionary(videoSettings)
        }
    }

    lazy var audioEncoder:AACEncoder = {
        var encoder:AACEncoder = AACEncoder()
        encoder.delegate = self
        return encoder
    }()

    lazy var videoEncoder:AVCEncoder = {
        var encoder:AVCEncoder = AVCEncoder()
        encoder.delegate = self
        return encoder
    }()

    weak var delegate:RTMPMuxerDelegate? = nil

    private var audioTimestamp:CMTime = kCMTimeZero
    private var videoTimestamp:CMTime = kCMTimeZero

    func dispose() {
        audioTimestamp = kCMTimeZero
        audioEncoder.dispose()
        videoTimestamp = kCMTimeZero
        videoEncoder.dispose()
    }

    func createMetadata() -> ECMAObject {
        var metadata:ECMAObject = ECMAObject()
        metadata["width"] = videoEncoder.width
        metadata["height"] = videoEncoder.height
        metadata["videocodecid"] = FLVTag.VideoCodec.AVC.rawValue
        metadata["audiocodecid"] = FLVTag.AudioCodec.AAC.rawValue
        metadata["audiochannels"] = audioEncoder.channels
        metadata["audiosamplerate"] = audioEncoder.sampleRate
        metadata["audiosamplesize"] = audioEncoder.sampleSize
        return metadata
    }

    func didSetFormatDescription(audio formatDescription: CMFormatDescriptionRef?) {
        if (formatDescription == nil) {
            return
        }
        let buffer:NSMutableData = NSMutableData()
        let config:[UInt8] = AudioSpecificConfig(formatDescription: formatDescription!).bytes
        var data:[UInt8] = [0x00, FLVTag.AACPacketType.Seq.rawValue]
        data[0] =  FLVTag.AudioCodec.AAC.rawValue << 4 | FLVTag.SoundRate.KHz44.rawValue << 2 | FLVTag.SoundSize.Snd16bit.rawValue << 1 | FLVTag.SoundType.Stereo.rawValue
        buffer.appendBytes(&data, length: data.count)
        buffer.appendBytes(config, length:config.count)
        delegate?.sampleOutput(self, audio: buffer, timestamp: 0)
    }

    func didSetFormatDescription(video formatDescription: CMFormatDescriptionRef?) {
        if (formatDescription == nil) {
            return
        }
        let avcC:NSData? = AVCConfigurationRecord.getData(formatDescription!)
        let buffer:NSMutableData = NSMutableData()
        var data:[UInt8] = [UInt8](count: 5, repeatedValue: 0x00)
        data[0] = FLVTag.FrameType.Key.rawValue << 4 | FLVTag.VideoCodec.AVC.rawValue
        data[1] = FLVTag.AVCPacketType.Seq.rawValue
        buffer.appendBytes(&data, length: data.count)
        buffer.appendData(avcC!)
        delegate?.sampleOutput(self, video: buffer, timestamp: 0)
    }

    func sampleOuput(video sampleBuffer: CMSampleBuffer) {
        var keyframe:Bool = false
        var totalLength:Int = 0
        var dataPointer:UnsafeMutablePointer<Int8> = nil
        let block:CMBlockBufferRef? = CMSampleBufferGetDataBuffer(sampleBuffer)
        if let attachments:CFArrayRef = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false) {
            if let attachment:Dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), CFDictionaryRef.self) as Dictionary? {
                let dependsOnOthers:Bool = attachment["DependsOnOthers"] as! Bool
                keyframe = dependsOnOthers == false
            }
        }
        if (block != nil && CMBlockBufferGetDataPointer(block!, 0, nil, &totalLength, &dataPointer) == noErr) {
            let buffer:NSMutableData = NSMutableData()
            var data:[UInt8] = [UInt8](count: 5, repeatedValue: 0x00)
            data[0] = ((keyframe ? FLVTag.FrameType.Key.rawValue : FLVTag.FrameType.Inter.rawValue) << 4) | FLVTag.VideoCodec.AVC.rawValue
            data[1] = FLVTag.AVCPacketType.Nal.rawValue
            buffer.appendBytes(&data, length: data.count)
            buffer.appendData(AVCEncoder.getData(dataPointer, length: totalLength))
            let presentationTimeStamp:CMTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let delta:Double = (videoTimestamp == kCMTimeZero ? 0 : CMTimeGetSeconds(presentationTimeStamp) - CMTimeGetSeconds(videoTimestamp)) * 1000
            delegate?.sampleOutput(self, video: buffer, timestamp: delta)
            videoTimestamp = presentationTimeStamp
        }
    }

    func sampleOuput(audio sampleBuffer: CMSampleBuffer) {
        var blockBuffer:CMBlockBufferRef?
        var audioBufferList:AudioBufferList = AudioBufferList()
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer, nil, &audioBufferList, sizeof(AudioBufferList.self), nil, nil, 0, &blockBuffer
        )
        let buffer:NSMutableData = NSMutableData()
        var data:[UInt8] = [0x00, FLVTag.AACPacketType.Raw.rawValue]
        data[0] =  FLVTag.AudioCodec.AAC.rawValue << 4 | FLVTag.SoundRate.KHz44.rawValue << 2 | FLVTag.SoundSize.Snd16bit.rawValue << 1 | FLVTag.SoundType.Stereo.rawValue
        buffer.appendBytes(&data, length: data.count)
        buffer.appendBytes(audioBufferList.mBuffers.mData, length: Int(audioBufferList.mBuffers.mDataByteSize))
        let presentationTimeStamp:CMTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let delta:Double = (audioTimestamp == kCMTimeZero ? 0 : CMTimeGetSeconds(presentationTimeStamp) - CMTimeGetSeconds(audioTimestamp)) * 1000
        delegate?.sampleOutput(self, audio: buffer, timestamp: delta)
        audioTimestamp = presentationTimeStamp
    }
}
