import CoreImage
import Foundation
import AVFoundation

open class VisualEffect: NSObject {
    open func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        return image
    }
}
