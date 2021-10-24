#if !os(macOS)
import Foundation
import UIKit

private var HKPictureInPictureControllerImplKey: UInt8 = 0

/// HKPictureInPictureController protocol default implementation.
public extension HKPictureInPictureController where Self: UIViewController {
    var isPictureInPictureActive: Bool {
        impl.isPictureInPictureActive
    }

    var pictureInPictureSize: CGSize {
        get {
            impl.pictureInPictureSize
        }
        set {
            impl.pictureInPictureSize = newValue
        }
    }

    var pictureInPicturePosition: HKPictureInPictureControllerPosition {
        get {
            impl.pictureInPicturePosition
        }
        set {
            impl.pictureInPicturePosition = newValue
        }
    }

    var pictureInPictureMargin: CGFloat {
        get {
            impl.pictureInPictureMargin
        }
        set {
            impl.pictureInPictureMargin = newValue
        }
    }

    var pictureInPictureCornerRadius: CGFloat {
        get {
            impl.pictureInPictureCornerRadius
        }
        set {
            impl.pictureInPictureCornerRadius = newValue
        }
    }

    var pictureInPictureAnimationDuration: TimeInterval {
        get {
            impl.pictureInPictureAnimationDuration
        }
        set {
            impl.pictureInPictureAnimationDuration = newValue
        }
    }

    private var impl: HKPictureInPictureControllerImpl {
        get {
            guard let object = objc_getAssociatedObject(self, &HKPictureInPictureControllerImplKey) as? HKPictureInPictureControllerImpl else {
                let impl = HKPictureInPictureControllerImpl(self)
                objc_setAssociatedObject(self, &HKPictureInPictureControllerImplKey, impl, .OBJC_ASSOCIATION_RETAIN)
                return impl
            }
            return object
        }
        set {
            objc_setAssociatedObject(self, &HKPictureInPictureControllerImplKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    func startPictureInPicture() {
        guard !impl.isPictureInPictureActive else {
            return
        }
        impl.startPictureInPicture()
    }

    func stopPictureInPicture() {
        guard impl.isPictureInPictureActive else {
            return
        }
        impl.stopPictureInPicture()
    }
}
#endif
