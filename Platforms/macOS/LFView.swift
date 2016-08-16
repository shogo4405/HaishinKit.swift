import Foundation
import AVFoundation

public class LFView: NSView {
    public static var defaultBackgroundColor:NSColor = NSColor.blackColor()

    var position:AVCaptureDevicePosition = .Front {
        didSet {
            let when:dispatch_time_t  = dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC)))
            dispatch_after(when, dispatch_get_main_queue()) {
                self.frame = NSRect(x: 0, y: 0, width: self.frame.width - 0.1, height: self.frame.height - 0.1)
            }
        }
    }
    var orientation:AVCaptureVideoOrientation = .Portrait

    public var videoGravity:String = AVLayerVideoGravityResizeAspect {
        didSet {
            layer?.setValue(videoGravity, forKey: "videoGravity")
        }
    }

    private weak var currentStream:Stream? {
        didSet {
            guard let oldValue:Stream = oldValue else {
                return
            }
            oldValue.mixer.videoIO.drawable = nil
        }
    }

    override public init(frame: NSRect) {
        super.init(frame: frame)
        awakeFromNib()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func awakeFromNib() {
        wantsLayer = true
        layer = AVCaptureVideoPreviewLayer()
        layer?.backgroundColor = LFView.defaultBackgroundColor.CGColor
        layer?.setValue(videoGravity, forKey: "videoGravity")
    }

    public func attachStream(stream:Stream?) {
        layer?.setValue(stream?.mixer.session, forKey: "session")
        stream?.mixer.videoIO.drawable = self
        currentStream = stream
    }
}

// MARK: - StreamDrawable
extension LFView: StreamDrawable {
    func render(image: CIImage, toCVPixelBuffer: CVPixelBuffer) {
    }
    func drawImage(image:CIImage) {
    }
}
