//
//  TFFilter.swift
//  TFSRT
//
//  Created by moRui on 2024/12/5.
//

import UIKit
import CoreImage
import TFGPUImage
//import GPUImageBeautifyFilter
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
        
        return self.applyFilter(to: image)
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
extension Data {
    func chunk(_ size: Int) -> [Data] {
        if count < size {
            return [self]
        }
        var chunks: [Data] = []
        let length = count
        var offset = 0
        repeat {
            let thisChunkSize = ((length - offset) > size) ? size : (length - offset)
            chunks.append(subdata(in: offset..<offset + thisChunkSize))
            offset += thisChunkSize
        } while offset < length
        return chunks
    }
}



final class MirrorEffect: VideoEffect {
    let filter = CIFilter(name: "CIAffineTransform")
    
    func execute(_ image: CIImage) -> CIImage {
        guard let filter = filter else {
            return image
        }
        
        // 创建水平翻转的变换
        let transform = CGAffineTransform(scaleX: -1, y: 1)
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(NSValue(cgAffineTransform: transform), forKey: kCIInputTransformKey)
        
        return filter.outputImage ?? image
    }
}
