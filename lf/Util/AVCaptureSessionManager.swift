import UIKit
import Foundation
import AVFoundation

public class AVCaptureSessionManager: NSObject {

    static let supportedSettingsKeys:[String] = [
        "sessionPreset",
        "orientation"
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
            if let device = device as? AVCaptureDevice {
                if (device.hasMediaType(AVMediaTypeVideo) && device.position == position) {
                    return device
                }
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

    //MARK: - AVCaptureDevice Configurations
    public var torch = false {
        didSet {
            if let device = currentCamera?.device {
                let torchMode = torch ? AVCaptureTorchMode.On : AVCaptureTorchMode.Off
                
                if device.isTorchModeSupported(torchMode) && device.torchAvailable {
                    
                    do {
                        try device.lockForConfiguration()
                        device.torchMode = torchMode
                        device.unlockForConfiguration()
                    }
                    catch let error {
                        print("Error while setting torch: \(error)")
                    }
                    
                }
                else {
                    print("torch mode not supported");
                }
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
    
    public var continuousAutofocus = true {
        didSet {
            if let device = currentCamera?.device {
                let focusMode = continuousAutofocus ? AVCaptureFocusMode.ContinuousAutoFocus : AVCaptureFocusMode.AutoFocus
                
                if device.isFocusModeSupported(focusMode) {
                    
                    do {
                        try device.lockForConfiguration()
                        device.focusMode = focusMode
                        device.unlockForConfiguration()
                    }
                    catch let error {
                        print("Error while locking device for autofocus: \(error)")
                    }
                    
                }
                else {
                    print("Focus mode not supported");
                }
            }
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
    
    public var continuousExposure = true {
        didSet {
            if let device = currentCamera?.device {
                let exposeMode = continuousExposure ? AVCaptureExposureMode.ContinuousAutoExposure : AVCaptureExposureMode.AutoExpose
                
                if device.isExposureModeSupported(exposeMode) {
                    
                    do {
                        try device.lockForConfiguration()
                        device.exposureMode = exposeMode
                        device.unlockForConfiguration()
                    }
                    catch let error {
                        print("Error while locking device for autoexpose: \(error)")
                    }
                    
                }
                else {
                    print("expose mode not supported");
                }
            }
        }
    }

    //MARK: - AVCaptureDevice Configurations
    public var torch = false {
        didSet {
            if let device = currentCamera?.device {
                let torchMode = torch ? AVCaptureTorchMode.On : AVCaptureTorchMode.Off
                
                if device.isTorchModeSupported(torchMode) && device.torchAvailable {
                    
                    do {
                        try device.lockForConfiguration()
                        device.torchMode = torchMode
                        device.unlockForConfiguration()
                    }
                    catch let error {
                        print("Error while setting torch: \(error)")
                    }
                    
                }
                else {
                    print("torch mode not supported");
                }
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
    
    public var continuousAutofocus = true {
        didSet {
            if let device = currentCamera?.device {
                let focusMode = continuousAutofocus ? AVCaptureFocusMode.ContinuousAutoFocus : AVCaptureFocusMode.AutoFocus
                
                if device.isFocusModeSupported(focusMode) {
                    
                    do {
                        try device.lockForConfiguration()
                        device.focusMode = focusMode
                        device.unlockForConfiguration()
                    }
                    catch let error {
                        print("Error while locking device for autofocus: \(error)")
                    }
                    
                }
                else {
                    print("Focus mode not supported");
                }
            }
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
    
    public var continuousExposure = true {
        didSet {
            if let device = currentCamera?.device {
                let exposeMode = continuousExposure ? AVCaptureExposureMode.ContinuousAutoExposure : AVCaptureExposureMode.AutoExpose
                
                if device.isExposureModeSupported(exposeMode) {
                    
                    do {
                        try device.lockForConfiguration()
                        device.exposureMode = exposeMode
                        device.unlockForConfiguration()
                    }
                    catch let error {
                        print("Error while locking device for autoexpose: \(error)")
                    }
                    
                }
                else {
                    print("expose mode not supported");
                }
            }
        }
    }

    public override init() {
        super.init()
        if let orientation:AVCaptureVideoOrientation = AVCaptureSessionManager.getAVCaptureVideoOrientation(UIDevice.currentDevice().orientation) {
            self.orientation = orientation
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

    private var currentAudio:AVCaptureDeviceInput? = nil {
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

    private var currentCamera:AVCaptureDeviceInput? = nil {
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

    deinit {
        syncOrientation = false
    }

    public func attachAudio(audio:AVCaptureDevice?) {
        audioDataOutput = nil
        guard audio != nil else {
            currentAudio = nil
            return
        }
        do {
            currentAudio = try AVCaptureDeviceInput(device: audio!)
            session.addOutput(audioDataOutput)
        } catch let error as NSError {
            print(error)
        }
    }

    public func attachCamera(camera:AVCaptureDevice?) {
        videoDataOutput = nil
        guard camera != nil else {
            currentCamera = nil
            return
        }
        do {
            camera!.activeVideoMinFrameDuration = CMTimeMake(1, FPS)
            currentCamera = try AVCaptureDeviceInput(device: camera!)
            session.addOutput(videoDataOutput)
            for connection in videoDataOutput.connections {
                if let connection:AVCaptureConnection = connection as? AVCaptureConnection {
                    if (connection.supportsVideoOrientation) {
                        connection.videoOrientation = orientation
                    }
                }
            }
        } catch let error as NSError {
            print(error)
        }
    }

    public func startRunning() {
        if (!session.running) {
            session.startRunning()
        }
    }

    public func stopRunning() {
        if (session.running) {
            session.stopRunning()
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
