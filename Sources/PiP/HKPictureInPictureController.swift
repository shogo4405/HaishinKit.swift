#if !os(macOS)
import Foundation
import UIKit

public protocol HKPictureInPictureController: AnyObject {
    var isPictureInPictureActive: Bool { get }
    var pictureInPictureSize: CGSize { get set }
    var pictureInPicturePosition: HKPictureInPictureControllerPosition { get set }
    var pictureInPictureMargin: CGFloat { get set }
    var pictureInPictureCornerRadius: CGFloat { get set }
    var pictureInPictureAnimationDuration: TimeInterval { get set }

    func startPictureInPicture()
    func stopPictureInPicture()
}
#endif
