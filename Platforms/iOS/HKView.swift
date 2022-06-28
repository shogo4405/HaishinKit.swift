#if os(iOS)

import AVFoundation
import UIKit

/**
 * A view that displays a video content of a NetStream object which uses AVCaptureVideoPreviewLayer.
 */
public class HKView: UIView {
    public static var defaultBackgroundColor: UIColor = .black

    /// Returns the class used to create the layer for instances of this class.
    override public class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    /// The view’s Core Animation layer used for rendering.
    override public var layer: AVCaptureVideoPreviewLayer {
        super.layer as! AVCaptureVideoPreviewLayer
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

    var orientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            let orientationChange = { [weak self] in
                guard let self = self else {
                    return
                }
                self.layer.connection.map {
                    if $0.isVideoOrientationSupported {
                        $0.videoOrientation = self.orientation
                    }
                }
            }
            if Thread.isMainThread {
                orientationChange()
            } else {
                DispatchQueue.main.sync {
                    orientationChange()
                }
            }
        }
    }
    var position: AVCaptureDevice.Position = .front
    var currentSampleBuffer: CMSampleBuffer?

    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.videoIO.renderer = nil
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        awakeFromNib()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    deinit {
        attachStream(nil)
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = HKView.defaultBackgroundColor
        layer.backgroundColor = HKView.defaultBackgroundColor.cgColor
    }

    /// Attaches a view to a new NetStream object.
    public func attachStream(_ stream: NetStream?) {
        guard let stream: NetStream = stream else {
            layer.session?.stopRunning()
            layer.session = nil
            currentStream = nil
            return
        }

        stream.mixer.session.beginConfiguration()
        layer.session = stream.mixer.session
        orientation = stream.mixer.videoIO.orientation
        stream.mixer.session.commitConfiguration()

        stream.lockQueue.async {
            stream.mixer.videoIO.renderer = self
            self.currentStream = stream
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
