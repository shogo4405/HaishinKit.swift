#if os(iOS) || os(macOS)
import AVFoundation
import Foundation

protocol IOCaptureUnit {
    associatedtype Output: AVCaptureOutput

    var input: AVCaptureInput { get }
    var output: Output { get }
    var connection: AVCaptureConnection? { get }
}

extension IOCaptureUnit {
    func attachSession(_ session: AVCaptureSession?) {
        guard let session else {
            return
        }
        if let connection {
            if session.canAddInput(input) {
                session.addInputWithNoConnections(input)
            }
            if session.canAddOutput(output) {
                session.addOutputWithNoConnections(output)
            }
            if session.canAddConnection(connection) {
                session.addConnection(connection)
            }
        } else {
            if session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
        }
    }

    func detachSession(_ session: AVCaptureSession?) {
        guard let session else {
            return
        }
        if let connection {
            if output.connections.contains(connection) {
                session.removeConnection(connection)
            }
        }
        if session.inputs.contains(input) {
            session.removeInput(input)
        }
        if session.outputs.contains(output) {
            session.removeOutput(output)
        }
    }
}

struct IOVideoCaptureUnit: IOCaptureUnit {
    typealias Output = AVCaptureVideoDataOutput

    var device: AVCaptureDevice? {
        (input as? AVCaptureDeviceInput)?.device
    }

    let input: AVCaptureInput
    let output: Output
    let connection: AVCaptureConnection?
}

struct IOAudioCaptureUnit: IOCaptureUnit {
    typealias Output = AVCaptureAudioDataOutput

    let input: AVCaptureInput
    let output: Output
    let connection: AVCaptureConnection?
}
#endif
