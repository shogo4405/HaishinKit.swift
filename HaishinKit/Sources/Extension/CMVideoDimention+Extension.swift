import AVFoundation
import Foundation

extension CMVideoDimensions {
    var size: CGSize {
        return .init(width: CGFloat(width), height: CGFloat(height))
    }
}
