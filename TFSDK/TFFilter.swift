//
//  TFFilter.swift
//  TFSRT
//
//  Created by moRui on 2024/12/5.
//

import UIKit

enum TFFilterType {
    case watermark //水印
    case filters  //滤镜
}
class TFFilter: VideoEffect {
    var type:TFFilterType = .filters

    //水印图片
    var watermark:UIImage?
    //水印图片位置
    var watermarkFrame:CGRect = .zero

    let watermarkFilter: CIFilter? = CIFilter(name: "CISourceOverCompositing")
    let mageBeautifyFilter = TFUImageBeautifyFilter()
    
    func execute(_ image: CIImage) -> CIImage {
      //水印
        if(type == .watermark)
        {
            guard let filter: CIFilter = watermarkFilter else {
                return image
            }

            // 假设 watermark 和 watermarkFrame 已定义
            guard let watermark = watermark else { return image }

            UIGraphicsBeginImageContext(image.extent.size)
            watermark.draw(in: watermarkFrame)

            let pronama = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!, options: nil)
            UIGraphicsEndImageContext()
            filter.setValue(pronama!, forKey: "inputImage")
            filter.setValue(image, forKey: "inputBackgroundImage")
            
            guard let outputImage = filter.outputImage else {
                return image
            }
            return outputImage
        }
        
        return mageBeautifyFilter.apply(image)!
        //过滤层
//        if let options = self.options {
//            //默认
//            if options.ciFilterName==nil {
//                return image
//            }
//            return self.applyFilter(with: image, options: options)
//        }
//        return image
    }

//    var filter:CIFilter?
//    func applyFilter(with sourceImage: CIImage, options: TFFilterOptions) -> CIImage {
//        guard let ciFilterName = options.ciFilterName else {
//            return sourceImage
//        }
//
//        if filter==nil {
//            filter = CIFilter(name: ciFilterName)
//        }
//      
//        if let filter = filter {
//            filter.setDefaults()
//            filter.setValue(sourceImage, forKey: kCIInputImageKey)
//
//            guard let ciFilterName = filter.outputImage else {
//                return sourceImage
//            }
//            return ciFilterName
//        }
//        //原数据
//        return sourceImage
//    }
}


//import CoreImage
//public struct TFFilterOptions {
//    let name: String
//    let ciFilterName: String?
//
//    public init(name: String, ciFilterName: String?) {
//        self.name = name
//        self.ciFilterName = ciFilterName
//    }
//}
//
//extension TFFilterOptions: Equatable {
//    public static func ==(lhs: TFFilterOptions, rhs: TFFilterOptions) -> Bool {
//        return lhs.name == rhs.name
//    }
//}
//
//extension TFFilterOptions {
//    static var all: [TFFilterOptions] = [
//        TFFilterOptions(name: "Normal", ciFilterName: nil),
//        TFFilterOptions(name: "Chrome", ciFilterName: "CIPhotoEffectChrome"),
//        TFFilterOptions(name: "Fade", ciFilterName: "CIPhotoEffectFade"),
//        TFFilterOptions(name: "Instant", ciFilterName: "CIPhotoEffectInstant"),
//        TFFilterOptions(name: "Mono", ciFilterName: "CIPhotoEffectMono"),
//        TFFilterOptions(name: "Noir", ciFilterName: "CIPhotoEffectNoir"),
//        TFFilterOptions(name: "Process", ciFilterName: "CIPhotoEffectProcess"),
//        TFFilterOptions(name: "Tonal", ciFilterName: "CIPhotoEffectTonal"),
//        TFFilterOptions(name: "Transfer", ciFilterName: "CIPhotoEffectTransfer"),
//        TFFilterOptions(name: "Tone", ciFilterName: "CILinearToSRGBToneCurve"),
//        TFFilterOptions(name: "Linear", ciFilterName: "CISRGBToneCurveToLinear"),
//        TFFilterOptions(name: "Sepia", ciFilterName: "CISepiaTone"),
//    ]
//}
