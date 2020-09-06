#if !os(macOS)
import Foundation
import UIKit

public protocol HKPictureInPicureController: class {
    var isPictureInPictureActive: Bool { get }
    var pictureInPictureSize: CGSize { get set }
    var pictureInPicturePosition: HKPictureInPicureControllerPosition { get set }
    var pictureInPictureMargin: CGFloat { get set }
    var pictureInPictureCornerRadius: CGFloat { get set }
    var pictureInPictureAnimationDuration: TimeInterval { get set }

    func startPictureInPicture()
    func stopPictureInPicture()
}
#endif
