import Foundation
import AVFoundation

protocol RTMPMuxerDelegate: class {
    func sampleOutput(_ muxer:RTMPMuxer, audio buffer:Data, timestamp:Double)
    func sampleOutput(_ muxer:RTMPMuxer, video buffer:Data, timestamp:Double)
}

// MARK: -
final class RTMPMuxer {
    internal weak var delegate:RTMPMuxerDelegate? = nil

    fileprivate var audioTimestamp:CMTime = kCMTimeZero
    fileprivate var videoTimestamp:CMTime = kCMTimeZero

    internal func dispose() {
        audioTimestamp = kCMTimeZero
        videoTimestamp = kCMTimeZero
    }
}

extension RTMPMuxer: AudioEncoderDelegate {
    // MARK: AudioEncoderDelegate
    internal func didSetFormatDescription(audio formatDescription: CMFormatDescription?) {
        guard let formatDescription:CMFormatDescription = formatDescription else {
            return
        }
        let buffer:NSMutableData = NSMutableData()
        let config:[UInt8] = AudioSpecificConfig(formatDescription: formatDescription).bytes
        var data:[UInt8] = [0x00, FLVAACPacketType.seq.rawValue]
        data[0] =  FLVAudioCodec.aac.rawValue << 4 | FLVSoundRate.kHz44.rawValue << 2 | FLVSoundSize.snd16bit.rawValue << 1 | FLVSoundType.stereo.rawValue
        buffer.append(&data, length: data.count)
        buffer.append(config, length: config.count)
        delegate?.sampleOutput(self, audio: buffer as Data, timestamp: 0)
    }

    internal func sampleOutput(audio sampleBuffer: CMSampleBuffer) {
        var blockBuffer:CMBlockBuffer?
        var audioBufferList:AudioBufferList = AudioBufferList()
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer, nil, &audioBufferList, MemoryLayout<AudioBufferList>.size, nil, nil, 0, &blockBuffer
        )
        let presentationTimeStamp:CMTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let delta:Double = (audioTimestamp == kCMTimeZero ? 0 : CMTimeGetSeconds(presentationTimeStamp) - CMTimeGetSeconds(audioTimestamp)) * 1000
        guard let _:CMBlockBuffer = blockBuffer , 0 <= delta else {
            return
        }
        let buffer:NSMutableData = NSMutableData()
        var data:[UInt8] = [0x00, FLVAACPacketType.raw.rawValue]
        data[0] = FLVAudioCodec.aac.rawValue << 4 | FLVSoundRate.kHz44.rawValue << 2 | FLVSoundSize.snd16bit.rawValue << 1 | FLVSoundType.stereo.rawValue
        buffer.append(&data, length: data.count)
        buffer.append(audioBufferList.mBuffers.mData!, length: Int(audioBufferList.mBuffers.mDataByteSize))
        delegate?.sampleOutput(self, audio: buffer as Data, timestamp: delta)
        audioTimestamp = presentationTimeStamp
    }
}

extension RTMPMuxer: VideoEncoderDelegate {
    // MARK: VideoEncoderDelegate
    internal func didSetFormatDescription(video formatDescription: CMFormatDescription?) {
        guard
            let formatDescription:CMFormatDescription = formatDescription,
            let avcC:Data = AVCConfigurationRecord.getData(formatDescription) else {
            return
        }
        let buffer:NSMutableData = NSMutableData()
        var data:[UInt8] = [UInt8](repeating: 0x00, count: 5)
        data[0] = FLVFrameType.key.rawValue << 4 | FLVVideoCodec.avc.rawValue
        data[1] = FLVAVCPacketType.seq.rawValue
        buffer.append(&data, length: data.count)
        buffer.append(avcC)
        delegate?.sampleOutput(self, video: buffer as Data, timestamp: 0)
    }

    internal func sampleOutput(video sampleBuffer: CMSampleBuffer) {
        guard let block:CMBlockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }

        let keyframe:Bool = !sampleBuffer.dependsOnOthers
        var totalLength:Int = 0
        var dataPointer:UnsafeMutablePointer<Int8>? = nil
        guard CMBlockBufferGetDataPointer(block, 0, nil, &totalLength, &dataPointer) == noErr else {
            return
        }

        var cto:Int32 = 0
        let pts:CMTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        var dts:CMTime = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)

        if (dts == kCMTimeInvalid) {
            dts = pts
        } else {
            cto = Int32((CMTimeGetSeconds(pts) - CMTimeGetSeconds(dts)) * 1000)
        }
        let delta:Double = (videoTimestamp == kCMTimeZero ? 0 : CMTimeGetSeconds(dts) - CMTimeGetSeconds(videoTimestamp)) * 1000
        let buffer:NSMutableData = NSMutableData()
        var data:[UInt8] = [UInt8](repeating: 0x00, count: 5)
        data[0] = ((keyframe ? FLVFrameType.key.rawValue : FLVFrameType.inter.rawValue) << 4) | FLVVideoCodec.avc.rawValue
        data[1] = FLVAVCPacketType.nal.rawValue
        data[2..<5] = cto.bigEndian.bytes[1..<4]
        buffer.append(&data, length: data.count)
        buffer.append(dataPointer!, length: totalLength)
        
        delegate?.sampleOutput(self, video: buffer as Data, timestamp: delta)
        videoTimestamp = dts
    }
}
