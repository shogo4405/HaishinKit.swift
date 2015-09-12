import UIKit
import Foundation
import AVFoundation

public class AVCaptureSessionManager: NSObject {

    static public let defaultFPS:Int32 = 30
    static public let defaultSessionPreset:String = AVCaptureSessionPresetMedium
    static public let defaultVideoSettings:[NSObject:AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
    ]

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

    public var FPS:Int32 = AVCaptureSessionManager.defaultFPS

    public var sessionPreset:String = AVCaptureSessionManager.defaultSessionPreset {
        didSet {
            session.beginConfiguration()
            session.sessionPreset = sessionPreset
            session.commitConfiguration()
        }
    }

    public var videoSetting:[NSObject:AnyObject] = AVCaptureSessionManager.defaultVideoSettings {
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

    private var _previewLayer:AVCaptureVideoPreviewLayer? = nil
    var previewLayer:AVCaptureVideoPreviewLayer! {
        get {
            if (_previewLayer == nil) {
                _previewLayer = AVCaptureVideoPreviewLayer(session: session)
            }
            return _previewLayer
        }
    }

    public var orientation:AVCaptureVideoOrientation = AVCaptureVideoOrientation.LandscapeLeft {
        didSet {
            if let connection:AVCaptureConnection = _previewLayer?.connection {
                if (connection.supportsVideoOrientation) {
                    connection.videoOrientation = orientation
                } else {
                    print("AVCaptureConnection.videoOrientation not supported")
                }
            }
            for output:AnyObject in session.outputs {
                if let output:AVCaptureVideoDataOutput = output as? AVCaptureVideoDataOutput {
                    for connection in output.connections {
                        if let connection:AVCaptureConnection = connection as? AVCaptureConnection {
                            if (connection.supportsVideoOrientation) {
                                connection.videoOrientation = orientation
                            } else {
                                print("AVCaptureConnection.videoOrientation not supported")
                            }
                        }
                    }
                }
            }
        }
    }

    deinit {
        syncOrientation = false
    }

    public func attachAudio(audio:AVCaptureDevice?) {
        if (audio == nil) {
            return
        }
        do {
            session.addInput(try AVCaptureDeviceInput(device: audio) as AVCaptureDeviceInput)
            session.addOutput(audioDataOutput!)
        } catch let error as NSError {
            print(error)
        }
    }
    
    public func attachCamera(camera:AVCaptureDevice?) {
        if (camera == nil) {
            return
        }
        do {
            camera!.activeVideoMinFrameDuration = CMTimeMake(1, FPS)
            session.addInput(try AVCaptureDeviceInput(device: camera) as AVCaptureDeviceInput)
            session.addOutput(videoDataOutput!)
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
        switch UIApplication.sharedApplication().statusBarOrientation {
        case .PortraitUpsideDown:
            orientation = AVCaptureVideoOrientation.PortraitUpsideDown
            break
        case .LandscapeRight:
            orientation = AVCaptureVideoOrientation.LandscapeRight
            break
        case .LandscapeLeft:
            orientation = AVCaptureVideoOrientation.LandscapeLeft
            break
        case .Portrait:
            orientation = AVCaptureVideoOrientation.Portrait
            break
        case .Unknown:
            break
        }
    }
}
