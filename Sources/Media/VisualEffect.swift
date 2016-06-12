import CoreImage
import Foundation

public class VisualEffect: NSObject {

    public var context:CIContext?

    public func execute(image: CIImage) -> CIImage {
        return image
    }
}
