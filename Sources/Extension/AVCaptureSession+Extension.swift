import AVFoundation
import Foundation

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
#endif
