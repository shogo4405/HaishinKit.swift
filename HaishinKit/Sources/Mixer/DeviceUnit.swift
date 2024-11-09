import AVFoundation
import Foundation

@available(tvOS 17.0, *)
protocol DeviceUnit {
    associatedtype Output: AVCaptureOutput

    var track: UInt8 { get }
    var input: AVCaptureInput? { get  }
    var output: Output? { get }
    var device: AVCaptureDevice? { get }
    var connection: AVCaptureConnection? { get }

    init(_ track: UInt8)
}
