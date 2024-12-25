//
//  TFVideoViewTool.h
//  newVideo
//
//  Created by moRui on 2024/12/25.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

@interface TFVideoViewTool : NSObject
+(CVPixelBufferRef)pixelBufferFromCGImage: (CGImageRef)image;
@end

NS_ASSUME_NONNULL_END
