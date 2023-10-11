import CoreImage
import CoreMedia
import Foundation

protocol IOVideoMixerDelegate: AnyObject {
    func videoMixer(_ videoMixer: IOVideoMixer<Self>, didOutput imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime)
}

private let kIOVideoMixer_defaultAttributes: [NSString: NSObject] = [
    kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
    kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue
]

final class IOVideoMixer<T: IOVideoMixerDelegate> {
    var muted = false
    var multiCamCaptureSettings: MultiCamCaptureSettings = .default
    weak var delegate: T?
    var context: CIContext = .init()
    private var extent = CGRect.zero {
        didSet {
            guard extent != oldValue else {
                return
            }
            CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary?, &pixelBufferPool)
            pixelBufferPool?.createPixelBuffer(&pixelBuffer)
        }
    }
    private var attributes: [NSString: NSObject] {
        var attributes: [NSString: NSObject] = kIOVideoMixer_defaultAttributes
        attributes[kCVPixelBufferWidthKey] = NSNumber(value: Int(extent.width))
        attributes[kCVPixelBufferHeightKey] = NSNumber(value: Int(extent.height))
        return attributes
    }
    private var buffer: CVPixelBuffer?
    private var pixelBuffer: CVPixelBuffer?
    private var pixelBufferPool: CVPixelBufferPool?
    private var multiCamSampleBuffer: CMSampleBuffer?
    private(set) var effects: Set<VideoEffect> = []

    @inline(__always)
    func effect(_ buffer: CVImageBuffer, info: CMSampleBuffer?) -> CIImage {
        var image = CIImage(cvPixelBuffer: buffer)
        for effect in effects {
            image = effect.execute(image, info: info)
        }
        return image
    }

    func registerEffect(_ effect: VideoEffect) -> Bool {
        effect.ciContext = context
        return effects.insert(effect).inserted
    }

    func unregisterEffect(_ effect: VideoEffect) -> Bool {
        effect.ciContext = nil
        return effects.remove(effect) != nil
    }

    func append(_ sampleBuffer: CMSampleBuffer, channel: Int, isVideoMirrored: Bool) {
        switch channel {
        case 0:
            var imageBuffer: CVImageBuffer?
            guard let buffer = sampleBuffer.imageBuffer else {
                return
            }
            buffer.lockBaseAddress()
            defer {
                buffer.unlockBaseAddress()
                imageBuffer?.unlockBaseAddress()
            }
            #if os(macOS)
            if isVideoMirrored {
                buffer.reflectHorizontal()
            }
            #endif
            if let multiCamPixelBuffer = multiCamSampleBuffer?.imageBuffer {
                multiCamPixelBuffer.lockBaseAddress()
                switch multiCamCaptureSettings.mode {
                case .pip:
                    buffer.over(
                        multiCamPixelBuffer,
                        regionOfInterest: multiCamCaptureSettings.regionOfInterest,
                        radius: multiCamCaptureSettings.cornerRadius
                    )
                case .splitView:
                    buffer.split(multiCamPixelBuffer, direction: multiCamCaptureSettings.direction)
                }
                multiCamPixelBuffer.unlockBaseAddress()
            }
            if !effects.isEmpty {
                let image = effect(buffer, info: sampleBuffer)
                extent = image.extent
                #if os(macOS)
                pixelBufferPool?.createPixelBuffer(&imageBuffer)
                #else
                if buffer.width != Int(extent.width) || buffer.height != Int(extent.height) {
                    pixelBufferPool?.createPixelBuffer(&imageBuffer)
                }
                #endif
                imageBuffer?.lockBaseAddress()
                context.render(image, to: imageBuffer ?? buffer)
            }
            if muted {
                imageBuffer = pixelBuffer
            }
            delegate?.videoMixer(self, didOutput: imageBuffer ?? buffer, presentationTimeStamp: sampleBuffer.presentationTimeStamp)
            if !muted {
                pixelBuffer = buffer
            }
        case 1:
            multiCamSampleBuffer = sampleBuffer
        default:
            break
        }
    }
}
