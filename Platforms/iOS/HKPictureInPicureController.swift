import Foundation
import UIKit

private var HKPictureInPicureControllerImplKey: UInt8 = 0

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
