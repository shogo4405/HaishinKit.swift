#if os(iOS)
import UIKit
#endif
import Foundation
import AVFoundation

final class AVMixer: NSObject {

    static let supportedSettingsKeys:[String] = [
        "fps",
        "sessionPreset",
        "orientation",
        "continuousAutofocus",
        "continuousExposure",
    ]

    static let defaultFPS:Float64 = 30
    static let defaultSessionPreset:String = AVCaptureSessionPresetMedium
    static let defaultVideoSettings:[NSObject: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA) as AnyObject
    ]

    var fps:Float64 {
        get { return videoIO.fps }
        set { videoIO.fps = newValue }
    }

    var orientation:AVCaptureVideoOrientation {
        get { return videoIO.orientation }
        set { videoIO.orientation = newValue }
    }

    var continuousExposure:Bool {
        get { return videoIO.continuousExposure }
        set { videoIO.continuousExposure = newValue }
    }

    var continuousAutofocus:Bool {
        get { return videoIO.continuousAutofocus }
        set { videoIO.continuousAutofocus = newValue }
    }

    #if os(iOS)
    var syncOrientation:Bool = false {
        didSet {
            guard syncOrientation != oldValue else {
                return
            }
            if (syncOrientation) {
                NotificationCenter.default.addObserver(self, selector: #selector(AVMixer.on(uiDeviceOrientationDidChange:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
            } else {
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
            }
        }
    }
    #endif

    var sessionPreset:String = AVMixer.defaultSessionPreset {
        didSet {
            guard sessionPreset != oldValue else {
                return
            }
            session.beginConfiguration()
            session.sessionPreset = sessionPreset
            session.commitConfiguration()
        }
    }

    fileprivate var _session:AVCaptureSession? = nil
    var session:AVCaptureSession! {
        if (_session == nil) {
            _session = AVCaptureSession()
            _session?.beginConfiguration()
            _session?.sessionPreset = AVMixer.defaultSessionPreset
            _session?.commitConfiguration()
        }
        return _session!
    }

    fileprivate(set) var audioIO:AudioIOComponent!
    fileprivate(set) var videoIO:VideoIOComponent!
    fileprivate(set) lazy var recorder:AVMixerRecorder = AVMixerRecorder()

    override init() {
        super.init()
        audioIO = AudioIOComponent(mixer: self)
        videoIO = VideoIOComponent(mixer: self)
    }

    deinit {
        #if os(iOS)
        syncOrientation = false
        #endif
    }

    #if os(iOS)
    @objc private func on(uiDeviceOrientationDidChange:Notification) {
        var deviceOrientation:UIDeviceOrientation = .unknown
        if let device:UIDevice = uiDeviceOrientationDidChange.object as? UIDevice {
            deviceOrientation = device.orientation
        }
        if let orientation:AVCaptureVideoOrientation = DeviceUtil.videoOrientation(by: deviceOrientation) {
            self.orientation = orientation
        }
    }
    #endif
}

extension AVMixer: Runnable {
    // MARK: Runnable
    var running:Bool {
        return session.isRunning
    }

    func startRunning() {
        session.startRunning()
        #if os(iOS)
        if let orientation:AVCaptureVideoOrientation = DeviceUtil.videoOrientation(by: UIDevice.current.orientation) , syncOrientation {
            self.orientation = orientation
        }
        #endif
    }

    func stopRunning() {
        session.stopRunning()
    }
}
