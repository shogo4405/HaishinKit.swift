import UIKit
import Foundation
import AVFoundation

public class AVCaptureSessionManager: NSObject {
    static public let defaultFPS:Int32 = 30
    static public let defaultVideoSettings:Dictionary<NSObject, AnyObject> = [
        kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
    ]
    static public let defaultSessionPreset:String = AVCaptureSessionPresetMedium

    private var _session:AVCaptureSession? = nil
    public var session:AVCaptureSession! {
        get {
            if (_session == nil) {
                _session = AVCaptureSession()
                _session!.sessionPreset = AVCaptureSessionManager.defaultSessionPreset
            }
            return _session!
        }
    }

    public var FPS:Int32 = AVCaptureSessionManager.defaultFPS

    public var sessionPreset:String = AVCaptureSessionManager.defaultSessionPreset {
        didSet {
            session.beginConfiguration()
            session.sessionPreset = sessionPreset
            session.commitConfiguration()
        }
    }

    public var videoSetting:Dictionary<NSObject, AnyObject> = AVCaptureSessionManager.defaultVideoSettings {
        didSet {
            videoDataOutput.videoSettings = videoSetting
        }
    }

    private var _videoDataOutput:AVCaptureVideoDataOutput? = nil
    var videoDataOutput:AVCaptureVideoDataOutput! {
        get {
            if (_videoDataOutput == nil) {
                _videoDataOutput = AVCaptureVideoDataOutput()
                _videoDataOutput!.alwaysDiscardsLateVideoFrames = true
                _videoDataOutput!.videoSettings = videoSetting
            }
            return _videoDataOutput!
        }
        set {
            if (_videoDataOutput == newValue) {
                return
            }
            if (_videoDataOutput != nil) {
                session.removeOutput(_videoDataOutput!)
            }
            _videoDataOutput = newValue
        }
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

    public var orientation:UIInterfaceOrientation = UIInterfaceOrientation.Unknown {
        didSet {
            for output:AnyObject in session.outputs {
                if let output:AVCaptureVideoDataOutput = output as? AVCaptureVideoDataOutput {
                    for connection in output.connections {
                        if let connection:AVCaptureConnection = connection as? AVCaptureConnection {
                            switch orientation {
                            case .PortraitUpsideDown:
                                connection.videoOrientation = AVCaptureVideoOrientation.PortraitUpsideDown
                                break
                            case .LandscapeRight:
                                connection.videoOrientation = AVCaptureVideoOrientation.LandscapeRight
                                break
                            case .LandscapeLeft:
                                connection.videoOrientation = AVCaptureVideoOrientation.LandscapeLeft
                                break
                            case .Portrait:
                                connection.videoOrientation = AVCaptureVideoOrientation.Portrait
                                break
                            case .Unknown:
                                break
                            }
                        }
                    }
                }
            }
        }
    }

    public func attachAudio(audio:AVCaptureDevice?) {
        if (audio == nil) {
            return
        }
        session.addInput(AVCaptureDeviceInput.deviceInputWithDevice(audio!, error: nil) as! AVCaptureDeviceInput)
        session.addOutput(audioDataOutput!)
    }
    
    public func attachCamera(camera:AVCaptureDevice?) {
        if (camera == nil) {
            return
        }
        camera!.activeVideoMinFrameDuration = CMTimeMake(1, FPS)
        session.addInput(AVCaptureDeviceInput.deviceInputWithDevice(camera!, error: nil) as! AVCaptureDeviceInput)
        session.addOutput(videoDataOutput!)
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

    public func detectOrientation() {
        let orientation:UIInterfaceOrientation = UIApplication.sharedApplication().statusBarOrientation
        if (self.orientation != orientation) {
            self.orientation = orientation
        }
    }}