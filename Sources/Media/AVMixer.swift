#if os(iOS)
import UIKit
#endif
import Foundation
import AVFoundation

public class AVMixer: NSObject {

    static let supportedSettingsKeys:[String] = [
        "sessionPreset",
        "orientation",
        "continuousAutofocus",
        "continuousExposure",
    ]

#if os(iOS)
    static public func getAVCaptureVideoOrientation(orientation:UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch orientation {
        case .Portrait:
            return .Portrait
        case .PortraitUpsideDown:
            return .PortraitUpsideDown
        case .LandscapeLeft:
            return .LandscapeRight
        case .LandscapeRight:
            return .LandscapeLeft
        default:
            return nil
        }
    }
#endif

    static public func deviceWithPosition(position:AVCaptureDevicePosition) -> AVCaptureDevice? {
        for device in AVCaptureDevice.devices() {
            guard let device:AVCaptureDevice = device as? AVCaptureDevice else {
                continue
            }
            if (device.hasMediaType(AVMediaTypeVideo) && device.position == position) {
                return device
            }
        }
        return nil
    }

    static public func deviceWithLocalizedName(localizedName:String, mediaType:String) -> AVCaptureDevice? {
        for device in AVCaptureDevice.devices() {
            guard let device:AVCaptureDevice = device as? AVCaptureDevice else {
                continue
            }
            if (device.hasMediaType(mediaType) && device.localizedName == localizedName) {
                return device
            }
        }
        return nil
    }

    static let defaultFPS:Int32 = 30
    static let defaultSessionPreset:String = AVCaptureSessionPresetMedium
    static let defaultVideoSettings:[NSObject: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
    ]

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

    private(set) var audioIO:AudioIOComponent = AudioIOComponent()
    private(set) var videoIO:VideoIOComponent = VideoIOComponent()

    override init() {
        super.init()
        audioIO.session = session
        videoIO.session = session
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
        #if os(iOS)
        videoIO.view.layer.setValue(session, forKey: "session")
        #else
        videoIO.view.layer?.setValue(session, forKey: "session")
        #endif
        session.startRunning()
        #if os(iOS)
        if let orientation:AVCaptureVideoOrientation = AVMixer.getAVCaptureVideoOrientation(UIDevice.currentDevice().orientation) {
            self.orientation = orientation
        }
        #endif
    }

    func stopRunning() {
        session.stopRunning()
    }
}
