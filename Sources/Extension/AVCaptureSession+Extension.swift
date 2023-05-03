import AVFoundation
import Foundation

#if targetEnvironment(macCatalyst)
extension AVCaptureSession {
    var isMultitaskingCameraAccessSupported: Bool {
        get {
            false
        }
        // swiftlint:disable unused_setter_value
        set {
            logger.warn("isMultitaskingCameraAccessSupported is unavailabled in Mac Catalyst.")
        }
    }

    var isMultitaskingCameraAccessEnabled: Bool {
        get {
            false
        }
        // swiftlint:disable unused_setter_value
        set {
            logger.warn("isMultitaskingCameraAccessEnabled is unavailabled in Mac Catalyst.")
        }
    }
}
#endif
