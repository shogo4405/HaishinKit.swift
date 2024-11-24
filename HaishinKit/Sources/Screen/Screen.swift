import AVFoundation
import Foundation

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// An interface a screen uses to inform its delegate.
public protocol ScreenDelegate: AnyObject {
    /// Tells the receiver to screen object layout phase.
    func screen(_ screen: Screen, willLayout time: CMTime)
}

/// An object that manages offscreen rendering a foundation.
public final class Screen: ScreenObjectContainerConvertible {
    /// The default screen size.
    public static let size = CGSize(width: 1280, height: 720)

    private static let lockFrags = CVPixelBufferLockFlags(rawValue: 0)

    /// The total of child counts.
    public var childCounts: Int {
        return root.childCounts
    }

    /// Specifies the delegate object.
    public weak var delegate: (any ScreenDelegate)?

    /// Specifies the video size to use when output a video.
    public var size: CGSize = Screen.size {
        didSet {
            guard size != oldValue else {
                return
            }
            renderer.bounds = .init(origin: .zero, size: size)
            CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary?, &pixelBufferPool)
        }
    }

    #if os(macOS)
    /// Specifies the background color.
    public var backgroundColor: CGColor = NSColor.black.cgColor {
        didSet {
            guard backgroundColor != oldValue else {
                return
            }
            renderer.backgroundColor = backgroundColor
        }
    }
    #else
    /// Specifies the background color.
    public var backgroundColor: CGColor = UIColor.black.cgColor {
        didSet {
            guard backgroundColor != oldValue else {
                return
            }
            renderer.backgroundColor = backgroundColor
        }
    }
    #endif

    var videoTrackScreenObject = VideoTrackScreenObject()
    private var root: ScreenObjectContainer = .init()
    private(set) var renderer = ScreenRendererByCPU()
    private var timeStamp: CMTime = .invalid
    private var attributes: [NSString: NSObject] {
        return [
            kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32ARGB),
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferWidthKey: NSNumber(value: Int(size.width)),
            kCVPixelBufferHeightKey: NSNumber(value: Int(size.height))
        ]
    }
    private var outputFormat: CMFormatDescription?
    private var pixelBufferPool: CVPixelBufferPool? {
        didSet {
            outputFormat = nil
        }
    }

    /// Creates a screen object.
    public init() {
        try? addChild(videoTrackScreenObject)
        CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary?, &pixelBufferPool)
    }

    /// Adds the specified screen object as a child of the current screen object container.
    public func addChild(_ child: ScreenObject?) throws {
        try root.addChild(child)
    }

    /// Removes the specified screen object as a child of the current screen object container.
    public func removeChild(_ child: ScreenObject?) {
        root.removeChild(child)
    }

    /// Registers a video effect.
    public func registerVideoEffect(_ effect: some VideoEffect) -> Bool {
        return videoTrackScreenObject.registerVideoEffect(effect)
    }

    /// Unregisters a video effect.
    public func unregisterVideoEffect(_ effect: some VideoEffect) -> Bool {
        return videoTrackScreenObject.unregisterVideoEffect(effect)
    }

    func append(_ track: UInt8, buffer: CMSampleBuffer) {
        let screens: [VideoTrackScreenObject] = root.getScreenObjects()
        for screen in screens where screen.track == track {
            screen.enqueue(buffer)
        }
    }

    func makeSampleBuffer() -> CMSampleBuffer? {
        var pixelBuffer: CVPixelBuffer?
        pixelBufferPool?.createPixelBuffer(&pixelBuffer)
        guard let pixelBuffer else {
            return nil
        }
        if outputFormat == nil {
            CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                formatDescriptionOut: &outputFormat
            )
        }
        guard let outputFormat else {
            return nil
        }
        if let dictionary = CVBufferGetAttachments(pixelBuffer, .shouldNotPropagate) {
            CVBufferSetAttachments(pixelBuffer, dictionary, .shouldPropagate)
        }
        let now = CMClock.hostTimeClock.time
        var timingInfo = CMSampleTimingInfo(
            duration: timeStamp == .invalid ? .zero : now - timeStamp,
            presentationTimeStamp: now,
            decodeTimeStamp: .invalid
        )
        timeStamp = now
        var sampleBuffer: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: outputFormat,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        ) == noErr else {
            return nil
        }
        if let sampleBuffer {
            return render(sampleBuffer)
        } else {
            return nil
        }
    }

    func render(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        try? sampleBuffer.imageBuffer?.lockBaseAddress(Self.lockFrags)
        defer {
            try? sampleBuffer.imageBuffer?.unlockBaseAddress(Self.lockFrags)
        }
        renderer.setTarget(sampleBuffer.imageBuffer)
        if let dimensions = sampleBuffer.formatDescription?.dimensions {
            root.size = dimensions.size
        }
        delegate?.screen(self, willLayout: sampleBuffer.presentationTimeStamp)
        root.layout(renderer)
        root.draw(renderer)
        return sampleBuffer
    }
}
