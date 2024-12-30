//
//  TFFilter.swift
//  TFSRT
//
//  Created by moRui on 2024/12/5.
//

import UIKit
import CoreImage
import TFGPUImage
//水印
class TFWatermarkFilter: TFFilter {
    //水印图片
    var watermark:UIImage?
    //水印图片位置
    var watermarkFrame:CGRect = .zero
    let watermarkFilter: CIFilter? = CIFilter(name: "CISourceOverCompositing")
    override func execute(_ image: CIImage) -> CIImage {
        
        if  isAvailable{
            guard let watermark = watermark else { return image }
            guard let filter: CIFilter = watermarkFilter else { return image }
            
            // 使用新方法计算水印帧
            let newWatermarkFrame = TFIngestTool.calculateNewWatermarkFrame(
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
        return image
    }
    
 
}
//美颜
class TFTFBeautyFilter: TFFilter {
    // 在你的 execute 方法中使用
    override func execute(_ image: CIImage) -> CIImage {

       if  isAvailable {
           //滤镜
            return self.applyFilter(to: image)
        }
        
        return image
    }
    func applyFilter(to ciImage: CIImage) -> CIImage{
        // 将 CIImage 转换为 UIImage
        guard let oldImage = convertCIImageToUIImage(ciImage) else { return ciImage }
        
        // 使用美颜效果的滤镜 GPUImageBeautifyFilter
        let beautifyFilter = GPUImageBeautifyFilter()
        
        // 设置要渲染的区域
        beautifyFilter.forceProcessing(at: oldImage.size)
        
        // 使用下一帧进行图像捕获
        beautifyFilter.useNextFrameForImageCapture()
        
        // 设置图片数据源
        let stillImageSource = GPUImagePicture(image: oldImage)
        
        // 添加上美颜效果的滤镜
        stillImageSource?.addTarget(beautifyFilter)
        
        // 开始渲染
        stillImageSource?.processImage()
        
        // 获取渲染后的图片
        guard let filteredImage = beautifyFilter.imageFromCurrentFramebuffer() else { return ciImage }
        
        // 将 UIImage 转换回 CIImage
        guard let convertedCIImage = convertUIImageToCIImage(filteredImage) else { return ciImage }
        
        return convertedCIImage
    }

    private func convertUIImageToCIImage(_ image: UIImage) -> CIImage? {
        // 如果 UIImage 是基于 CGImage 创建的，可以直接转换
        if let cgImage = image.cgImage {
            return CIImage(cgImage: cgImage)
        }
        return nil
    }

    private func convertCIImageToUIImage(_ ciImage: CIImage) -> UIImage? {
        // 创建 CIContext
        let context = CIContext(options: nil)
        
        // 渲染 CIImage 到 CGImage
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        // 将 CGImage 转换为 UIImage
        return UIImage(cgImage: cgImage)
    }
}
//裁剪
class TFCropRectFilter: TFFilter {
    
    public var videoSize: CGSize = .zero

    override func execute(_ image: CIImage) -> CIImage {
        
        if  isAvailable{
            let originalSize = image.extent.size
            
            if videoSize.width/videoSize.height>originalSize.width/originalSize.height {
                
                
                let height = originalSize.width*(videoSize.width/videoSize.height)
//                let cropRectY =  (originalSize.height-height)/2
                let cropRect = CGRect(
                    x: 0,
                    y: 0,
                    width: originalSize.width,
                    height:height
                )
                
                
                let new_image = image.cropped(to: cropRect)
                
               if let resizedCIImage = TFIngestTool.resizeCIImage(image: new_image, targetSize: originalSize)
//                if let resizedCIImage = TFIngestTool.resizeCIImage(image: new_image, to: originalSize, mode: UIView.ContentMode.scaleAspectFit)
                {
                 return resizedCIImage
                    
                }
                
            }
            
            
        }
       
        return image
    }
  
}


//格挡
class TFCameraPictureFilter: TFFilter {
    public var videoSize: CGSize = .zero
    var imageRef:CIImage? = nil
    override init() {
        super.init()
        
        let pictureFile = "CloudLiveSDKFramework.bundle/camera_\(Int(self.videoSize.width))x\(Int(self.videoSize.height)).png"

        if !FileManager.default.fileExists(atPath: pictureFile) {
            let fallbackPictureFile = "CloudLiveSDKFramework.bundle/camera_320x240.png"
            let myImage = UIImage(named: fallbackPictureFile)
            // 尝试直接获取 CIImage
            imageRef = myImage?.ciImage

            // 如果 ciImage 属性为 nil，则通过 CIImage(image:) 创建
            if imageRef == nil {
                if let cgImage = myImage?.cgImage {
                    imageRef = CIImage(cgImage: cgImage)
                }
            }

        }
    }

    override func execute(_ image: CIImage) -> CIImage {
        if isAvailable{
            if let new_image = imageRef
            {
              let originalSize = image.extent.size
              
                if let resizedCIImage = TFIngestTool.resizeCIImage(image: new_image, to: originalSize, mode: UIView.ContentMode.scaleAspectFit) {
                    
    
                    
//                if let resizedCIImage = TFIngestTool.resizeCIImage(image: new_image, targetSize: originalSize){
                    
                       return resizedCIImage
                   }
             
            }
        }
        return image
    }
}

class TFFilter: VideoEffect {
    //是否启用
    var isAvailable:Bool = false

    // 在你的 execute 方法中使用
    func execute(_ image: CIImage) -> CIImage {

        return image
    }

}


