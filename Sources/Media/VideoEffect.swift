import AVFoundation
import CoreImage
import Foundation

/// An object that apply a video effect.
/// - seealso: https://developer.apple.com/documentation/coreimage/processing_an_image_using_built-in_filters
///
/// ## Example code:
/// ```
/// final class MonochromeEffect: VideoEffect {
///     let filter: CIFilter? = CIFilter(name: "CIColorMonochrome")
///
///     override func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
///         guard let filter: CIFilter = filter else {
///             return image
///         }
///         filter.setValue(image, forKey: "inputImage")
///         filter.setValue(CIColor(red: 0.75, green: 0.75, blue: 0.75), forKey: "inputColor")
///         filter.setValue(1.0, forKey: "inputIntensity")
///         return filter.outputImage ?? image
///     }
/// }
/// ```
open class VideoEffect: NSObject {
    /// Specifies the ciContext object.
    public var ciContext: CIContext?

    /// Executes to apply a video effect.
    open func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        image
    }
}
