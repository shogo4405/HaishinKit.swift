#if os(iOS) || os(tvOS)
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

    /// A value that displays a video format.
    public var videoFormatDescription: CMVideoFormatDescription? {
        currentStream?.mixer.videoIO.formatDescription
    }

    #if !os(tvOS)
    public var orientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            if Thread.isMainThread {
                layer.flushAndRemoveImage()
            } else {
                DispatchQueue.main.sync {
                    layer.flushAndRemoveImage()
                }
            }
        }
    }
    public var position: AVCaptureDevice.Position = .front
    #endif
    private var currentSampleBuffer: CMSampleBuffer?

    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.videoIO.drawable = nil
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

    deinit {
        attachStream(nil)
    }

    /// Prepares the receiver for service after it has been loaded from an Interface Builder archive, or nib file.
    override public func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = Self.defaultBackgroundColor
        layer.backgroundColor = Self.defaultBackgroundColor.cgColor
        layer.videoGravity = videoGravity
    }
}

extension PiPHKView: NetStreamDrawable {
    // MARK: NetStreamDrawable
    public func attachStream(_ stream: NetStream?) {
        guard let stream: NetStream = stream else {
            currentStream = nil
            return
        }
        stream.lockQueue.async {
            stream.mixer.videoIO.drawable = self
            self.currentStream = stream
            stream.mixer.startRunning()
        }
    }

    public func enqueue(_ sampleBuffer: CMSampleBuffer?) {
        if Thread.isMainThread {
            currentSampleBuffer = sampleBuffer
            if let sampleBuffer = sampleBuffer {
                layer.enqueue(sampleBuffer)
            }
        } else {
            DispatchQueue.main.async {
                self.enqueue(sampleBuffer)
            }
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

    /// A value that displays a video format.
    public var videoFormatDescription: CMVideoFormatDescription? {
        currentStream?.mixer.videoIO.formatDescription
    }

    public var orientation: AVCaptureVideoOrientation = .portrait {
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
    public var position: AVCaptureDevice.Position = .front

    private var currentSampleBuffer: CMSampleBuffer?

    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.videoIO.drawable = nil
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

    deinit {
        attachStream(nil)
    }

    /// Prepares the receiver for service after it has been loaded from an Interface Builder archive, or nib file.
    override public func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        layer = AVSampleBufferDisplayLayer()
        layer?.backgroundColor = HKView.defaultBackgroundColor.cgColor
        layer?.setValue(videoGravity, forKey: "videoGravity")
    }
}

extension PiPHKView: NetStreamDrawable {
    // MARK: NetStreamDrawable
    public func attachStream(_ stream: NetStream?) {
        guard let stream: NetStream = stream else {
            currentStream = nil
            return
        }
        stream.lockQueue.async {
            stream.mixer.videoIO.drawable = self
            self.currentStream = stream
            stream.mixer.startRunning()
        }
    }

    public func enqueue(_ sampleBuffer: CMSampleBuffer?) {
        if Thread.isMainThread {
            currentSampleBuffer = sampleBuffer
            if let sampleBuffer = sampleBuffer {
                (layer as? AVSampleBufferDisplayLayer)?.enqueue(sampleBuffer)
            }
        } else {
            DispatchQueue.main.async {
                self.enqueue(sampleBuffer)
            }
        }
    }
}

#endif
