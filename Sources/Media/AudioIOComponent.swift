import Foundation
import AVFoundation

final class AudioIOComponent: IOComponent {
    var encoder:AACEncoder = AACEncoder()
    var playback:AudioStreamPlayback = AudioStreamPlayback()
    let lockQueue:DispatchQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioIOComponent.lock")

#if os(iOS) || os(macOS)
    var input:AVCaptureDeviceInput? = nil {
        didSet {
            guard let mixer:AVMixer = mixer, oldValue != input else {
                return
            }
            if let oldValue:AVCaptureDeviceInput = oldValue {
                mixer.session.removeInput(oldValue)
            }
            if let input:AVCaptureDeviceInput = input, mixer.session.canAddInput(input) {
                mixer.session.addInput(input)
            }
        }
    }

    private var _output:AVCaptureAudioDataOutput? = nil
    var output:AVCaptureAudioDataOutput! {
        get {
            if (_output == nil) {
                _output = AVCaptureAudioDataOutput()
            }
            return _output
        }
        set {
            if (_output == newValue) {
                return
            }
            if let output:AVCaptureAudioDataOutput = _output {
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

    func appendSampleBuffer(_ sampleBuffer:CMSampleBuffer) {
        mixer?.recorder.appendSampleBuffer(sampleBuffer, mediaType: .audio)
        encoder.encodeSampleBuffer(sampleBuffer)
    }

#if os(iOS) || os(macOS)
    func attachAudio(_ audio:AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession:Bool) throws {
        guard let mixer:AVMixer = mixer else {
            return
        }

        mixer.session.beginConfiguration()
        defer {
            mixer.session.commitConfiguration()
        }

        output = nil
        encoder.invalidate()

        guard let audio:AVCaptureDevice = audio else {
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
    }
#else
    func dispose() {
    }
#endif
}

extension AudioIOComponent: AVCaptureAudioDataOutputSampleBufferDelegate {
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        appendSampleBuffer(sampleBuffer)
    }
}

