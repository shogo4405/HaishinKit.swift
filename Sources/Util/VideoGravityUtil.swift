import AVFoundation

extension CGRect {
    var aspectRatio: CGFloat {
        width / height
    }
}

final class VideoGravityUtil {
    @inline(__always)
    static func calculate(_ videoGravity: AVLayerVideoGravity, inRect: inout CGRect, fromRect: inout CGRect) {
        switch videoGravity {
        case .resizeAspect:
            resizeAspect(&inRect, fromRect: &fromRect)
        case .resizeAspectFill:
            resizeAspectFill(&inRect, fromRect: &fromRect)
        default:
            break
        }
    }

    @inline(__always)
    static func resizeAspect(_ inRect: inout CGRect, fromRect: inout CGRect) {
        let xRatio: CGFloat = inRect.width / fromRect.width
        let yRatio: CGFloat = inRect.height / fromRect.height
        if yRatio < xRatio {
            inRect.origin.x = (inRect.size.width - fromRect.size.width * yRatio) / 2
            inRect.size.width = fromRect.size.width * yRatio
        } else {
            inRect.origin.y = (inRect.size.height - fromRect.size.height * xRatio) / 2
            inRect.size.height = fromRect.size.height * xRatio
        }
    }

    @inline(__always)
    static func resizeAspectFill(_ inRect: inout CGRect, fromRect: inout CGRect) {
        let inRectAspect: CGFloat = inRect.aspectRatio
        let fromRectAspect: CGFloat = fromRect.aspectRatio
        if inRectAspect < fromRectAspect {
            inRect.origin.x += (inRect.size.width - inRect.size.height * fromRectAspect) / 2
            inRect.size.width = inRect.size.height * fromRectAspect
        } else {
            inRect.origin.y += (inRect.size.height - inRect.size.width / fromRectAspect) / 2
            inRect.size.height = inRect.size.width / fromRectAspect
        }
    }
}
