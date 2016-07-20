import Foundation
import AVFoundation

public class LFView: NSView {

    public static var defaultBackgroundColor:NSColor = NSColor.blackColor()

    public var videoGravity:String! = AVLayerVideoGravityResize {
        didSet {
            switch videoGravity {
            case AVLayerVideoGravityResizeAspect:
                layer?.contentsGravity = kCAGravityResizeAspect
            case AVLayerVideoGravityResizeAspectFill:
                layer?.contentsGravity = kCAGravityResizeAspectFill
            case AVLayerVideoGravityResize:
                layer?.contentsGravity = kCAGravityResize
            default:
                layer?.contentsGravity = kCAGravityResizeAspect
            }
        }
    }

    override public init(frame: NSRect) {
        super.init(frame: frame)
        initialize()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }

    public func attachStream(stream:Stream?) {
        layer?.setValue(stream?.mixer.session, forKey: "session")
    }

    private func initialize() {
        wantsLayer = true
        layer = AVCaptureVideoPreviewLayer()
        layer?.backgroundColor = LFView.defaultBackgroundColor.CGColor
        layer?.setValue(videoGravity, forKey: "videoGravity")
    }
}