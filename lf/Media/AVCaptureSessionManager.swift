import UIKit
import Foundation
import AVFoundation

public class AVCaptureSessionManager: NSObject {

    static let supportedSettingsKeys:[String] = [
        "sessionPreset",
        "orientation",
        "continuousAutofocus",
        "continuousExposure",
    ]

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

    static public let defaultFPS:Int32 = 30
    static public let defaultSessionPreset:String = AVCaptureSessionPresetMedium
    static public let defaultVideoSettings:[NSObject: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
    ]

    public var FPS:Int32 = AVCaptureSessionManager.defaultFPS

    public var orientation:AVCaptureVideoOrientation = .Portrait {
        didSet {
            guard orientation != oldValue else {
                return
            }

            if let connection:AVCaptureConnection = _layer?.connection {
                if (connection.supportsVideoOrientation) {
                    connection.videoOrientation = orientation
                }
            }

            if (_videoDataOutput != nil) {
                for connection in _videoDataOutput!.connections {
                    if let connection:AVCaptureConnection = connection as? AVCaptureConnection {
                        if (connection.supportsVideoOrientation) {
                            connection.videoOrientation = orientation
                        }
                    }
                }
            }
        }
    }

    public var torch:Bool = false {
        didSet {
            let torchMode:AVCaptureTorchMode = torch ? .On : .Off
            guard let device:AVCaptureDevice = currentCamera?.device
                where device.isTorchModeSupported(torchMode) && device.torchAvailable else {
                logger.warning("torchMode(\(torchMode)) is not supported")
                return
            }
            do {
                try device.lockForConfiguration()
                device.torchMode = torchMode
                device.unlockForConfiguration()
            }
            catch let error as NSError {
                logger.error("while setting torch: \(error)")
            }
        }
    }

    public var continuousAutofocus:Bool = true {
        didSet {
            let focusMode:AVCaptureFocusMode = continuousAutofocus ? .ContinuousAutoFocus : .AutoFocus
            guard let device:AVCaptureDevice = currentCamera?.device
                where device.isFocusModeSupported(focusMode) else {
                logger.warning("focusMode\(focusMode) is not supported")
                return
            }
            do {
                try device.lockForConfiguration()
                device.focusMode = focusMode
                device.unlockForConfiguration()
            }
            catch let error as NSError {
                logger.error("while locking device for autofocus: \(error)")
            }
        }
    }

    public var focusPointOfInterest: CGPoint? {
        set {
            if let device = currentCamera?.device {
                
                if device.focusPointOfInterestSupported {
                    
                    if let newValue = newValue {
                        do {
                            try device.lockForConfiguration()
                            device.focusPointOfInterest = newValue
                            device.focusMode = AVCaptureFocusMode.AutoFocus
                            device.unlockForConfiguration()
                        }
                        catch let error {
                            print("Error while locking device for focus poi: \(error)")
                        }
                    }
                }
                else {
                    print("focus poi not supported");
                }
            }
        }
        
        get {
            return self.focusPointOfInterest
        }
    }
    
    public var exposurePointOfInterest: CGPoint? {
        set {
            if let device = currentCamera?.device {

                if device.exposurePointOfInterestSupported {
                    
                    if let newValue = newValue {
                        do {
                            try device.lockForConfiguration()
                            device.exposurePointOfInterest = newValue
                            device.exposureMode = AVCaptureExposureMode.AutoExpose
                            device.unlockForConfiguration()
                        }
                        catch let error {
                            print("Error while locking device for expose poi: \(error)")
                        }
                    }
                }
                else {
                    print("expose poi not supported");
                }
            }
        }
        get {
            return self.exposurePointOfInterest
        }
    }

    public var continuousExposure:Bool = true {
        didSet {
            let exposeMode:AVCaptureExposureMode = continuousExposure ? .ContinuousAutoExposure : .AutoExpose
            guard let device:AVCaptureDevice = currentCamera?.device
                where device.isExposureModeSupported(exposeMode) else {
                logger.warning("exposeMode\(exposeMode) not supported")
                return
            }
            do {
                try device.lockForConfiguration()
                device.exposureMode = exposeMode
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for autoexpose: \(error)")
            }
        }
    }

    public var syncOrientation:Bool = false {
        didSet {
            let center:NSNotificationCenter = NSNotificationCenter.defaultCenter()
            if (syncOrientation) {
                center.addObserver(self, selector: "onOrientationChanged:", name: UIDeviceOrientationDidChangeNotification, object: nil)
            } else {
                center.removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
            }
        }
    }

    public var sessionPreset:String = AVCaptureSessionManager.defaultSessionPreset {
        didSet {
            session.beginConfiguration()
            session.sessionPreset = sessionPreset
            session.commitConfiguration()
        }
    }

