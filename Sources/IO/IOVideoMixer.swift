import CoreImage
import CoreMedia
import Foundation

protocol IOVideoMixerDelegate: AnyObject {
    func videoMixer(_ videoMixer: IOVideoMixer<Self>, didOutput imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime)
    func videoMixer(_ videoMixer: IOVideoMixer<Self>, didOutput sampleBUffer: CMSampleBuffer)
}

private let kIOVideoMixer_defaultAttributes: [NSString: NSObject] = [
    kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
    kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue
]

final class IOVideoMixer<T: IOVideoMixerDelegate> {
    var muted = false
    var settings: IOVideoMixerSettings = .default
    weak var delegate: T?
    var context: CIContext = .init() {
        didSet {
            for effect in effects {
                effect.ciContext = context
            }
        }
    }
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
    private(set) var effects: [VideoEffect] = .init()

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
        if effects.contains(effect) {
            return false
        }
        effects.append(effect)
        return true
    }

    func unregisterEffect(_ effect: VideoEffect) -> Bool {
        effect.ciContext = nil
        if let index = effects.firstIndex(of: effect) {
            effects.remove(at: index)
            return true
        }
        return false
    }

    func append(_ sampleBuffer: CMSampleBuffer, channel: UInt8, isVideoMirrored: Bool) {
        if channel == settings.channel {
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
                switch settings.mode {
                case .pip:
                    buffer.over(
                        multiCamPixelBuffer,
                        regionOfInterest: settings.regionOfInterest,
                        radius: settings.cornerRadius
                    )
                case .splitView:
                    buffer.split(multiCamPixelBuffer, direction: settings.direction)
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
            delegate?.videoMixer(self, didOutput: sampleBuffer)
        } else {
            multiCamSampleBuffer = sampleBuffer
        }
    }

    func detach(_ channel: UInt8) {
        switch channel {
        case 0:
            pixelBuffer = nil
        case 1:
            multiCamSampleBuffer = nil
        default:
            break
        }
    }
}
