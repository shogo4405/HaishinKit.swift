import AVFoundation

final class AudioIOComponent: IOComponent {
    lazy var encoder: AudioConverter = AudioConverter()
    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioIOComponent.lock")

    private var _audioEngine: AVAudioEngine?
    private var audioEngine: AVAudioEngine! {
        get {
            if _audioEngine == nil {
                _audioEngine = AVAudioEngine()
            }
            return _audioEngine
        }
        set {
            if _audioEngine == newValue {
                return
            }
            _audioEngine = nil
        }
    }
    private var _playerNode: AVAudioPlayerNode?
    private var playerNode: AVAudioPlayerNode! {
        get {
            if _playerNode == nil {
                _playerNode = AVAudioPlayerNode()
            }
            return _playerNode
        }
        set {
            if _playerNode == newValue {
                return
            }
            _playerNode = nil
        }
    }
    private var audioFormat: AVAudioFormat? {
        didSet {
            guard let audioEngine = audioEngine else { return }
            audioEngine.attach(playerNode)
            nstry({
                self.audioEngine.connect(self.playerNode, to: audioEngine.outputNode, format: self.audioFormat)
            }, { exeption in
                logger.warn("\(exeption)")
            })
            try? audioEngine.start()
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
        if #available(iOSApplicationExtension 9.0, *) {
            audioFormat = AVAudioFormat(cmAudioFormatDescription: formatDescription)
        } else {
        }
    }

    func sampleOutput(audio bytes: UnsafeMutableRawPointer?, count: UInt32, presentationTimeStamp: CMTime) {
        guard
            let bytes = bytes,
            let audioFormat = audioFormat,
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: count / 4) else {
            return
        }

        buffer.frameLength = buffer.frameCapacity
        memcpy(buffer.mutableAudioBufferList.pointee.mBuffers.mData, bytes, Int(count))
        buffer.mutableAudioBufferList.pointee.mBuffers.mDataByteSize = count
        buffer.mutableAudioBufferList.pointee.mBuffers.mNumberChannels = 1

        nstry({
            self.playerNode.scheduleBuffer(buffer, completionHandler: {
            })
            if !self.playerNode.isPlaying {
                self.playerNode.play()
            }
        }, { exeption in
            logger.warn("\(exeption)")
        })
    }
}
