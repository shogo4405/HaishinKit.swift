import CoreImage
import Foundation
import AVFoundation

open class VisualEffect: NSObject {
    open var ciContext: CIContext?
    open func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        return image
    }
}
