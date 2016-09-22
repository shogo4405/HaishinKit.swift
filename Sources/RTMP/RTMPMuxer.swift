import Foundation
import AVFoundation

protocol RTMPMuxerDelegate: class {
    func sampleOutput(audio buffer:Data, withTimestamp:Double, muxer:RTMPMuxer)
    func sampleOutput(video buffer:Data, withTimestamp:Double, muxer:RTMPMuxer)
}

// MARK: -
final class RTMPMuxer {
    static let aac:UInt8 = FLVAudioCodec.aac.rawValue << 4 | FLVSoundRate.kHz44.rawValue << 2 | FLVSoundSize.snd16bit.rawValue << 1 | FLVSoundType.stereo.rawValue

    weak var delegate:RTMPMuxerDelegate? = nil
    fileprivate var avcC:Data?
    fileprivate var audioDecorderSpecificConfig:Data?
    fileprivate var timestamps:[Int:Double] = [:]
    fileprivate var audioTimestamp:CMTime = kCMTimeZero
    fileprivate var videoTimestamp:CMTime = kCMTimeZero

    func dispose() {
        audioTimestamp = kCMTimeZero
        videoTimestamp = kCMTimeZero
    }
}

extension RTMPMuxer: AudioEncoderDelegate {
    // MARK: AudioEncoderDelegate

    func didSetFormatDescription(audio formatDescription: CMFormatDescription?) {
        guard let formatDescription:CMFormatDescription = formatDescription else {
            return
        }
        var buffer:Data = Data([RTMPMuxer.aac, FLVAACPacketType.seq.rawValue])
        buffer.append(contentsOf: AudioSpecificConfig(formatDescription: formatDescription).bytes)
        delegate?.sampleOutput(audio: buffer, withTimestamp: 0, muxer: self)
    }

    func sampleOutput(audio sampleBuffer: CMSampleBuffer) {
        var blockBuffer:CMBlockBuffer?
        var audioBufferList:AudioBufferList = AudioBufferList()
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer, nil, &audioBufferList, MemoryLayout<AudioBufferList>.size, nil, nil, 0, &blockBuffer
        )
        let presentationTimeStamp:CMTime = sampleBuffer.presentationTimeStamp
        let delta:Double = (audioTimestamp == kCMTimeZero ? 0 : presentationTimeStamp.seconds - audioTimestamp.seconds) * 1000
        guard let _:CMBlockBuffer = blockBuffer , 0 <= delta else {
            return
        }
        var buffer:Data = Data([RTMPMuxer.aac, FLVAACPacketType.raw.rawValue])
        if let mData:UnsafeMutableRawPointer = audioBufferList.mBuffers.mData {
            buffer.append(mData.assumingMemoryBound(to: UInt8.self), count: Int(audioBufferList.mBuffers.mDataByteSize))
        }
        delegate?.sampleOutput(audio: buffer, withTimestamp: delta, muxer: self)
        audioTimestamp = presentationTimeStamp
    }
}

extension RTMPMuxer: VideoEncoderDelegate {
    // MARK: VideoEncoderDelegate
    func didSetFormatDescription(video formatDescription: CMFormatDescription?) {
        guard
            let formatDescription:CMFormatDescription = formatDescription,
            let avcC:Data = AVCConfigurationRecord.getData(formatDescription) else {
            return
        }
        var buffer:Data = Data([FLVFrameType.key.rawValue << 4 | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.seq.rawValue, 0, 0, 0])
        buffer.append(avcC)
        delegate?.sampleOutput(video: buffer, withTimestamp: 0, muxer: self)
    }

    func sampleOutput(video sampleBuffer: CMSampleBuffer) {
        guard let block:CMBlockBuffer = sampleBuffer.dataBuffer else {
            return
        }

        let keyframe:Bool = !sampleBuffer.dependsOnOthers
        var totalLength:Int = 0
        var dataPointer:UnsafeMutablePointer<Int8>? = nil
        guard CMBlockBufferGetDataPointer(block, 0, nil, &totalLength, &dataPointer) == noErr else {
            return
        }

        var compositionTime:Int32 = 0
        let presentationTimeStamp:CMTime = sampleBuffer.presentationTimeStamp
        var decodeTimeStamp:CMTime = sampleBuffer.decodeTimeStamp
        if (decodeTimeStamp == kCMTimeInvalid) {
            decodeTimeStamp = presentationTimeStamp
        } else {
            compositionTime = Int32((decodeTimeStamp.seconds - decodeTimeStamp.seconds) * 1000)
        }
        let delta:Double = (videoTimestamp == kCMTimeZero ? 0 : decodeTimeStamp.seconds - videoTimestamp.seconds) * 1000
        var buffer:Data = Data([((keyframe ? FLVFrameType.key.rawValue : FLVFrameType.inter.rawValue) << 4) | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.nal.rawValue])
        buffer.append(contentsOf: compositionTime.bigEndian.bytes[1..<4])
        if let pointer:UnsafeMutablePointer<Int8> = dataPointer {
            buffer.append(Data(bytes: pointer, count: totalLength))
        }
        delegate?.sampleOutput(video: buffer, withTimestamp: delta, muxer: self)
        videoTimestamp = decodeTimeStamp
    }
}

extension RTMPMuxer: MP4SamplerDelegate {
    // MP4SampleDelegate
    func didSet(avcC: Data, withType:Int) {
        if (avcC == self.avcC) {
            return
        }
        var buffer:Data = Data([FLVFrameType.key.rawValue << 4 | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.seq.rawValue, 0, 0, 0])
        buffer.append(avcC)
        delegate?.sampleOutput(video: buffer, withTimestamp: 0, muxer: self)
        self.avcC = avcC
    }

    func didSet(audioDecorderSpecificConfig: Data, withType:Int) {
        if (withType == 2) {
            return
        }
        if (audioDecorderSpecificConfig == self.audioDecorderSpecificConfig) {
            return
        }
        var buffer:Data = Data([RTMPMuxer.aac, FLVAACPacketType.raw.rawValue])
        buffer.append(audioDecorderSpecificConfig)
        delegate?.sampleOutput(audio: buffer, withTimestamp: 0, muxer: self)
        self.audioDecorderSpecificConfig = audioDecorderSpecificConfig
    }

    func output(data:Data, withType:Int, currentTime:Double, keyframe:Bool) {
        let delta:Double = (timestamps[withType] == nil) ? 0 : timestamps[withType]!
        switch withType {
        case 0:
            let compositionTime:Int32 = 0
            var buffer:Data = Data([((keyframe ? FLVFrameType.key.rawValue : FLVFrameType.inter.rawValue) << 4) | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.nal.rawValue])
            buffer.append(contentsOf: compositionTime.bigEndian.bytes[1..<4])
            buffer.append(data)
            delegate?.sampleOutput(video: buffer, withTimestamp: delta, muxer: self)
        case 1:
            var buffer:Data = Data([RTMPMuxer.aac, FLVAACPacketType.raw.rawValue])
            buffer.append(data)
            delegate?.sampleOutput(audio: buffer, withTimestamp: delta, muxer: self)
        default:
            break
        }
        timestamps[withType] = currentTime
    }
}
