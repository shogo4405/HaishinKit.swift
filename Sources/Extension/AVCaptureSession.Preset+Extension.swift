import AVFoundation
import Foundation

#if os(macOS)
extension AVCaptureSession.Preset {
    @available(macOS, obsoleted: 10.15)
    private static let hd1920x1080 = AVCaptureSession.Preset(rawValue: "")
}
#endif

#if os(iOS) || os(macOS)
extension AVCaptureSession.Preset {
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
