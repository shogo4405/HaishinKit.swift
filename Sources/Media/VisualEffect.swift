import CoreImage
import Foundation

open class VisualEffect: NSObject {
    open func execute(_ image: CIImage) -> CIImage {
        return image
    }
}
