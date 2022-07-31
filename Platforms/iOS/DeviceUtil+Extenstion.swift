#if os(iOS)

import AVFoundation
import UIKit

extension DeviceUtil {
    /// Looks up the AVCaptureVideoOrientation by a Notification.
    public static func videoOrientation(by notification: Notification) -> AVCaptureVideoOrientation? {
        guard let device: UIDevice = notification.object as? UIDevice else {
            return nil
        }
        return videoOrientation(by: device.orientation)
    }

    /// Looks up the  AVCaptureVideoOrientation by an UIDeviceOrientation.
    public static func videoOrientation(by orientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return nil
        }
    }

    /// Looks up the AVCaptureVideoOrientation by an UIInterfaceOrientation.
    public static func videoOrientation(by orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation? {
        switch orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return nil
        }
    }
}

#endif
