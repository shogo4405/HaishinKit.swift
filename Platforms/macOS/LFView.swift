import Foundation
import AVFoundation

open class LFView: NSView {
    public static var defaultBackgroundColor:NSColor = NSColor.black

    internal var position:AVCaptureDevicePosition = .front {
        didSet {
            /*
            let when:dispatch_time_t  = DispatchTime.now(dispatch_time_t(DISPATCH_TIME_NOW), Int64(0.1 * Double(NSEC_PER_SEC)))
            dispatch_after(when, DispatchQueue.main) {
                self.frame = NSRect(x: 0, y: 0, width: self.frame.width - 0.1, height: self.frame.height - 0.1)
            }
            */
        }
    }
    internal var orientation:AVCaptureVideoOrientation = .portrait

    public var videoGravity:String = AVLayerVideoGravityResizeAspect {
        didSet {
            layer?.setValue(videoGravity, forKey: "videoGravity")
        }
    }

    private weak var currentStream:NetStream? {
        didSet {
            guard let oldValue:NetStream = oldValue else {
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

    open override func awakeFromNib() {
        wantsLayer = true
        layer = AVCaptureVideoPreviewLayer()
        layer?.backgroundColor = LFView.defaultBackgroundColor.cgColor
        layer?.setValue(videoGravity, forKey: "videoGravity")
    }

    public func attach(stream:NetStream?) {
        layer?.setValue(stream?.mixer.session, forKey: "session")
        stream?.mixer.videoIO.drawable = self
        currentStream = stream
    }
}

extension LFView: NetStreamDrawable {
    // MARK: NetStreamDrawable
    internal func render(image:CIImage, to toCVPixelBuffer:CVPixelBuffer) {
    }
    internal func draw(image:CIImage) {
    }
}
