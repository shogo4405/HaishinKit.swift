import HaishinKit
import CoreImage
import Foundation

final class MonochromeEffect: VisualEffect {
    let filter:CIFilter? = CIFilter(name: "CIColorMonochrome")
    
    override func execute(_ image: CIImage) -> CIImage {
        guard let filter:CIFilter = filter else {
            return image
        }
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(CIColor(red: 0.75, green: 0.75, blue: 0.75), forKey: "inputColor")
        filter.setValue(1.0, forKey: "inputIntensity")
        return filter.outputImage!
    }
}
