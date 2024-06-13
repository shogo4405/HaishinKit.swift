#if os(iOS) || os(tvOS) || os(visionOS)
import AVFoundation
import Foundation
import UIKit

/// A view that displays a video content of a NetStream object which uses AVSampleBufferDisplayLayer api.
public class PiPHKView: UIView {
    /// The view’s background color.
    public static var defaultBackgroundColor: UIColor = .black

    /// Returns the class used to create the layer for instances of this class.
    override public class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }

    /// The view’s Core Animation layer used for rendering.
    override public var layer: AVSampleBufferDisplayLayer {
        super.layer as! AVSampleBufferDisplayLayer
    }

    /// A value that specifies how the video is displayed within a player layer’s bounds.
    public var videoGravity: AVLayerVideoGravity = .resizeAspect {
        didSet {
            layer.videoGravity = videoGravity
        }
    }

    #if os(iOS)
    /// Specifies the orientation of AVCaptureVideoOrientation.
    public var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            if Thread.isMainThread {
                layer.flushAndRemoveImage()
                (captureVideoPreview as? IOCaptureVideoPreview)?.videoOrientation = videoOrientation
            } else {
                DispatchQueue.main.sync {
                    layer.flushAndRemoveImage()
                    (self.captureVideoPreview as? IOCaptureVideoPreview)?.videoOrientation = videoOrientation
                }
            }
        }
    }
    #endif

    #if os(iOS) || os(tvOS)
    /// Specifies the capture video preview enabled or not.
    @available(tvOS 17.0, *)
    public var isCaptureVideoPreviewEnabled: Bool {
        get {
            captureVideoPreview != nil
        }
        set {
            guard isCaptureVideoPreviewEnabled != newValue else {
                return
            }
            if Thread.isMainThread {
                captureVideoPreview = newValue ? IOCaptureVideoPreview(self) : nil
            } else {
                DispatchQueue.main.async {
                    self.captureVideoPreview = newValue ? IOCaptureVideoPreview(self) : nil
                }
            }
        }
    }
    #endif

    private weak var currentStream: (any IOStreamConvertible)? {
        didSet {
            oldValue?.removeObserver(self)
            currentStream?.addObserver(self)
        }
    }

    private var captureVideoPreview: UIView? {
        willSet {
            captureVideoPreview?.removeFromSuperview()
        }
        didSet {
            captureVideoPreview.map {
                addSubview($0)
                sendSubviewToBack($0)
            }
        }
    }

    /// Initializes and returns a newly allocated view object with the specified frame rectangle.
    override public init(frame: CGRect) {
        super.init(frame: frame)
        awakeFromNib()
    }

    /// Returns an object initialized from data in a given unarchiver.
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    /// Prepares the receiver for service after it has been loaded from an Interface Builder archive, or nib file.
    override public func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = Self.defaultBackgroundColor
        layer.backgroundColor = Self.defaultBackgroundColor.cgColor
        layer.videoGravity = videoGravity
    }
}

extension PiPHKView: IOStreamView {
    // MARK: IOStreamView
    public func attachStream(_ stream: (some IOStreamConvertible)?) {
        currentStream = stream
    }

    public func enqueue(_ sampleBuffer: CMSampleBuffer?) {
        guard let sampleBuffer else {
            return
        }
        layer.enqueue(sampleBuffer)
    }
}

extension PiPHKView: IOStreamObserver {
    nonisolated public func stream(_ stream: IOStream, didOutput audio: AVAudioBuffer, when: AVAudioTime) {
    }

    nonisolated public func stream(_ stream: IOStream, didOutput video: CMSampleBuffer) {
        Task { @MainActor in
            self.enqueue(video)
        }
    }
}
#else

import AppKit
import AVFoundation

/// A view that displays a video content of a NetStream object which uses AVSampleBufferDisplayLayer api.
public class PiPHKView: NSView {
    /// The view’s background color.
    public static var defaultBackgroundColor: NSColor = .black

    /// A value that specifies how the video is displayed within a player layer’s bounds.
    public var videoGravity: AVLayerVideoGravity = .resizeAspect {
        didSet {
            layer?.setValue(videoGravity, forKey: "videoGravity")
        }
    }

    /// Specifies the orientation of AVCaptureVideoOrientation.
    public var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            if Thread.isMainThread {
                (layer as? AVSampleBufferDisplayLayer)?.flushAndRemoveImage()
            } else {
                DispatchQueue.main.sync {
                    (layer as? AVSampleBufferDisplayLayer)?.flushAndRemoveImage()
                }
            }
        }
    }

    /// Specifies the capture video preview enabled or not.
    public var isCaptureVideoPreviewEnabled: Bool {
        get {
            captureVideoPreview != nil
        }
        set {
            guard isCaptureVideoPreviewEnabled != newValue else {
                return
            }
            if Thread.isMainThread {
                captureVideoPreview = newValue ? IOCaptureVideoPreview(self) : nil
            } else {
                DispatchQueue.main.async {
                    self.captureVideoPreview = newValue ? IOCaptureVideoPreview(self) : nil
                }
            }
        }
    }

    private var captureVideoPreview: NSView? {
        willSet {
            captureVideoPreview?.removeFromSuperview()
        }
        didSet {
            captureVideoPreview.map {
                addSubview($0)
                sendSubviewToBack($0)
            }
        }
    }

    private weak var currentStream: (any IOStreamConvertible)? {
        didSet {
            oldValue?.removeObserver(self)
            currentStream?.addObserver(self)
        }
    }

    /// Initializes and returns a newly allocated view object with the specified frame rectangle.
    override public init(frame: CGRect) {
        super.init(frame: frame)
        awakeFromNib()
    }

    /// Returns an object initialized from data in a given unarchiver.
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    /// Prepares the receiver for service after it has been loaded from an Interface Builder archive, or nib file.
    override public func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        layer = AVSampleBufferDisplayLayer()
        layer?.backgroundColor = PiPHKView.defaultBackgroundColor.cgColor
        layer?.setValue(videoGravity, forKey: "videoGravity")
    }
}

extension PiPHKView: IOStreamView {
    // MARK: IOStreamView
    public func attachStream(_ stream: (some IOStreamConvertible)?) {
        currentStream = stream
    }

    public func enqueue(_ sampleBuffer: CMSampleBuffer?) {
        guard let sampleBuffer else {
            return
        }
        (layer as? AVSampleBufferDisplayLayer)?.enqueue(sampleBuffer)
    }
}

extension PiPHKView: IOStreamObserver {
    nonisolated public func stream(_ stream: IOStream, didOutput audio: AVAudioBuffer, when: AVAudioTime) {
    }

    nonisolated public func stream(_ stream: IOStream, didOutput video: CMSampleBuffer) {
        Task { @MainActor in
            enqueue(video)
        }
    }
}

#endif
