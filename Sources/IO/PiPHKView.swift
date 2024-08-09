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
        Task { @MainActor in
            backgroundColor = Self.defaultBackgroundColor
            layer.backgroundColor = Self.defaultBackgroundColor.cgColor
            layer.videoGravity = videoGravity
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

    private var enqueueTask: Task<Void, Never>?

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
        Task { @MainActor in
            wantsLayer = true
            layer = AVSampleBufferDisplayLayer()
            layer?.backgroundColor = PiPHKView.defaultBackgroundColor.cgColor
            layer?.setValue(videoGravity, forKey: "videoGravity")
        }
    }
}

extension PiPHKView: IOStreamObserver {
    nonisolated public func stream(_ stream: some IOStream, didOutput audio: AVAudioBuffer, when: AVAudioTime) {
    }

    nonisolated public func stream(_ stream: some IOStream, didOutput video: CMSampleBuffer) {
        Task { @MainActor in
            (layer as? AVSampleBufferDisplayLayer)?.enqueue(video)
            #if os(macOS)
            self.needsDisplay = true
            #else
            self.setNeedsDisplay()
            #endif
        }
    }
}

#endif
