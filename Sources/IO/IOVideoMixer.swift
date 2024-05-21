import CoreImage
import CoreMedia
import Foundation

protocol IOVideoMixerDelegate: AnyObject {
    func videoMixer(_ videoMixer: IOVideoMixer<Self>, track: UInt8, didInput sampleBuffer: CMSampleBuffer)
    func videoMixer(_ videoMixer: IOVideoMixer<Self>, didOutput imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime)
    func videoMixer(_ videoMixer: IOVideoMixer<Self>, didOutput sampleBbffer: CMSampleBuffer)
}

private let kIOVideoMixer_defaultAttributes: [NSString: NSObject] = [
    kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
    kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue
]

final class IOVideoMixer<T: IOVideoMixerDelegate> {
    var settings: IOVideoMixerSettings = .default
    weak var delegate: T?
    var context: CIContext = .init() {
        didSet {
            for effect in effects {
                effect.ciContext = context
            }
        }
    }
    var inputFormats: [UInt8: CMFormatDescription] {
        var formats: [UInt8: CMFormatDescription] = .init()
        if let sampleBuffer, let formatDescription = sampleBuffer.formatDescription {
            formats[0] = formatDescription
        }
        if let multiCamSampleBuffer, let formatDescription = multiCamSampleBuffer.formatDescription {
            formats[1] = formatDescription
        }
        return formats
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
    private var sampleBuffer: CMSampleBuffer?
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

    func append(_ track: UInt8, sampleBuffer: CMSampleBuffer) {
        delegate?.videoMixer(self, track: track, didInput: sampleBuffer)
        if track == settings.mainTrack {
            var imageBuffer: CVImageBuffer?
            guard let buffer = sampleBuffer.imageBuffer else {
                return
            }
            self.sampleBuffer = sampleBuffer
            buffer.lockBaseAddress()
            defer {
                buffer.unlockBaseAddress()
                imageBuffer?.unlockBaseAddress()
            }
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
                if settings.alwaysUseBufferPoolForVideoEffects || buffer.width != Int(extent.width) || buffer.height != Int(extent.height) {
                    pixelBufferPool?.createPixelBuffer(&imageBuffer)
                }
                #endif
                imageBuffer?.lockBaseAddress()
                context.render(image, to: imageBuffer ?? buffer)
            }
            if settings.isMuted {
                imageBuffer = pixelBuffer
            }
            delegate?.videoMixer(self, didOutput: imageBuffer ?? buffer, presentationTimeStamp: sampleBuffer.presentationTimeStamp)
            if !settings.isMuted {
                pixelBuffer = buffer
            }
            delegate?.videoMixer(self, didOutput: sampleBuffer)
        } else {
            multiCamSampleBuffer = sampleBuffer
        }
    }

    func detach(_ track: UInt8) {
        switch track {
        case 0:
            pixelBuffer = nil
            sampleBuffer = nil
        case 1:
            multiCamSampleBuffer = nil
        default:
            break
        }
    }
}
