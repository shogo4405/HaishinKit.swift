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
          
            guard let watermark = watermark else { return image }
            guard let filter: CIFilter = watermarkFilter else {return image}
          
            //image.extent.size 是摄像头分辨率的大小
            UIGraphicsBeginImageContext(image.extent.size)
            watermark.draw(in: watermarkFrame )

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

    }

}
