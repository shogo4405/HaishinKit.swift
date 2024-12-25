//
//  TFVideoViewTool.m
//  newVideo
//
//  Created by moRui on 2024/12/25.
//

#import "TFVideoViewTool.h"

@implementation TFVideoViewTool
+(CVPixelBufferRef)pixelBufferFromCGImage: (CGImageRef) image
{
    NSDictionary *options = @{
                              (NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,
                              (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
                              };
    
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, CGImageGetWidth(image),
                                          CGImageGetHeight(image), kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    if (status!=kCVReturnSuccess) {
//        NSLog(@"Operation failed");
    }
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, CGImageGetWidth(image),
                                                 CGImageGetHeight(image), 8, 4*CGImageGetWidth(image), rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    CGAffineTransform flipVertical = CGAffineTransformMake( 1, 0, 0, -1, 0, CGImageGetHeight(image) );
    CGContextConcatCTM(context, flipVertical);
    CGAffineTransform flipHorizontal = CGAffineTransformMake( -1.0, 0.0, 0.0, 1.0, CGImageGetWidth(image), 0.0 );
    CGContextConcatCTM(context, flipHorizontal);
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    return pxbuffer;
}
@end
