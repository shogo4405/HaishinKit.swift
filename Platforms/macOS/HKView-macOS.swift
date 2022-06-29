#if os(macOS)

import AppKit
import AVFoundation

/**
 * A view that displays a video content of a NetStream object which uses AVCaptureVideoPreviewLayer.
 */
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

    var position: AVCaptureDevice.Position = .front {
        didSet {
            DispatchQueue.main.async {
                self.layer?.setNeedsLayout()
            }
        }
    }
    var orientation: AVCaptureVideoOrientation = .portrait
    var currentSampleBuffer: CMSampleBuffer?

    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.videoIO.renderer = nil
        }
    }

    override public init(frame: NSRect) {
        super.init(frame: frame)
        awakeFromNib()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        layer = AVCaptureVideoPreviewLayer()
        layer?.backgroundColor = HKView.defaultBackgroundColor.cgColor
        layer?.setValue(videoGravity, forKey: "videoGravity")
    }

    /// Attaches a view to a new NetStream object.
    public func attachStream(_ stream: NetStream?) {
        currentStream = stream
        guard let stream: NetStream = stream else {
            layer?.setValue(nil, forKey: "session")
            return
        }
        stream.lockQueue.async {
            self.layer?.setValue(stream.mixer.session, forKey: "session")
            stream.mixer.videoIO.renderer = self
            stream.mixer.startRunning()
        }
    }
}

extension HKView: NetStreamDrawable {
    // MARK: NetStreamRenderer
    func enqueue(_ sampleBuffer: CMSampleBuffer?) {
    }
}

#endif
