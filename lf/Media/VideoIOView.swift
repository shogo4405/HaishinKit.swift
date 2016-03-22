import UIKit
import Foundation
import AVFoundation

public class VideoIOView: UIView {
    static var defaultBackgroundColor:UIColor = UIColor.blackColor()

    private var display:AVSampleBufferDisplayLayer = AVSampleBufferDisplayLayer()

    required override public init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }

    public var videoGravity:String! = AVLayerVideoGravityResizeAspectFill {
        didSet {
            display.videoGravity = videoGravity
            layer.setValue(videoGravity, forKey: "videoGravity")
        }
    }

    override public var frame:CGRect {
        get {
            return super.frame
        }
        set {
            super.frame = newValue
            display.frame = bounds
        }
    }

    override public class func layerClass() -> AnyClass {
        return VideoPreviewLayer.self
    }

    public func enqueueSampleBuffer(sampleBuffer: CMSampleBufferRef) {
        display.enqueueSampleBuffer(sampleBuffer)
    }

    private func initialize() {
        backgroundColor = VideoIOView.defaultBackgroundColor
        layer.addSublayer(display)
        display.videoGravity = videoGravity
        layer.setValue(videoGravity, forKey: "videoGravity")
    }
}
