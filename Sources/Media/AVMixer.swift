#if os(iOS)
import UIKit
#endif
import Foundation
import AVFoundation

final internal class AVMixer: NSObject {

    static internal let supportedSettingsKeys:[String] = [
        "fps",
        "sessionPreset",
        "orientation",
        "continuousAutofocus",
        "continuousExposure",
    ]

    static internal let defaultFPS:Float64 = 30
    static internal let defaultSessionPreset:String = AVCaptureSessionPresetMedium
    static internal let defaultVideoSettings:[NSObject: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA) as AnyObject
    ]

    internal var fps:Float64 {
        get { return videoIO.fps }
        set { videoIO.fps = newValue }
    }

    internal var orientation:AVCaptureVideoOrientation {
        get { return videoIO.orientation }
        set { videoIO.orientation = newValue }
    }

    internal var continuousExposure:Bool {
        get { return videoIO.continuousExposure }
        set { videoIO.continuousExposure = newValue }
    }

    internal var continuousAutofocus:Bool {
        get { return videoIO.continuousAutofocus }
        set { videoIO.continuousAutofocus = newValue }
    }

    #if os(iOS)
    internal var syncOrientation:Bool = false {
        didSet {
            guard syncOrientation != oldValue else {
                return
            }
            let center:NotificationCenter = NotificationCenter.default
            if (syncOrientation) {
                center.addObserver(self, selector: #selector(AVMixer.onOrientationChanged(_:)), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
            } else {
                center.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
            }
        }
    }
    #endif

    internal var sessionPreset:String = AVMixer.defaultSessionPreset {
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
    internal var session:AVCaptureSession! {
        if (_session == nil) {
            _session = AVCaptureSession()
            _session!.sessionPreset = AVMixer.defaultSessionPreset
        }
        return _session!
    }

    internal fileprivate(set) var audioIO:AudioIOComponent!
    internal fileprivate(set) var videoIO:VideoIOComponent!
    internal fileprivate(set) lazy var recorder:AVMixerRecorder = AVMixerRecorder()

    override internal init() {
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
    internal func onOrientationChanged(_ notification:Notification) {
        var deviceOrientation:UIDeviceOrientation = .unknown
        if let device:UIDevice = notification.object as? UIDevice {
            deviceOrientation = device.orientation
        }
        if let orientation:AVCaptureVideoOrientation = DeviceUtil.getAVCaptureVideoOrientation(deviceOrientation) {
            self.orientation = orientation
        }
    }
    #endif
}

extension AVMixer: Runnable {
    // MARK: Runnable
    internal var running:Bool {
        return session.isRunning
    }

    internal func startRunning() {
        session.startRunning()
        #if os(iOS)
        if let orientation:AVCaptureVideoOrientation = DeviceUtil.getAVCaptureVideoOrientation(UIDevice.current.orientation) , syncOrientation {
            self.orientation = orientation
        }
        #endif
    }

    internal func stopRunning() {
        session.stopRunning()
    }
}