    public var videoSettings:[NSObject:AnyObject] = AVCaptureSessionManager.defaultVideoSettings {
        didSet {
            videoDataOutput.videoSettings = videoSettings
        }
    }

    private var _session:AVCaptureSession? = nil
    var session:AVCaptureSession! {
        if (_session == nil) {
            _session = AVCaptureSession()
            _session!.sessionPreset = AVCaptureSessionManager.defaultSessionPreset
        }
        return _session!
    }

    private var _audioDataOutput:AVCaptureAudioDataOutput? = nil
    var audioDataOutput:AVCaptureAudioDataOutput! {
        get {
            if (_audioDataOutput == nil) {
                _audioDataOutput = AVCaptureAudioDataOutput()
            }
            return _audioDataOutput
        }
        set {
            if (_audioDataOutput == newValue) {
                return
            }
            if (_audioDataOutput != nil) {
                _audioDataOutput!.setSampleBufferDelegate(nil, queue: nil)
                session.removeOutput(_audioDataOutput!)
            }
            _audioDataOutput = newValue
        }
    }

    private var _videoDataOutput:AVCaptureVideoDataOutput? = nil
    var videoDataOutput:AVCaptureVideoDataOutput! {
        get {
            if (_videoDataOutput == nil) {
                _videoDataOutput = AVCaptureVideoDataOutput()
                _videoDataOutput!.alwaysDiscardsLateVideoFrames = true
                _videoDataOutput!.videoSettings = videoSettings
            }
            return _videoDataOutput!
        }
        set {
            if (_videoDataOutput == newValue) {
                return
            }
            if (_videoDataOutput != nil) {
                _videoDataOutput!.setSampleBufferDelegate(nil, queue: nil)
                session.removeOutput(_videoDataOutput!)
            }
            _videoDataOutput = newValue
        }
    }

    private var _layer:AVCaptureVideoPreviewLayer? = nil
    var layer:AVCaptureVideoPreviewLayer! {
        if (_layer == nil) {
            _layer = AVCaptureVideoPreviewLayer(session: session)
            if let connection:AVCaptureConnection = _layer?.connection {
                if (connection.supportsVideoOrientation) {
                    connection.videoOrientation = orientation
                }
            }
        }
        return _layer
    }

    public private(set) var currentAudio:AVCaptureDeviceInput? = nil {
        didSet {
            guard oldValue != currentAudio else {
                return
            }
            if (oldValue != nil) {
                session.removeInput(oldValue!)
            }
            if (currentAudio != nil) {
                session.addInput(currentAudio!)
            }
        }
    }

    public private(set) var currentCamera:AVCaptureDeviceInput? = nil {
        didSet {
            guard oldValue != currentCamera else {
                return
            }
            if (oldValue != nil) {
                session.removeInput(oldValue!)
            }
            if (currentCamera != nil) {
                session.addInput(currentCamera!)
            }
        }
    }

    public override init() {
        super.init()
        if let orientation:AVCaptureVideoOrientation = AVCaptureSessionManager.getAVCaptureVideoOrientation(UIDevice.currentDevice().orientation) {
            self.orientation = orientation
        }
    }

    deinit {
        syncOrientation = false
    }

    public func attachAudio(audio:AVCaptureDevice?) {
        audioDataOutput = nil
        guard let audio:AVCaptureDevice = audio else {
            currentAudio = nil
            return
        }
        do {
            currentAudio = try AVCaptureDeviceInput(device: audio)
            session.addOutput(audioDataOutput)
        } catch let error as NSError {
            logger.error("\(error)")
        }
    }

    public func attachCamera(camera:AVCaptureDevice?) {
        videoDataOutput = nil
        guard let camera:AVCaptureDevice = camera else {
            currentCamera = nil
            return
        }
        do {
            camera.activeVideoMinFrameDuration = CMTimeMake(1, FPS)
            currentCamera = try AVCaptureDeviceInput(device: camera)
            session.addOutput(videoDataOutput)
            for connection in videoDataOutput.connections {
                guard let connection:AVCaptureConnection = connection as? AVCaptureConnection else {
                    continue
                }
                if (connection.supportsVideoOrientation) {
                    connection.videoOrientation = orientation
                }
            }
        } catch let error as NSError {
            logger.error("\(error)")
        }
    }

    func onOrientationChanged(notification:NSNotification) {
        var deviceOrientation:UIDeviceOrientation = .Unknown
        if let device:UIDevice = notification.object as? UIDevice {
            deviceOrientation = device.orientation
        }
        if let orientation:AVCaptureVideoOrientation = AVCaptureSessionManager.getAVCaptureVideoOrientation(deviceOrientation) {
            self.orientation = orientation
        }
    }
}

// MARK: - Runnable
extension AVCaptureSessionManager: Runnable {
    public func startRunning() {
        session.startRunning()
    }
    
    public func stopRunning() {
        session.stopRunning()
    }
}

