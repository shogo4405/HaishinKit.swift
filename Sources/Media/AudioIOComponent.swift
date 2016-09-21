import Foundation
import AVFoundation

final class AudioIOComponent: IOComponent {
    var encoder:AACEncoder = AACEncoder()
    let lockQueue:DispatchQueue = DispatchQueue(
        label: "com.github.shogo4405.lf.AudioIOComponent.lock", attributes: []
    )

    var input:AVCaptureDeviceInput? = nil {
        didSet {
            guard oldValue != input else {
                return
            }
            if let oldValue:AVCaptureDeviceInput = oldValue {
                mixer.session.removeInput(oldValue)
            }
            if let input:AVCaptureDeviceInput = input {
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
                mixer.session.removeOutput(output)
            }
            _output = newValue
        }
    }

    override init(mixer: AVMixer) {
        super.init(mixer: mixer)
        encoder.lockQueue = lockQueue
    }

    func attachAudio(_ audio:AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession:Bool) {
        output = nil
        encoder.invalidate()
        guard let audio:AVCaptureDevice = audio else {
            input = nil
            return
        }
        do {
            input = try AVCaptureDeviceInput(device: audio)
            #if os(iOS)
            mixer.session.automaticallyConfiguresApplicationAudioSession = automaticallyConfiguresApplicationAudioSession
            #endif
            mixer.session.addOutput(output)
            output.setSampleBufferDelegate(self, queue: lockQueue)
        } catch let error as NSError {
            logger.error("\(error)")
        }
    }
}

extension AudioIOComponent: AVCaptureAudioDataOutputSampleBufferDelegate {
    // MARK: AVCaptureAudioDataOutputSampleBufferDelegate
    func captureOutput(_ captureOutput:AVCaptureOutput!, didOutputSampleBuffer sampleBuffer:CMSampleBuffer!, from connection:AVCaptureConnection!) {
        encoder.captureOutput(captureOutput, didOutputSampleBuffer: sampleBuffer, from: connection)
    }
}
