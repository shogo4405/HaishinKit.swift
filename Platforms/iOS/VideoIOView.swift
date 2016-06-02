import Foundation
import AVFoundation

public class VideoIOView: UIView {
    static public var defaultBackgroundColor:UIColor = UIColor.blackColor()
    
    override public class func layerClass() -> AnyClass {
        return VideoIOLayer.self
    }
    
    public var videoGravity:String! = AVLayerVideoGravityResizeAspectFill {
        didSet {
            layer.setValue(videoGravity, forKey: "videoGravity")
        }
    }
    
    var contents:AnyObject? {
        get { return layer.contents }
        set { layer.contents = newValue }
    }
    
    var transform3D:CATransform3D {
        get { return layer.transform }
        set { layer.transform = newValue }
    }
    
    required override public init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    private func initialize() {
        backgroundColor = VideoIOView.defaultBackgroundColor
        layer.frame = bounds
        layer.setValue(videoGravity, forKey: "videoGravity")
    }
}
