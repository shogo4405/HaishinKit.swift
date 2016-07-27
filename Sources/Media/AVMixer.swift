#if os(iOS)
import UIKit
#endif
import Foundation
import AVFoundation

class AVMixer: NSObject {

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
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)
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
            let center:NSNotificationCenter = NSNotificationCenter.defaultCenter()
            if (syncOrientation) {
                center.addObserver(self, selector: #selector(AVMixer.onOrientationChanged(_:)), name: UIDeviceOrientationDidChangeNotification, object: nil)
            } else {
                center.removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
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

    private var _session:AVCaptureSession? = nil
    var session:AVCaptureSession! {
        if (_session == nil) {
            _session = AVCaptureSession()
            _session!.sessionPreset = AVMixer.defaultSessionPreset
        }
        return _session!
    }

    private(set) var audioIO:AudioIOComponent!
    private(set) var videoIO:VideoIOComponent!
    private(set) lazy var recorder:AVMixerRecorder = AVMixerRecorder()

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
    func onOrientationChanged(notification:NSNotification) {
        var deviceOrientation:UIDeviceOrientation = .Unknown
        if let device:UIDevice = notification.object as? UIDevice {
            deviceOrientation = device.orientation
        }
        if let orientation:AVCaptureVideoOrientation = AVMixer.getAVCaptureVideoOrientation(deviceOrientation) {
            self.orientation = orientation
        }
    }
    #endif
}

// MARK: Runnable
extension AVMixer: Runnable {
    var running:Bool {
        return session.running
    }

    func startRunning() {
        session.startRunning()
        #if os(iOS)
        if let orientation:AVCaptureVideoOrientation = AVMixer.getAVCaptureVideoOrientation(UIDevice.currentDevice().orientation) where syncOrientation {
            self.orientation = orientation
        }
        #endif
    }

    func stopRunning() {
        session.stopRunning()
    }
}
