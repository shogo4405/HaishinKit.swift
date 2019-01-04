import AVFoundation

final class AudioIOComponent: IOComponent {
    lazy var encoder = AudioConverter()
    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioIOComponent.lock")

    var audioEngine: AVAudioEngine?

    var soundTransform: SoundTransform = .init() {
        didSet {
            soundTransform.apply(playerNode)
        }
    }

    private var _playerNode: AVAudioPlayerNode?
    private var playerNode: AVAudioPlayerNode! {
        get {
            if _playerNode == nil {
                _playerNode = AVAudioPlayerNode()
                audioEngine?.attach(_playerNode!)
            }
            return _playerNode
        }
        set {
            if let playerNode = _playerNode {
                audioEngine?.detach(playerNode)
            }
            _playerNode = newValue
        }
    }

    private var audioFormat: AVAudioFormat? {
        didSet {
            guard let audioFormat = audioFormat, let audioEngine = audioEngine else {
                return
            }
            nstry({
                audioEngine.connect(self.playerNode, to: audioEngine.outputNode, format: audioFormat)
            }, { exeption in
                logger.warn(exeption)
            })
            do {
                try audioEngine.start()
            } catch {
                logger.warn(error)
            }
        }
    }

#if os(iOS) || os(macOS)
    var input: AVCaptureDeviceInput? {
        didSet {
            guard let mixer: AVMixer = mixer, oldValue != input else {
                return
            }
            if let oldValue: AVCaptureDeviceInput = oldValue {
                mixer.session.removeInput(oldValue)
            }
            if let input: AVCaptureDeviceInput = input, mixer.session.canAddInput(input) {
                mixer.session.addInput(input)
            }
        }
    }

    private var _output: AVCaptureAudioDataOutput?
    var output: AVCaptureAudioDataOutput! {
        get {
            if _output == nil {
                _output = AVCaptureAudioDataOutput()
            }
            return _output
        }
        set {
            if _output == newValue {
                return
            }
            if let output: AVCaptureAudioDataOutput = _output {
                output.setSampleBufferDelegate(nil, queue: nil)
                mixer?.session.removeOutput(output)
            }
            _output = newValue
        }
    }
#endif

    override init(mixer: AVMixer) {
        super.init(mixer: mixer)
        encoder.lockQueue = lockQueue
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        mixer?.recorder.appendSampleBuffer(sampleBuffer, mediaType: .audio)
        encoder.encodeSampleBuffer(sampleBuffer)
    }

#if os(iOS) || os(macOS)
    func attachAudio(_ audio: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool) throws {
        guard let mixer: AVMixer = mixer else {
            return
        }

        mixer.session.beginConfiguration()
        defer {
            mixer.session.commitConfiguration()
        }

        output = nil
        encoder.invalidate()

        guard let audio: AVCaptureDevice = audio else {
            input = nil
            return
        }

        input = try AVCaptureDeviceInput(device: audio)
        #if os(iOS)
        mixer.session.automaticallyConfiguresApplicationAudioSession = automaticallyConfiguresApplicationAudioSession
        #endif
        mixer.session.addOutput(output)
        output.setSampleBufferDelegate(self, queue: lockQueue)
    }

    func dispose() {
        input = nil
        output = nil
        playerNode = nil
        audioFormat = nil
    }
#else
    func dispose() {
        playerNode = nil
        audioFormat = nil
    }
#endif
}

extension AudioIOComponent: AVCaptureAudioDataOutputSampleBufferDelegate {
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        appendSampleBuffer(sampleBuffer)
    }
}

extension AudioIOComponent: AudioConverterDelegate {
    // MARK: AudioConverterDelegate
    func didSetFormatDescription(audio formatDescription: CMFormatDescription?) {
        guard let formatDescription = formatDescription else { return }
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
    }

    func sampleOutput(audio data: UnsafeMutableAudioBufferListPointer, presentationTimeStamp: CMTime) {
        guard !data.isEmpty else { return }

        guard
            let audioFormat = audioFormat,
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: data[0].mDataByteSize / 4) else {
            return
        }

        buffer.frameLength = buffer.frameCapacity
        let bufferList = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        for i in 0..<bufferList.count {
            guard let mData = data[i].mData else { continue }
            memcpy(bufferList[i].mData, mData, Int(data[i].mDataByteSize))
            bufferList[i].mDataByteSize = data[i].mDataByteSize
            bufferList[i].mNumberChannels = 1
        }

        nstry({
            self.playerNode.scheduleBuffer(buffer, completionHandler: nil)
            if !self.playerNode.isPlaying {
                self.playerNode.play()
            }
        }, { exeption in
            logger.warn("\(exeption)")
        })
    }
}
