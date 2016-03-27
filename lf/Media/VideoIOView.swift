import UIKit
import Foundation
import AVFoundation

public class VideoIOView: UIView {
    static var defaultBackgroundColor:UIColor = UIColor.blackColor()

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
            layer.setValue(videoGravity, forKey: "videoGravity")
        }
    }

    override public class func layerClass() -> AnyClass {
        return VideoIOLayer.self
    }

    private func initialize() {
        backgroundColor = VideoIOView.defaultBackgroundColor
        layer.frame = bounds
        layer.setValue(videoGravity, forKey: "videoGravity")
    }
}
