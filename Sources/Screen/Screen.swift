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

protocol ScreenObserver: AnyObject {
    func screen(_ screen: Screen, didOutput buffer: CMSampleBuffer)
}

/// An object that manages offscreen rendering a foundation.
public final class Screen: ScreenObjectContainerConvertible {
    public static let size = CGSize(width: 1280, height: 720)

    private static let lockFrags = CVPixelBufferLockFlags(rawValue: 0)

    /// The total of child counts.
    public var childCounts: Int {
        return root.childCounts
    }

    /// Specifies the delegate object.
    public weak var delegate: (any ScreenDelegate)?

    /// Specifies the frame rate to use when output a video.
    public var frameRate = 30 {
        didSet {
            guard frameRate != oldValue else {
                return
            }
            choreographer.preferredFramesPerSecond = frameRate
        }
    }

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

    public var isRunning: Atomic<Bool> {
        return choreographer.isRunning
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

    public var renderEffectsSeparately = true

    weak var observer: (any ScreenObserver)?
    private var root: ScreenObjectContainer = .init()
    private(set) var renderer = ScreenRendererByCPU()
    private lazy var choreographer: DisplayLinkChoreographer = {
        var choreographer = DisplayLinkChoreographer()
        choreographer.delegate = self
        return choreographer
    }()
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

    /// Adds the specified screen object as a child of the current screen object container.
    public func addChild(_ child: ScreenObject?) throws {
        try root.addChild(child)
    }

    /// Removes the specified screen object as a child of the current screen object container.
    public func removeChild(_ child: ScreenObject?) {
        root.removeChild(child)
    }

    func getScreenObjects<T: ScreenObject>() -> [T] {
        return root.getScreenObjects()
    }

    func render(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        sampleBuffer.imageBuffer?.lockBaseAddress(Self.lockFrags)
        defer {
            sampleBuffer.imageBuffer?.unlockBaseAddress(Self.lockFrags)
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

    func render(streamBuffer: CMSampleBuffer, viewBuffer: CMSampleBuffer) {
        streamBuffer.imageBuffer?.lockBaseAddress(Self.lockFrags)
        viewBuffer.imageBuffer?.lockBaseAddress(Self.lockFrags)
        defer {
            streamBuffer.imageBuffer?.unlockBaseAddress(Self.lockFrags)
            viewBuffer.imageBuffer?.unlockBaseAddress(Self.lockFrags)
        }
        renderer.setTarget(streamBuffer.imageBuffer, .stream)
        renderer.setTarget(viewBuffer.imageBuffer, .view)
        if let dimensions = streamBuffer.formatDescription?.dimensions {
            root.size = dimensions.size
        }
        delegate?.screen(self, willLayout: streamBuffer.presentationTimeStamp)
        root.layout(renderer)
        root.draw(renderer)
    }
}

extension Screen: Running {
    // MARK: Running
    public func startRunning() {
        guard !choreographer.isRunning.value else {
            return
        }
        CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary?, &pixelBufferPool)
        choreographer.preferredFramesPerSecond = frameRate
        choreographer.startRunning()
        choreographer.isPaused = false
    }

    public func stopRunning() {
        guard choreographer.isRunning.value else {
            return
        }
        choreographer.stopRunning()
    }
}

extension Screen: ChoreographerDelegate {
    // MARK: ChoreographerDelegate
    func choreographer(_ choreographer: some Choreographer, didFrame duration: Double) {
        var pixelBuffer: CVPixelBuffer?
        pixelBufferPool?.createPixelBuffer(&pixelBuffer)
        guard let pixelBuffer else {
            return
        }
        if outputFormat == nil {
            CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                formatDescriptionOut: &outputFormat
            )
        }
        guard let outputFormat else {
            return
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
            return
        }
        if renderEffectsSeparately {
            var viewPixelBuffer: CVPixelBuffer?
            pixelBufferPool?.createPixelBuffer(&viewPixelBuffer)
            guard let viewPixelBuffer else {
                return
            }
            var viewSampleBuffer: CMSampleBuffer?
            guard CMSampleBufferCreateReadyWithImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: viewPixelBuffer,
                formatDescription: outputFormat,
                sampleTiming: &timingInfo,
                sampleBufferOut: &viewSampleBuffer
            ) == noErr else {
                return
            }
            if let sampleBuffer, let viewSampleBuffer {
                render(streamBuffer: sampleBuffer, viewBuffer: viewSampleBuffer)
                sampleBuffer.targetType = .stream
                viewSampleBuffer.targetType = .view
                observer?.screen(self, didOutput: sampleBuffer)
                observer?.screen(self, didOutput: viewSampleBuffer)
            }
        } else if let sampleBuffer {
            sampleBuffer.targetType = .both
            observer?.screen(self, didOutput: render(sampleBuffer))
        }
    }
}
