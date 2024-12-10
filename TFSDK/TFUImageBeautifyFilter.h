#import <Foundation/Foundation.h>


// 确保类和方法使用 @objc 修饰符
@interface TFUImageBeautifyFilter : NSObject

// 使用 @objc 修饰符暴露给 Swift
- (CIImage *)applyFilter:(CIImage *)oldImage;

@end
