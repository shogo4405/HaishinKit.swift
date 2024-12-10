//
//  TFUImageBeautifyFilter.m
//  TFSRT
//
//  Created by moRui on 2024/12/10.
//

#import "TFUImageBeautifyFilter.h"
#import "GPUImageOutput.h"
#import "GPUImageBeautifyFilter.h"

@interface TFUImageBeautifyFilter()

@end
@implementation TFUImageBeautifyFilter

-(CIImage*)applyFilter:(CIImage*)ciImage
{
    UIImage * oldImage = [self convertCIImageToUIImage:ciImage];
    //使用美颜效果的滤镜  GPUImageBeautifyFilter
    GPUImageBeautifyFilter *disFilter = [[GPUImageBeautifyFilter alloc] init];
    
    //设置要渲染的区域
    [disFilter forceProcessingAtSize:oldImage.size];
   //使用下一帧进行图像捕获
    [disFilter useNextFrameForImageCapture];
    
    //设置图片数据源
    GPUImagePicture *stillImageSource = [[GPUImagePicture alloc]initWithImage:oldImage];
    
    //添加上美颜效果的滤镜
    [stillImageSource addTarget:disFilter];
    //开始渲染
    [stillImageSource processImage];
    //获取渲染后的图片
    UIImage *image = [disFilter imageFromCurrentFramebuffer];
    //加载出来
    CIImage *convert = [self convertUIImageToCIImage:image];
    return convert;
}
- (CIImage *)convertUIImageToCIImage:(UIImage *)image {
    CIImage *ciImage = nil;
    
    // 如果 UIImage 是基于 CGImage 创建的，可以直接转换
    if (image.CGImage) {
        ciImage = [CIImage imageWithCGImage:image.CGImage];
    }

    return ciImage;
}
- (UIImage *)convertCIImageToUIImage:(CIImage *)ciImage {
    // 创建 CIContext
    CIContext *context = [CIContext contextWithOptions:nil];
    
    // 渲染 CIImage 到 CGImageRef
    CGImageRef cgImage = [context createCGImage:ciImage fromRect:ciImage.extent];
    
    // 将 CGImageRef 转换为 UIImage
    UIImage *uiImage = [UIImage imageWithCGImage:cgImage];
    
    // 释放 CGImageRef
    CGImageRelease(cgImage);
    
    return uiImage;
}
@end
