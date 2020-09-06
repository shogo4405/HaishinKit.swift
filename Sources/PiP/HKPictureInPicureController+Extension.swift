#if !os(macOS)
import Foundation
import UIKit

private var HKPictureInPicureControllerImplKey: UInt8 = 0

/// HKPictureInPicureController protocol default implementation.
public extension HKPictureInPicureController where Self: UIViewController {
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

    var pictureInPicturePosition: HKPictureInPicureControllerPosition {
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

    private var impl: HKPictureInPicureControllerImpl {
        get {
            guard let object = objc_getAssociatedObject(self, &HKPictureInPicureControllerImplKey) as? HKPictureInPicureControllerImpl else {
                let impl = HKPictureInPicureControllerImpl(self)
                objc_setAssociatedObject(self, &HKPictureInPicureControllerImplKey, impl, .OBJC_ASSOCIATION_RETAIN)
                return impl
            }
            return object
        }
        set {
            objc_setAssociatedObject(self, &HKPictureInPicureControllerImplKey, newValue, .OBJC_ASSOCIATION_RETAIN)
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
