#if os(iOS) || os(tvOS) || os(macOS)
import AVFoundation
import Foundation

@available(tvOS 17.0, *)
final class IOAudioCaptureUnit: IOCaptureUnit {
    typealias Output = AVCaptureAudioDataOutput

    private(set) var device: AVCaptureDevice?
    var input: AVCaptureInput?
    var output: Output?
    var connection: AVCaptureConnection?

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
        output?.setSampleBufferDelegate(audioUnit, queue: audioUnit?.lockQueue)
    }
}
#endif
