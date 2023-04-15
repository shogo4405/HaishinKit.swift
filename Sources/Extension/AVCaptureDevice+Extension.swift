import AVFoundation
import Foundation

extension AVCaptureDevice {
    func videoFormat(width: Int32, height: Int32, frameRate: Float64, isMultiCamSupported: Bool) -> AVCaptureDevice.Format? {
        if isMultiCamSupported {
            return formats.first {
                $0.isMultiCamSupported && $0.isFrameRateSupported(frameRate) && width <= $0.formatDescription.dimensions.width && height <= $0.formatDescription.dimensions.height
            } ?? formats.last {
                $0.isMultiCamSupported && $0.isFrameRateSupported(frameRate) && $0.formatDescription.dimensions.width < width && $0.formatDescription.dimensions.height < height
            }
        } else {
            return formats.first {
                $0.isFrameRateSupported(frameRate) && width <= $0.formatDescription.dimensions.width && height <= $0.formatDescription.dimensions.height
            } ?? formats.last {
                $0.isFrameRateSupported(frameRate) && $0.formatDescription.dimensions.width < width && $0.formatDescription.dimensions.height < height
            }
        }
    }
}
