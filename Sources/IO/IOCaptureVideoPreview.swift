#if os(iOS) || os(tvOS)
import AVFoundation
import Foundation
import UIKit

@available(tvOS 17.0, *)
final class IOCaptureVideoPreview: UIView {
    override public class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    override public var layer: AVCaptureVideoPreviewLayer {
        super.layer as! AVCaptureVideoPreviewLayer
    }

    var videoGravity: AVLayerVideoGravity {
        get {
            layer.videoGravity
        }
        set {
            layer.videoGravity = newValue
        }
    }

    #if os(iOS)
    var videoOrientation: AVCaptureVideoOrientation? {
        get {
            return layer.connection?.videoOrientation
        }
        set {
            if let newValue, layer.connection?.isVideoOrientationSupported == true {
                layer.connection?.videoOrientation = newValue
            }
        }
    }
    #endif

    init(_ view: UIView) {
        super.init(frame: view.bounds)
        translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalTo: view.heightAnchor),
            widthAnchor.constraint(equalTo: view.widthAnchor),
            centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attachStream(_ stream: IOStream?) {
        layer.session = stream?.mixer.session.session
        #if os(iOS)
        if let videoOrientation = stream?.videoOrientation, layer.connection?.isVideoOrientationSupported == true {
            layer.connection?.videoOrientation = videoOrientation
        }
        #endif
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()
        layer.session = nil
    }
}

#elseif os(macOS)

import AppKit
import AVFoundation
import Foundation

final class IOCaptureVideoPreview: NSView {
    static let defaultBackgroundColor: NSColor = .black

    var videoGravity: AVLayerVideoGravity = .resizeAspect {
        didSet {
            layer?.setValue(videoGravity.rawValue, forKey: "videoGravity")
        }
    }

    var videoOrientation: AVCaptureVideoOrientation = .portrait

    init(_ view: NSView) {
        super.init(frame: view.bounds)
        translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalTo: view.heightAnchor),
            widthAnchor.constraint(equalTo: view.widthAnchor),
            centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        layer = AVCaptureVideoPreviewLayer()
        layer?.backgroundColor = IOCaptureVideoPreview.defaultBackgroundColor.cgColor
        layer?.setValue(videoGravity, forKey: "videoGravity")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attachStream(_ stream: IOStream?) {
        layer?.setValue(stream?.mixer.session, forKey: "session")
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()
        layer?.setValue(nil, forKey: "session")
    }
}

#endif
