import AVFoundation

protocol RTMPMuxerDelegate: AnyObject {
    func muxer(_ muxer: RTMPMuxer, didSetMetadata: ASObject)
    func muxer(_ muxer: RTMPMuxer, didOutputAudio buffer: Data, withTimestamp: Double)
    func muxer(_ muxer: RTMPMuxer, didOutputVideo buffer: Data, withTimestamp: Double)
    func muxer(_ muxer: RTMPMuxer, audioCodecErrorOccurred error: AudioCodec.Error)
    func muxer(_ muxer: RTMPMuxer, videoCodecErrorOccurred error: VideoCodec.Error)
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

extension RTMPMuxer: AudioCodecDelegate {
    // MARK: AudioCodecDelegate
    func audioCodec(_ codec: AudioCodec, errorOccurred error: AudioCodec.Error) {
        delegate?.muxer(self, audioCodecErrorOccurred: error)
    }

    func audioCodec(_ codec: AudioCodec, didOutput audioFormat: AVAudioFormat) {
        var buffer = Data([RTMPMuxer.aac, FLVAACPacketType.seq.rawValue])
        buffer.append(contentsOf: AudioSpecificConfig(formatDescription: audioFormat.formatDescription).bytes)
        delegate?.muxer(self, didOutputAudio: buffer, withTimestamp: 0)
    }

    func audioCodec(_ codec: AudioCodec, didOutput audioBuffer: AVAudioBuffer, presentationTimeStamp: CMTime) {
        let delta = (audioTimeStamp == CMTime.zero ? 0 : presentationTimeStamp.seconds - audioTimeStamp.seconds) * 1000
        guard let audioBuffer = audioBuffer as? AVAudioCompressedBuffer, 0 <= delta else {
            return
        }
        var buffer = Data([RTMPMuxer.aac, FLVAACPacketType.raw.rawValue])
        buffer.append(audioBuffer.data.assumingMemoryBound(to: UInt8.self), count: Int(audioBuffer.byteLength))
        delegate?.muxer(self, didOutputAudio: buffer, withTimestamp: delta)
        audioTimeStamp = presentationTimeStamp
        codec.releaseOutputBuffer(audioBuffer)
    }
}

extension RTMPMuxer: VideoCodecDelegate {
    // MARK: VideoCodecDelegate
    func videoCodec(_ codec: VideoCodec, errorOccurred error: VideoCodec.Error) {
        delegate?.muxer(self, videoCodecErrorOccurred: error)
    }

    func videoCodec(_ codec: VideoCodec, didOutput formatDescription: CMFormatDescription?) {
        guard
            let formatDescription = formatDescription,
            let avcC = AVCConfigurationRecord.getData(formatDescription) else {
            return
        }
        var buffer = Data([FLVFrameType.key.rawValue << 4 | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.seq.rawValue, 0, 0, 0])
        buffer.append(avcC)
        delegate?.muxer(self, didOutputVideo: buffer, withTimestamp: 0)
    }

    func videoCodec(_ codec: VideoCodec, didOutput sampleBuffer: CMSampleBuffer) {
        let keyframe = !sampleBuffer.isNotSync
        var compositionTime: Int32 = 0
        let presentationTimeStamp = sampleBuffer.presentationTimeStamp
        var decodeTimeStamp = sampleBuffer.decodeTimeStamp
        if decodeTimeStamp == CMTime.invalid {
            decodeTimeStamp = presentationTimeStamp
        } else {
            compositionTime = (videoTimeStamp == .zero) ? 0 : Int32((sampleBuffer.presentationTimeStamp.seconds - videoTimeStamp.seconds) * 1000)
        }
        let delta = (videoTimeStamp == .zero ? 0 : decodeTimeStamp.seconds - videoTimeStamp.seconds) * 1000
        guard let data = sampleBuffer.dataBuffer?.data, 0 <= delta else {
            return
        }
        var buffer = Data([((keyframe ? FLVFrameType.key.rawValue : FLVFrameType.inter.rawValue) << 4) | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.nal.rawValue])
        buffer.append(contentsOf: compositionTime.bigEndian.data[1..<4])
        buffer.append(data)
        delegate?.muxer(self, didOutputVideo: buffer, withTimestamp: delta)
        videoTimeStamp = decodeTimeStamp
    }
}
