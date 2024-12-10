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

    func calculateNewWatermarkFrame(originalFrame: CGRect, imageExtent: CGSize, screenBounds: CGRect) -> CGRect {
        // 计算缩放因子
        let scaleFactorWidth = imageExtent.width / screenBounds.width
        let scaleFactorHeight = imageExtent.height / screenBounds.height
        let scaleFactor = min(scaleFactorWidth, scaleFactorHeight)
        
        // 调整水印帧的位置和大小
        var newFrame = originalFrame
        newFrame.origin.x *= scaleFactor
        newFrame.origin.y *= scaleFactor
        newFrame.size.width *= scaleFactor
        newFrame.size.height *= scaleFactor
        
        return newFrame
    }

    // 在你的 execute 方法中使用
    func execute(_ image: CIImage) -> CIImage {
        if type == .watermark {
            guard let watermark = watermark else { return image }
            guard let filter: CIFilter = watermarkFilter else { return image }
            
            // 使用新方法计算水印帧
            let newWatermarkFrame = calculateNewWatermarkFrame(
                originalFrame: watermarkFrame,
                imageExtent: image.extent.size,
                screenBounds: UIScreen.main.bounds
            )
            
            UIGraphicsBeginImageContext(image.extent.size)
            
            // 将水印绘制到上下文中，使用新的帧
            watermark.draw(in: newWatermarkFrame)
            
            if let pronama = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!) {
                UIGraphicsEndImageContext()
                filter.setValue(pronama, forKey: "inputImage")
                filter.setValue(image, forKey: "inputBackgroundImage")
                
                if let outputImage = filter.outputImage {
                    return outputImage
                }
            }
            UIGraphicsEndImageContext()
        }
        
        return mageBeautifyFilter.apply(image)!
    }
    
//    func execute(_ image: CIImage) -> CIImage {
//      //水印
//        if(type == .watermark)
//        {
//
//            guard let watermark = watermark else { return image }
//            guard let filter: CIFilter = watermarkFilter else {return image}
//
//            //image.extent.size 是摄像头分辨率的大小
//            UIGraphicsBeginImageContext(image.extent.size)
//            watermark.draw(in: watermarkFrame )
//
//            let pronama = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!, options: nil)
//            UIGraphicsEndImageContext()
//            filter.setValue(pronama!, forKey: "inputImage")
//            filter.setValue(image, forKey: "inputBackgroundImage")
//
//            guard let outputImage = filter.outputImage else {
//                return image
//            }
//            return outputImage
//        }
//
//        return mageBeautifyFilter.apply(image)!
//
//    }
}
