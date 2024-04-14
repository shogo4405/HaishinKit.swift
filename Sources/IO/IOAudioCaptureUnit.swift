#if os(iOS) || os(tvOS) || os(macOS)
import AVFoundation
import Foundation

@available(tvOS 17.0, *)
final class IOAudioCaptureUnit: IOCaptureUnit {
    typealias Output = AVCaptureAudioDataOutput

    let track: UInt8
    private(set) var device: AVCaptureDevice?
    var input: AVCaptureInput?
    var output: Output?
    var connection: AVCaptureConnection?
    private var dataOutput: IOAudioCaptureUnitDataOutput?

    init(_ track: UInt8) {
        self.track = track
    }

    func attachDevice(_ device: AVCaptureDevice?, audioUnit: IOAudioUnit) throws {
        setSampleBufferDelegate(nil)
        audioUnit.mixer?.session.detachCapture(self)
        guard let device else {
            self.device = nil
            input = nil
            output = nil
            return
        }
        self.device = device
        input = try AVCaptureDeviceInput(device: device)
        output = AVCaptureAudioDataOutput()
        audioUnit.mixer?.session.attachCapture(self)
        setSampleBufferDelegate(audioUnit)
    }

    func setSampleBufferDelegate(_ audioUnit: IOAudioUnit?) {
        dataOutput = audioUnit?.makeDataOutput(track)
        output?.setSampleBufferDelegate(dataOutput, queue: audioUnit?.lockQueue)
    }
}

@available(tvOS 17.0, *)
final class IOAudioCaptureUnitDataOutput: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let track: UInt8
    private let audioMixer: any IOAudioMixerConvertible

    init(track: UInt8, audioMixer: any IOAudioMixerConvertible) {
        self.track = track
        self.audioMixer = audioMixer
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        audioMixer.append(sampleBuffer, track: track)
    }
}
#endif
