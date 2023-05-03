import AVFoundation

protocol RTMPMuxerDelegate: AnyObject {
    func muxer(_ muxer: RTMPMuxer, didSetMetadata: ASObject)
    func muxer(_ muxer: RTMPMuxer, didOutputAudio buffer: Data, withTimestamp: Double)
    func muxer(_ muxer: RTMPMuxer, didOutputVideo buffer: Data, withTimestamp: Double)
    func muxer(_ muxer: RTMPMuxer, audioCodecErrorOccurred error: AudioCodec.Error)
    func muxer(_ muxer: RTMPMuxer, videoCodecErrorOccurred error: VideoCodec.Error)
    func muxerWillDropFrame(_ muxer: RTMPMuxer) -> Bool
}

// MARK: -
final class RTMPMuxer {
    static let aac: UInt8 = FLVAudioCodec.aac.rawValue << 4 | FLVSoundRate.kHz44.rawValue << 2 | FLVSoundSize.snd16bit.rawValue << 1 | FLVSoundType.stereo.rawValue

    weak var delegate: RTMPMuxerDelegate?
    private var audioTimeStamp: CMTime = .zero
    private var videoTimeStamp: CMTime = .zero
    private let compositiionTimeOffset = CMTime.init(value: 1, timescale: 10)

    func dispose() {
        audioTimeStamp = .zero
        videoTimeStamp = .zero
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
        guard let formatDescription else {
            return
        }
        switch codec.settings.format {
        case .h264:
            guard let avcC = AVCDecoderConfigurationRecord.getData(formatDescription) else {
                return
            }
            var buffer = Data([FLVFrameType.key.rawValue << 4 | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.seq.rawValue, 0, 0, 0])
            buffer.append(avcC)
            delegate?.muxer(self, didOutputVideo: buffer, withTimestamp: 0)
        case .hevc:
            guard let hvcC = HEVCDecoderConfigurationRecord.getData(formatDescription) else {
                return
            }
            var buffer = Data([0b10000000 | FLVFrameType.key.rawValue << 4 | FLVVideoPacketType.sequenceStart.rawValue, 0x68, 0x76, 0x63, 0x31])
            buffer.append(hvcC)
            delegate?.muxer(self, didOutputVideo: buffer, withTimestamp: 0)
        }
    }

    func videoCodec(_ codec: VideoCodec, didOutput sampleBuffer: CMSampleBuffer) {
        let keyframe = !sampleBuffer.isNotSync
        let decodeTimeStamp = sampleBuffer.decodeTimeStamp.isValid ? sampleBuffer.decodeTimeStamp : sampleBuffer.presentationTimeStamp
        let compositionTime = getCompositionTime(sampleBuffer)
        let delta = (videoTimeStamp == .zero ? .zero : decodeTimeStamp - videoTimeStamp).seconds * 1000
        guard let data = sampleBuffer.dataBuffer?.data, 0 <= delta else {
            return
        }
        switch codec.settings.format {
        case .h264:
            var buffer = Data([((keyframe ? FLVFrameType.key.rawValue : FLVFrameType.inter.rawValue) << 4) | FLVVideoCodec.avc.rawValue, FLVAVCPacketType.nal.rawValue])
            buffer.append(contentsOf: compositionTime.bigEndian.data[1..<4])
            buffer.append(data)
            delegate?.muxer(self, didOutputVideo: buffer, withTimestamp: delta)
        case .hevc:
            var buffer = Data([0b10000000 | ((keyframe ? FLVFrameType.key.rawValue : FLVFrameType.inter.rawValue) << 4) | FLVVideoPacketType.codedFrames.rawValue, 0x68, 0x76, 0x63, 0x31])
            buffer.append(contentsOf: compositionTime.bigEndian.data[1..<4])
            buffer.append(data)
            delegate?.muxer(self, didOutputVideo: buffer, withTimestamp: delta)
        }
        videoTimeStamp = decodeTimeStamp
    }

    func videoCodecWillDropFame(_ codec: VideoCodec) -> Bool {
        return delegate?.muxerWillDropFrame(self) ?? false
    }

    private func getCompositionTime(_ sampleBuffer: CMSampleBuffer) -> Int32 {
        guard sampleBuffer.decodeTimeStamp.isValid, sampleBuffer.decodeTimeStamp != sampleBuffer.presentationTimeStamp else {
            return 0
        }
        return Int32((sampleBuffer.presentationTimeStamp - videoTimeStamp + compositiionTimeOffset).seconds * 1000)
    }
}
