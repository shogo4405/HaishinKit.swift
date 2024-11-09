import AVFoundation
import Foundation

#if os(iOS) || os(tvOS) || os(macOS)
@available(tvOS 17.0, *)
extension AVCaptureSession.Preset {
    static let `default`: AVCaptureSession.Preset = .hd1280x720

    var width: Int32? {
        switch self {
        case .hd1920x1080:
            return 1920
        case .hd1280x720:
            return 1280
        case .vga640x480:
            return 640
        case .cif352x288:
            return 352
        default:
            return nil
        }
    }

    var height: Int32? {
        switch self {
        case .hd1920x1080:
            return 1080
        case .hd1280x720:
            return 720
        case .vga640x480:
            return 480
        case .cif352x288:
            return 288
        default:
            return nil
        }
    }
}
#endif
