#if os(iOS) || os(tvOS) || os(macOS)
import AVFoundation
import Foundation

enum IOCaptureUnitError: Error {
    case noDeviceAvailable
}

@available(tvOS 17.0, *)
protocol IOCaptureUnit {
    associatedtype Output: AVCaptureOutput

    var input: AVCaptureInput? { get set }
    var output: Output? { get set }
    var connection: AVCaptureConnection? { get set }
}

@available(tvOS 17.0, *)
extension IOCaptureUnit {
    func attachSession(_ session: AVCaptureSession?) {
        guard let session else {
            return
        }
        if let connection {
            if let input, session.canAddInput(input) {
                session.addInputWithNoConnections(input)
            }
            if let output, session.canAddOutput(output) {
                session.addOutputWithNoConnections(output)
            }
            if session.canAddConnection(connection) {
                session.addConnection(connection)
            }
        } else {
            if let input, session.canAddInput(input) {
                session.addInput(input)
            }
            if let output, session.canAddOutput(output) {
                session.addOutput(output)
            }
        }
    }

    func detachSession(_ session: AVCaptureSession?) {
        guard let session else {
            return
        }
        if let connection {
            if output?.connections.contains(connection) == true {
                session.removeConnection(connection)
            }
        }
        if let input, session.inputs.contains(input) {
            session.removeInput(input)
        }
        if let output, session.outputs.contains(output) {
            session.removeOutput(output)
        }
    }
}

#endif
