#if os(iOS) || os(tvOS)

import AVFoundation
import CoreImage
import UIKit

private extension CGRect {
    init(size: CGSize) {
        self.init(origin: .zero, size: size)
    }
}

// MARK: -
public class IOUIScreenCaptureUnit: NSObject, IOScreenCaptureUnit {
    static let defaultFrameInterval: Int = 2
    static let defaultAttributes: [NSString: NSObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA),
        kCVPixelBufferCGBitmapContextCompatibilityKey: true as NSObject
    ]

    public var enabledScale = false
    public var afterScreenUpdates = false
    public var frameInterval: Int = IOUIScreenCaptureUnit.defaultFrameInterval
    public var attributes: [NSString: NSObject] {
        var attributes: [NSString: NSObject] = IOUIScreenCaptureUnit.defaultAttributes
        attributes[kCVPixelBufferWidthKey] = NSNumber(value: Float(size.width * scale))
        attributes[kCVPixelBufferHeightKey] = NSNumber(value: Float(size.height * scale))
        attributes[kCVPixelBufferBytesPerRowAlignmentKey] = NSNumber(value: Float(size.width * scale * 4))
        return attributes
    }
    public weak var delegate: IOScreenCaptureUnitDelegate?
    public internal(set) var isRunning: Atomic<Bool> = .init(false)

    private var shared: UIApplication?
    private var viewToCapture: UIView?
    private var context = CIContext(options: [.useSoftwareRenderer: NSNumber(value: false)])
    private let semaphore = DispatchSemaphore(value: 1)
    private let lockQueue = DispatchQueue(
        label: "com.haishinkit.HaishinKit.ScreenCaptureSession.lock", qos: .userInteractive, attributes: []
    )
    private var colorSpace: CGColorSpace!
    private var displayLink: CADisplayLink!

    private var size: CGSize = .zero {
        didSet {
            guard size != oldValue else {
                return
            }
            pixelBufferPool = nil
        }
    }
    private var scale: CGFloat {
        enabledScale ? UIScreen.main.scale : 1.0
    }

    private var _pixelBufferPool: CVPixelBufferPool?
    private var pixelBufferPool: CVPixelBufferPool! {
        get {
            if _pixelBufferPool == nil {
                var pixelBufferPool: CVPixelBufferPool?
                CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary?, &pixelBufferPool)
                _pixelBufferPool = pixelBufferPool
            }
            return _pixelBufferPool!
        }
        set {
            _pixelBufferPool = newValue
        }
    }

    public init(shared: UIApplication) {
        self.shared = shared
        size = UIScreen.main.bounds.size
        super.init()
    }

    public init(viewToCapture: UIView) {
        self.viewToCapture = viewToCapture
        size = viewToCapture.bounds.size
        afterScreenUpdates = true
        super.init()
    }

    @objc
    public func onScreen(_ displayLink: CADisplayLink) {
        guard semaphore.wait(timeout: .now()) == .success else {
            return
        }

        if self.shared != nil {
            size = UIScreen.main.bounds.size
        }
        if let viewToCapture = self.viewToCapture {
            size = viewToCapture.bounds.size
        }

        lockQueue.async {
            autoreleasepool {
                self.onScreenProcess(displayLink)
            }
            self.semaphore.signal()
        }
    }

    open func onScreenProcess(_ displayLink: CADisplayLink) {
        var pixelBuffer: CVPixelBuffer?

        CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer)
        CVPixelBufferLockBaseAddress(pixelBuffer!, [])
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        let cgctx: CGContext = UIGraphicsGetCurrentContext()!
        DispatchQueue.main.sync {
            UIGraphicsPushContext(cgctx)
            if let shared: UIApplication = shared {
                for window: UIWindow in shared.windows {
                    window.drawHierarchy(
                        in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height),
                        afterScreenUpdates: self.afterScreenUpdates
                    )
                }
            }
            if let viewToCapture: UIView = viewToCapture {
                viewToCapture.drawHierarchy(
                    in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height),
                    afterScreenUpdates: self.afterScreenUpdates
                )
            }
            UIGraphicsPopContext()
        }
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        context.render(CIImage(cgImage: image.cgImage!), to: pixelBuffer!)
        delegate?.session(self, didOutput: pixelBuffer!, presentationTime: CMTimeMakeWithSeconds(displayLink.timestamp, preferredTimescale: 1000))
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, [])
    }
}

extension IOUIScreenCaptureUnit: Running {
    // MARK: Running
    public func startRunning() {
        lockQueue.sync {
            guard !self.isRunning.value else {
                return
            }
            self.isRunning.mutate { $0 = true }
            self.pixelBufferPool = nil
            self.colorSpace = CGColorSpaceCreateDeviceRGB()
            self.displayLink = CADisplayLink(target: self, selector: #selector(onScreen))
            self.displayLink.frameInterval = self.frameInterval
            self.displayLink.add(to: .main, forMode: RunLoop.Mode.common)
        }
    }

    public func stopRunning() {
        lockQueue.sync {
            guard self.isRunning.value else {
                return
            }
            self.displayLink.remove(from: .main, forMode: RunLoop.Mode.common)
            self.displayLink.invalidate()
            self.colorSpace = nil
            self.displayLink = nil
            self.isRunning.mutate { $0 = false }
        }
    }
}

#endif
