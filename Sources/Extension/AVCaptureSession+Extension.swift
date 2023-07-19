import AVFoundation
import Foundation

// swiftlint:disable unused_setter_value
#if targetEnvironment(macCatalyst)
extension AVCaptureSession {
    var isMultitaskingCameraAccessSupported: Bool {
        get {
            false
        }
        set {
            logger.warn("isMultitaskingCameraAccessSupported is unavailabled in Mac Catalyst.")
        }
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
#else
extension AVCaptureSession {
    @available(iOS, obsoleted: 16.0)
    var isMultitaskingCameraAccessEnabled: Bool {
        get {
            false
        }
        set {
            logger.warn("isMultitaskingCameraAccessEnabled is unavailabled in under iOS 16.")
        }
    }

    @available(iOS, obsoleted: 16.0)
    var isMultitaskingCameraAccessSupported: Bool {
        false
    }
}
#endif
// swiftlint:enable unused_setter_value
