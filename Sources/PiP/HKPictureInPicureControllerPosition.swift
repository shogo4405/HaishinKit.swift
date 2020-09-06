#if !os(macOS)
import UIKit

public enum HKPictureInPicureControllerPosition {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft

    func CGPoint(_ controller: HKPictureInPicureController, insets: UIEdgeInsets = .zero) -> CGPoint {
        let margin = controller.pictureInPictureMargin
        switch self {
        case .topLeft:
            return .init(
                x: margin + insets.left,
                y: margin + insets.top)
        case .topRight:
            return .init(
                x: UIScreen.main.bounds.width - controller.pictureInPictureSize.width - margin - insets.right,
                y: margin + insets.top
            )
        case .bottomLeft:
            return .init(
                x: margin + insets.left,
                y: UIScreen.main.bounds.height - controller.pictureInPictureSize.height - margin - insets.bottom
            )
        case .bottomRight:
            return .init(
                x: UIScreen.main.bounds.width - controller.pictureInPictureSize.width - margin - insets.right,
                y: UIScreen.main.bounds.height - controller.pictureInPictureSize.height - margin - insets.bottom
            )
        }
    }
}
#endif
