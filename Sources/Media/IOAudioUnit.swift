import AVFoundation

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

final class IOAudioUnit: NSObject, IOUnit {
    lazy var codec: AudioCodec = {
        var codec = AudioCodec()
        codec.lockQueue = lockQueue
        return codec
    }()

    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioIOComponent.lock")

    var audioEngine: AVAudioEngine?
    var soundTransform: SoundTransform = .init() {
        didSet {
            soundTransform.apply(mixer?.mediaLink.playerNode)
        }
    }
    weak var mixer: IOMixer?
    var muted = false

    #if os(iOS) || os(macOS)
    private(set) var capture: IOAudioCaptureUnit = .init()
    #endif

    private var audioFormat: AVAudioFormat?

    #if os(iOS) || os(macOS)
    func attachAudio(_ device: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool) throws {
        guard let mixer else {
            return
        }
        mixer.session.beginConfiguration()
        defer {
            mixer.session.commitConfiguration()
        }
        codec.invalidate()
        guard let device else {
            try capture.attachDevice(nil, audioUnit: self)
            return
        }
        try capture.attachDevice(device, audioUnit: self)
        #if os(iOS)
        mixer.session.automaticallyConfiguresApplicationAudioSession = automaticallyConfiguresApplicationAudioSession
        #endif
    }
    #endif

    func registerEffect(_ effect: AudioEffect) -> Bool {
        codec.effects.insert(effect).inserted
    }

    func unregisterEffect(_ effect: AudioEffect) -> Bool {
        codec.effects.remove(effect) != nil
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let sampleBuffer = sampleBuffer.muted(muted) else {
            return
        }
        mixer?.recorder.appendSampleBuffer(sampleBuffer, mediaType: .audio)
        codec.encodeSampleBuffer(sampleBuffer)
    }
}

extension IOAudioUnit: IOUnitEncoding {
    // MARK: IOUnitEncoding
    func startEncoding(_ delegate: AVCodecDelegate) {
        codec.delegate = delegate
        codec.startRunning()
    }

    func stopEncoding() {
        codec.stopRunning()
        codec.delegate = nil
    }
}

extension IOAudioUnit: IOUnitDecoding {
    // MARK: IOUnitDecoding
    func startDecoding(_ audioEngine: AVAudioEngine) {
        self.audioEngine = audioEngine
        if let playerNode = mixer?.mediaLink.playerNode {
            audioEngine.attach(playerNode)
        }
        codec.delegate = self
        codec.startRunning()
    }

    func stopDecoding() {
        if let playerNode = mixer?.mediaLink.playerNode {
            audioEngine?.detach(playerNode)
        }
        audioEngine = nil
        codec.stopRunning()
        codec.delegate = nil
    }
}

#if os(iOS) || os(macOS)
extension IOAudioUnit: AVCaptureAudioDataOutputSampleBufferDelegate {
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard mixer?.useSampleBuffer(sampleBuffer: sampleBuffer, mediaType: AVMediaType.audio) == true else {
            return
        }
        appendSampleBuffer(sampleBuffer)
    }
}
#endif

extension IOAudioUnit: AudioCodecDelegate {
    // MARK: AudioConverterDelegate
    func audioCodec(_ codec: AudioCodec, didSet formatDescription: CMFormatDescription?) {
        guard let formatDescription = formatDescription, let audioEngine = audioEngine else {
            return
        }
        audioFormat = AVAudioFormat(cmAudioFormatDescription: formatDescription)
        nstry({
            if let plyerNode = self.mixer?.mediaLink.playerNode, let audioFormat = self.audioFormat {
                audioEngine.connect(plyerNode, to: audioEngine.mainMixerNode, format: audioFormat)
            }
        }, { exeption in
            logger.warn(exeption)
        })
        do {
            try audioEngine.start()
        } catch {
            logger.warn(error)
        }
    }

    func audioCodec(_ codec: AudioCodec, didOutput sample: UnsafeMutableAudioBufferListPointer, presentationTimeStamp: CMTime) {
        guard !sample.isEmpty, sample[0].mDataByteSize != 0 else {
            return
        }
        guard
            let audioFormat = audioFormat,
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: sample[0].mDataByteSize / 4) else {
            return
        }
        buffer.frameLength = buffer.frameCapacity
        let bufferList = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        for i in 0..<bufferList.count {
            guard let mData = sample[i].mData else { continue }
            memcpy(bufferList[i].mData, mData, Int(sample[i].mDataByteSize))
            bufferList[i].mDataByteSize = sample[i].mDataByteSize
            bufferList[i].mNumberChannels = 1
        }
        if let mixer = mixer {
            mixer.delegate?.mixer(mixer, didOutput: buffer, presentationTimeStamp: presentationTimeStamp)
        }
        mixer?.mediaLink.enqueueAudio(buffer)
    }
}
