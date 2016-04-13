import Foundation
import lf
import UIKit
import AVFoundation

final class PronamaEffect: VisualEffect {
    let filter:CIFilter? = CIFilter(name: "CISourceOverCompositing")

    var extent:CGRect = CGRectZero {
        didSet {
            if (extent == oldValue) {
                return
            }
            UIGraphicsBeginImageContext(extent.size)
            let image:UIImage = UIImage(named: "Icon.png")!
            image.drawAtPoint(CGPointMake(50, 50))
            pronama = CIImage(image: UIGraphicsGetImageFromCurrentImageContext(), options: nil)
            UIGraphicsEndImageContext()
        }
    }
    var pronama:CIImage?

    override init() {
        super.init()
    }

    override func execute(image: CIImage) -> CIImage {
        guard let filter:CIFilter = filter else {
            return image
        }
        extent = image.extent
        filter.setValue(pronama!, forKey: "inputImage")
        filter.setValue(image, forKey: "inputBackgroundImage")
        return filter.outputImage!
    }
}

final class MonochromeEffect: VisualEffect {
    let filter:CIFilter? = CIFilter(name: "CIColorMonochrome")

    override func execute(image: CIImage) -> CIImage {
        guard let filter:CIFilter = filter else {
            return image
        }
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(CIColor(red: 0.75, green: 0.75, blue: 0.75), forKey: "inputColor")
        filter.setValue(1.0, forKey: "inputIntensity")
        return filter.outputImage!
    }
}
