import AVFoundation

protocol RTMPMuxerDelegate: class {
    func metadata(_ metadata: ASObject)
    func sampleOutput(audio buffer: Data, withTimestamp: Double, muxer: RTMPMuxer)
    func sampleOutput(video buffer: Data, withTimestamp: Double, muxer: RTMPMuxer)
}

// MARK: -
final class RTMPMuxer {
    static let aac: UInt8 = FLVAudioCodec.aac.rawValue << 4 | FLVSoundRate.kHz44.rawValue << 2 | FLVSoundSize.snd16bit.rawValue << 1 | FLVSoundType.stereo.rawValue

    weak var delegate: RTMPMuxerDelegate?
    private var configs: [Int: Data] = [:]
    private var audioTimeStamp = CMTime.zero
    private var videoTimeStamp = CMTime.zero

    func dispose() {
        configs.removeAll()
        audioTimeStamp = CMTime.zero
        videoTimeStamp = CMTime.zero
    }
}

extension RTMPMuxer: AudioConverterDelegate {
    // MARK: AudioConverterDelegate
    func didSetFormatDescription(audio formatDescription: CMFormatDescription?) {
        guard let formatDescription = formatDescription else {
            return
        }
        var buffer = Data([RTMPMuxer.aac, FLVAACPacketType.seq.rawValue])
        buffer.append(contentsOf: AudioSpecificConfig(formatDescription: formatDescription).bytes)
        delegate?.sampleOutput(audio: buffer, withTimestamp: 0, muxer: self)
    }

    func sampleOutput(audio data: UnsafeMutableAudioBufferListPointer, presentationTimeStamp: CMTime) {
        let delta: Double = (audioTimeStamp == CMTime.zero ? 0 : presentationTimeStamp.seconds - audioTimeStamp.seconds) * 1000
        guard let bytes = data[0].mData, 0 < data[0].mDataByteSize && 0 <= delta else {
            return
        }
        var buffer = Data([RTMPMuxer.aac, FLVAACPacketType.raw.rawValue])
        buffer.append(bytes.assumingMemoryBound(to: UInt8.self), count: Int(data[0].mDataByteSize))
        delegate?.sampleOutput(audio: buffer, withTimestamp: delta, muxer: self)
        audioTimeStamp = presentationTimeStamp
    }
}

extension RTMPMuxer: VideoEncoderDelegate {
    // MARK: VideoEncoderDelegate
    func didSetFormatDescription(video formatDescription: CMFormatDescription?) {
        guard
            let formatDescription = formatDescription,
            let avcC = AVCConfigurationRecord.getData(formatDescription) else {
            return
        }
        var buffer = Data([FLVFrameType.key.rawValue << 4 | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.seq.rawValue, 0, 0, 0])
        buffer.append(avcC)
        delegate?.sampleOutput(video: buffer, withTimestamp: 0, muxer: self)
    }

    func sampleOutput(video sampleBuffer: CMSampleBuffer) {
        let keyframe: Bool = !sampleBuffer.isNotSync
        var compositionTime: Int32 = 0
        let presentationTimeStamp: CMTime = sampleBuffer.presentationTimeStamp
        var decodeTimeStamp: CMTime = sampleBuffer.decodeTimeStamp
        if decodeTimeStamp == CMTime.invalid {
            decodeTimeStamp = presentationTimeStamp
        } else {
            compositionTime = Int32((presentationTimeStamp.seconds - decodeTimeStamp.seconds) * 1000)
        }
        let delta: Double = (videoTimeStamp == CMTime.zero ? 0 : decodeTimeStamp.seconds - videoTimeStamp.seconds) * 1000
        guard let data = sampleBuffer.dataBuffer?.data, 0 <= delta else {
            return
        }
        var buffer = Data([((keyframe ? FLVFrameType.key.rawValue : FLVFrameType.inter.rawValue) << 4) | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.nal.rawValue])
        buffer.append(contentsOf: compositionTime.bigEndian.data[1..<4])
        buffer.append(data)
        delegate?.sampleOutput(video: buffer, withTimestamp: delta, muxer: self)
        videoTimeStamp = decodeTimeStamp
    }
}

extension RTMPMuxer: MP4SamplerDelegate {
    // MARK: MP4SampleDelegate
    func didOpen(_ reader: MP4Reader) {
        var metadata = ASObject()
        if let avc1: MP4VisualSampleEntryBox = reader.getBoxes(byName: "avc1").first as? MP4VisualSampleEntryBox {
            metadata["width"] = avc1.width
            metadata["height"] = avc1.height
            metadata["videocodecid"] = FLVVideoCodec.avc.rawValue
        }
        if let _: MP4AudioSampleEntryBox = reader.getBoxes(byName: "mp4a").first as? MP4AudioSampleEntryBox {
            metadata["audiocodecid"] = FLVAudioCodec.aac.rawValue
        }
        delegate?.metadata(metadata)
    }

    func didSet(config: Data, withID: Int, type: AVMediaType) {
        guard configs[withID] != config else {
            return
        }
        configs[withID] = config
        switch type {
        case .video:
            var buffer = Data([FLVFrameType.key.rawValue << 4 | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.seq.rawValue, 0, 0, 0])
            buffer.append(config)
            delegate?.sampleOutput(video: buffer, withTimestamp: 0, muxer: self)
        case .audio:
            if withID != 1 {
                break
            }
            var buffer = Data([RTMPMuxer.aac, FLVAACPacketType.seq.rawValue])
            buffer.append(config)
            delegate?.sampleOutput(audio: buffer, withTimestamp: 0, muxer: self)
        default:
            break
        }
    }

    func output(data: Data, withID: Int, currentTime: Double, keyframe: Bool) {
        switch withID {
        case 0:
            let compositionTime: Int32 = 0
            var buffer = Data([((keyframe ? FLVFrameType.key.rawValue : FLVFrameType.inter.rawValue) << 4) | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.nal.rawValue])
            buffer.append(contentsOf: compositionTime.bigEndian.data[1..<4])
            buffer.append(data)
            delegate?.sampleOutput(video: buffer, withTimestamp: currentTime, muxer: self)
        case 1:
            var buffer = Data([RTMPMuxer.aac, FLVAACPacketType.raw.rawValue])
            buffer.append(data)
            delegate?.sampleOutput(audio: buffer, withTimestamp: currentTime, muxer: self)
        default:
            break
        }
    }
}
