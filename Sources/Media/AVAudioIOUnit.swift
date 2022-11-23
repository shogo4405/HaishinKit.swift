import AVFoundation

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

final class AVAudioIOUnit: NSObject, AVIOUnit {
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
    weak var mixer: AVMixer?
    var muted = false

    #if os(iOS) || os(macOS)
    var capture: AVCaptureIOUnit<AVCaptureAudioDataOutput>? {
        didSet {
            oldValue?.output.setSampleBufferDelegate(nil, queue: nil)
            oldValue?.detach(mixer?.session)
        }
    }
    #endif

    private var audioFormat: AVAudioFormat?

    #if os(iOS) || os(macOS)
    deinit {
        capture = nil
    }
    #endif

    #if os(iOS) || os(macOS)
    func attachAudio(_ audio: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool) throws {
        guard let mixer = mixer else {
            return
        }
        mixer.session.beginConfiguration()
        defer {
            mixer.session.commitConfiguration()
        }
        codec.invalidate()
        guard let audio: AVCaptureDevice = audio else {
            capture = nil
            return
        }
        capture = AVCaptureIOUnit(try AVCaptureDeviceInput(device: audio)) {
            AVCaptureAudioDataOutput()
        }
        #if os(iOS)
        mixer.session.automaticallyConfiguresApplicationAudioSession = automaticallyConfiguresApplicationAudioSession
        #endif
        capture?.output.setSampleBufferDelegate(self, queue: lockQueue)
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

extension AVAudioIOUnit: AVIOUnitEncoding {
    // MARK: AVIOUnitEncoding
    func startEncoding(_ delegate: AVCodecDelegate) {
        codec.delegate = delegate
        codec.startRunning()
    }

    func stopEncoding() {
        codec.stopRunning()
        codec.delegate = nil
    }
}

extension AVAudioIOUnit: AVIOUnitDecoding {
    // MARK: AVIOUnitDecoding
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
extension AVAudioIOUnit: AVCaptureAudioDataOutputSampleBufferDelegate {
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard mixer?.useSampleBuffer(sampleBuffer: sampleBuffer, mediaType: AVMediaType.audio) == true else {
            return
        }
        appendSampleBuffer(sampleBuffer)
    }
}
#endif

extension AVAudioIOUnit: AudioCodecDelegate {
    // MARK: AudioConverterDelegate
    func audioCodec(_ codec: AudioCodec, didSet formatDescription: CMFormatDescription?) {
        guard let formatDescription = formatDescription, let audioEngine = audioEngine else {
            return
        }
        #if os(iOS)
        if #available(iOS 9.0, *) {
            audioFormat = AVAudioFormat(cmAudioFormatDescription: formatDescription)
        } else {
            guard let asbd = formatDescription.streamBasicDescription?.pointee else {
                return
            }
            audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: asbd.mSampleRate, channels: asbd.mChannelsPerFrame, interleaved: false)
        }
        #else
        audioFormat = AVAudioFormat(cmAudioFormatDescription: formatDescription)
        #endif
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
