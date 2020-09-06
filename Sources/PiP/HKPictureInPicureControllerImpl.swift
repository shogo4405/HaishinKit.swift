#if !os(macOS)
import Foundation
import UIKit

class HKPictureInPicureControllerImpl: HKPictureInPicureController {
    static let margin: CGFloat = 16
    static let position: HKPictureInPicureControllerPosition = .bottomRight
    static let cornerRadius: CGFloat = 8
    static let animationDuration: TimeInterval = 0.3

    var isPictureInPictureActive: Bool = false
    var pictureInPictureSize: CGSize = .init(width: 160, height: 90)
    var pictureInPictureMargin: CGFloat = HKPictureInPicureControllerImpl.margin
    var pictureInPicturePosition: HKPictureInPicureControllerPosition = HKPictureInPicureControllerImpl.position
    var pictureInPictureCornerRadius: CGFloat = HKPictureInPicureControllerImpl.cornerRadius
    var pictureInPictureAnimationDuration: TimeInterval = HKPictureInPicureControllerImpl.animationDuration

    private var window: UIWindow?
    private var origin: CGPoint = .zero
    private var parent: UIViewController?
    private let viewController: UIViewController
    private lazy var panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPanGestureRecognizer(_:)))

    init(_ viewController: UIViewController) {
        self.viewController = viewController
        self.parent = viewController.parent
    }

    func startPictureInPicture() {
        guard !isPictureInPictureActive else {
            return
        }
        toggleWindow()
        viewController.view.addGestureRecognizer(panGestureRecognizer)
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(orientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
        #endif
        isPictureInPictureActive = true
    }

    func stopPictureInPicture() {
        guard isPictureInPictureActive else {
            return
        }
        toggleWindow()
        viewController.view.removeGestureRecognizer(panGestureRecognizer)
        #if os(iOS)
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        #endif
        isPictureInPictureActive = false
    }

    private func toggleWindow() {
        if window == nil {
            viewController.removeFromParent()
            viewController.view.removeFromSuperview()
            window = UIWindow(frame: .zero)
            window?.rootViewController = viewController
            window?.makeKeyAndVisible()
            if #available(iOS 11.0, tvOS 11.0, *) {
                transform(parent?.view.window?.safeAreaInsets ?? .zero)
            } else {
                transform()
            }
            viewController.view.layer.cornerRadius = pictureInPictureCornerRadius
        } else {
            window?.rootViewController = nil
            window = nil
            parent?.addChild(viewController)
            parent?.view.addSubview(viewController.view)
            viewController.view.layer.cornerRadius = 0
            UIView.animate(withDuration: pictureInPictureAnimationDuration) { [weak self] in
                guard let self = self else {
                    return
                }
                self.viewController.view.frame = self.parent?.view.bounds ?? .zero
            }
        }
    }

    private func transform(_ insets: UIEdgeInsets = .zero) {
        UIView.animate(withDuration: pictureInPictureAnimationDuration) { [weak self] in
            guard let self = self, let window = self.window else {
                return
            }
            if self.origin == .zero || !UIScreen.main.bounds.contains(self.origin) {
                window.frame = .init(origin: self.pictureInPicturePosition.CGPoint(self, insets: insets), size: self.pictureInPictureSize)
            } else {
                window.frame = .init(origin: self.origin, size: self.pictureInPictureSize)
            }
        }
    }

    #if os(iOS)
    @objc
    private func orientationDidChange() {
        switch UIDevice.current.orientation {
        case .landscapeLeft, .landscapeRight, .portrait, .portraitUpsideDown:
            if #available(iOS 11.0, *) {
                transform(parent?.view.window?.safeAreaInsets ?? .zero)
            } else {
                transform()
            }
        default:
            break
        }
    }
    #endif

    @objc
    private func didPanGestureRecognizer(_ sender: UIPanGestureRecognizer) {
        guard let window = window else {
            return
        }
        let point: CGPoint = sender.translation(in: viewController.view)
        window.center = CGPoint(x: window.center.x + point.x, y: window.center.y + point.y)
        origin = window.frame.origin
        sender.setTranslation(.zero, in: viewController.view)
    }
}

#endif
