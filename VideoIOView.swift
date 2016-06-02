import Foundation
import AVFoundation

public class VideoIOView: NSView {
    public var videoGravity:String! = AVLayerVideoGravityResizeAspectFill {
        didSet {
            layer?.setValue(videoGravity, forKey: "videoGravity")
        }
    }
    
    var contents:AnyObject? {
        get { return layer?.contents }
        set { layer?.contents = newValue }
    }
    
    var transform3D:CATransform3D {
        get { return layer!.transform }
        set { layer?.transform = newValue }
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
        layer = VideoIOLayer()
        layer?.frame = bounds
        layer?.setValue(videoGravity, forKey: "videoGravity")
    }
}