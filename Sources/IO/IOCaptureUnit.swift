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
#endif
