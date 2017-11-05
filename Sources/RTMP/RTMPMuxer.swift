import Foundation
import AVFoundation

protocol RTMPMuxerDelegate: class {
    func metadata(_ metadata:ASObject)
    func sampleOutput(audio buffer:Data, withTimestamp:Double, muxer:RTMPMuxer)
    func sampleOutput(video buffer:Data, withTimestamp:Double, muxer:RTMPMuxer)
}

// MARK: -
final class RTMPMuxer {
    static let aac:UInt8 = FLVAudioCodec.aac.rawValue << 4 | FLVSoundRate.kHz44.rawValue << 2 | FLVSoundSize.snd16bit.rawValue << 1 | FLVSoundType.stereo.rawValue

    weak var delegate:RTMPMuxerDelegate? = nil
    private var configs:[Int:Data] = [:]
    private var audioTimestamp:CMTime = kCMTimeZero
    private var videoTimestamp:CMTime = kCMTimeZero

    func dispose() {
        configs.removeAll()
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
        let presentationTimeStamp:CMTime = sampleBuffer.presentationTimeStamp
        let delta:Double = (audioTimestamp == kCMTimeZero ? 0 : presentationTimeStamp.seconds - audioTimestamp.seconds) * 1000
        guard let data:Data = sampleBuffer.dataBuffer?.data, 0 <= delta else {
            return
        }
        var buffer:Data = Data([RTMPMuxer.aac, FLVAACPacketType.raw.rawValue])
        buffer.append(data)
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
        guard let data:Data = sampleBuffer.dataBuffer?.data else {
            return
        }
        let keyframe:Bool = !sampleBuffer.dependsOnOthers
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
        buffer.append(contentsOf: compositionTime.bigEndian.data[1..<4])
        buffer.append(data)
        delegate?.sampleOutput(video: buffer, withTimestamp: delta, muxer: self)
        videoTimestamp = decodeTimeStamp
    }
}

extension RTMPMuxer: MP4SamplerDelegate {
    // MARK: MP4SampleDelegate
    func didOpen(_ reader: MP4Reader) {
        var metadata:ASObject = ASObject()
        if let avc1:MP4VisualSampleEntryBox = reader.getBoxes(byName: "avc1").first as? MP4VisualSampleEntryBox {
            metadata["width"] = avc1.width
            metadata["height"] = avc1.height
            metadata["videocodecid"] = FLVVideoCodec.avc.rawValue
        }
        if let _:MP4AudioSampleEntryBox = reader.getBoxes(byName: "mp4a").first as? MP4AudioSampleEntryBox {
            metadata["audiocodecid"] = FLVAudioCodec.aac.rawValue
        }
        delegate?.metadata(metadata)
    }

    func didSet(config:Data, withID:Int, type:AVMediaType) {
        guard configs[withID] != config else {
            return
        }
        configs[withID] = config
        switch type {
        case .video:
            var buffer:Data = Data([FLVFrameType.key.rawValue << 4 | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.seq.rawValue, 0, 0, 0])
            buffer.append(config)
            delegate?.sampleOutput(video: buffer, withTimestamp: 0, muxer: self)
        case .audio:
            if (withID != 1) {
                break
            }
            var buffer:Data = Data([RTMPMuxer.aac, FLVAACPacketType.seq.rawValue])
            buffer.append(config)
            delegate?.sampleOutput(audio: buffer, withTimestamp: 0, muxer: self)
        default:
            break
        }
    }

    func output(data:Data, withID:Int, currentTime:Double, keyframe:Bool) {
        switch withID {
        case 0:
            let compositionTime:Int32 = 0
            var buffer:Data = Data([((keyframe ? FLVFrameType.key.rawValue : FLVFrameType.inter.rawValue) << 4) | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.nal.rawValue])
            buffer.append(contentsOf: compositionTime.bigEndian.data[1..<4])
            buffer.append(data)
            delegate?.sampleOutput(video: buffer, withTimestamp: currentTime, muxer: self)
        case 1:
            var buffer:Data = Data([RTMPMuxer.aac, FLVAACPacketType.raw.rawValue])
            buffer.append(data)
            delegate?.sampleOutput(audio: buffer, withTimestamp: currentTime, muxer: self)
        default:
            break
        }
    }
}
