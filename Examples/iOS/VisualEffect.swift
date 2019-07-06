import AVFoundation
import HaishinKit
import UIKit

final class CurrentTimeEffect: VideoEffect {

    let filter: CIFilter? = CIFilter(name: "CISourceOverCompositing")

    let label: UILabel = {
        let label = UILabel()
        label.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        return label
    }()

    override func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        let now = Date()
        label.text = now.description

        UIGraphicsBeginImageContext(image.extent.size)
        label.drawText(in: CGRect(x: 0, y: 0, width: 200, height: 200))
        let result = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!, options: nil)!
        UIGraphicsEndImageContext()

        filter!.setValue(result, forKey: "inputImage")
        filter!.setValue(image, forKey: "inputBackgroundImage")

        return filter!.outputImage!
    }
}

final class PronamaEffect: VideoEffect {
    let filter: CIFilter? = CIFilter(name: "CISourceOverCompositing")

    var extent = CGRect.zero {
        didSet {
            if extent == oldValue {
                return
            }
            UIGraphicsBeginImageContext(extent.size)
            let image = UIImage(named: "Icon.png")!
            image.draw(at: CGPoint(x: 50, y: 50))
            pronama = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!, options: nil)
            UIGraphicsEndImageContext()
        }
    }
    var pronama: CIImage?

    override init() {
        super.init()
    }

    override func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        guard let filter: CIFilter = filter else {
            return image
        }
        extent = image.extent
        filter.setValue(pronama!, forKey: "inputImage")
        filter.setValue(image, forKey: "inputBackgroundImage")
        return filter.outputImage!
    }
}

final class MonochromeEffect: VideoEffect {
    let filter: CIFilter? = CIFilter(name: "CIColorMonochrome")

    override func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        guard let filter: CIFilter = filter else {
            return image
        }
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(CIColor(red: 0.75, green: 0.75, blue: 0.75), forKey: "inputColor")
        filter.setValue(1.0, forKey: "inputIntensity")
        return filter.outputImage!
    }
}
