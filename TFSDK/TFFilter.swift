//
//  TFFilter.swift
//  TFSRT
//
//  Created by moRui on 2024/12/5.
//

import UIKit

class TFFilter: VideoEffect {
    var state:NSInteger = -1
    func execute(_ image: CIImage) -> CIImage {
      
        return image
    }
}
//黑白
final class TFMonochromeEffect: TFFilter {
    let filter: CIFilter? = CIFilter(name: "CIColorMonochrome")

    override func execute(_ image: CIImage) -> CIImage {
        guard let filter: CIFilter = filter else {
            return image
        }
        filter.setValue(image, forKey: "inputImage")
        filter.setValue(CIColor(red: 0.75, green: 0.75, blue: 0.75), forKey: "inputColor")
        filter.setValue(1.0, forKey: "inputIntensity")
        
        guard let outputImage = filter.outputImage else {
            return image
        }
        return outputImage
    }
}

//加水印
final class TFPronamaEffect: TFFilter {
    
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

    override func execute(_ image: CIImage) -> CIImage {
        guard let filter: CIFilter = filter else {
            return image
        }
        extent = image.extent
        filter.setValue(pronama!, forKey: "inputImage")
        filter.setValue(image, forKey: "inputBackgroundImage")
        
        guard let outputImage = filter.outputImage else {
            return image
        }
        return outputImage
    }
}
