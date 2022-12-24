import AVFoundation
import Foundation

#if os(iOS)
extension AVCaptureDevice {
    func videoFormat(width: Int32, height: Int32, isMultiCamSupported: Bool) -> AVCaptureDevice.Format? {
        if #available(iOS 13.0, *), isMultiCamSupported {
            return formats.first {
                $0.isMultiCamSupported && width <= $0.formatDescription.dimensions.width && height <= $0.formatDescription.dimensions.height
            } ?? formats.last {
                $0.isMultiCamSupported && $0.formatDescription.dimensions.width < width && $0.formatDescription.dimensions.height < height
            }
        } else {
            return formats.first {
                width <= $0.formatDescription.dimensions.width && height <= $0.formatDescription.dimensions.height
            } ?? formats.last {
                $0.formatDescription.dimensions.width < width && $0.formatDescription.dimensions.height < height
            }
        }
    }
}
#endif

#if os(macOS)
extension AVCaptureDevice {
    func videoFormat(width: Int32, height: Int32, isMultiCamSupported: Bool) -> AVCaptureDevice.Format? {
        return formats.first {
            width <= $0.formatDescription.dimensions.width && height <= $0.formatDescription.dimensions.height
        } ?? formats.last {
            $0.formatDescription.dimensions.width < width && $0.formatDescription.dimensions.height < height
        }
    }
}
#endif
