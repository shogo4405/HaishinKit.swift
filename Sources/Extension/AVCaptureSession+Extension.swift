import AVFoundation
import Foundation

// swiftlint:disable unused_setter_value
#if targetEnvironment(macCatalyst)
extension AVCaptureSession {
    var isMultitaskingCameraAccessSupported: Bool {
        false
    }

    var isMultitaskingCameraAccessEnabled: Bool {
        get {
            false
        }
        set {
            logger.warn("isMultitaskingCameraAccessEnabled is unavailabled in Mac Catalyst.")
        }
    }
}
#elseif os(iOS) || os(macOS)
extension AVCaptureSession {
    @available(iOS, obsoleted: 16.0)
    var isMultitaskingCameraAccessSupported: Bool {
        false
    }

    @available(iOS, obsoleted: 16.0)
    var isMultitaskingCameraAccessEnabled: Bool {
        get {
            false
        }
        set {
            logger.warn("isMultitaskingCameraAccessEnabled is unavailabled in under iOS 16.")
        }
    }
}
#endif
// swiftlint:enable unused_setter_value
