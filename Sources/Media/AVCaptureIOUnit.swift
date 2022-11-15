#if os(iOS) || os(macOS)
import AVFoundation
import Foundation

struct AVCaptureIOUnit<T: AVCaptureOutput> {
    let input: AVCaptureInput
    let output: T
    var device: AVCaptureDevice? {
        (input as? AVCaptureDeviceInput)?.device
    }

    init(_ input: AVCaptureInput, factory: () -> T) {
        self.input = input
        self.output = factory()
    }

    func attach(_ session: AVCaptureSession?) {
        guard let session else {
            return
        }
        if session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
    }

    func detach(_ session: AVCaptureSession?) {
        guard let session else {
            return
        }
        session.removeInput(input)
        session.removeOutput(output)
    }
}
#endif
