#if os(macOS)

import AppKit
import AVFoundation

/// A view that displays a video content of a NetStream object which uses AVCaptureVideoPreviewLayer.
public class HKView: NSView {
    /// The view’s background color.
    public static var defaultBackgroundColor: NSColor = .black

    /// A value that specifies how the video is displayed within a player layer’s bounds.
    public var videoGravity: AVLayerVideoGravity = .resizeAspect {
        didSet {
            layer?.setValue(videoGravity.rawValue, forKey: "videoGravity")
        }
    }

    /// A value that displays a video format.
    public var videoFormatDescription: CMVideoFormatDescription? {
        currentStream?.mixer.videoIO.formatDescription
    }

    public var videoOrientation: AVCaptureVideoOrientation = .portrait

    private var currentSampleBuffer: CMSampleBuffer?

    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.videoIO.drawable = nil
        }
    }

    /// Initializes and returns a newly allocated view object with the specified frame rectangle.
    override public init(frame: NSRect) {
        super.init(frame: frame)
        awakeFromNib()
    }

    /// Returns an object initialized from data in a given unarchiver.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    /// Prepares the receiver for service after it has been loaded from an Interface Builder archive, or nib file.
    override public func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        layer = AVCaptureVideoPreviewLayer()
        layer?.backgroundColor = HKView.defaultBackgroundColor.cgColor
        layer?.setValue(videoGravity, forKey: "videoGravity")
    }
}

extension HKView: NetStreamDrawable {
    // MARK: NetStreamDrawable
    public func attachStream(_ stream: NetStream?) {
        currentStream = stream
        guard let stream: NetStream = stream else {
            layer?.setValue(nil, forKey: "session")
            return
        }
        stream.lockQueue.async {
            self.layer?.setValue(stream.mixer.session, forKey: "session")
            stream.mixer.videoIO.drawable = self
            stream.mixer.startRunning()
        }
    }

    public func enqueue(_ sampleBuffer: CMSampleBuffer?) {
    }
}

#endif
