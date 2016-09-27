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

    var continuousExposure:Bool {
        get { return videoIO.continuousExposure }
        set { videoIO.continuousExposure = newValue }
    }

    var continuousAutofocus:Bool {
        get { return videoIO.continuousAutofocus }
        set { videoIO.continuousAutofocus = newValue }
    }

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
            _session?.beginConfiguration()
            _session?.sessionPreset = AVMixer.defaultSessionPreset
            _session?.commitConfiguration()
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
}

extension AVMixer: Runnable {
    // MARK: Runnable
    var running:Bool {
        return session.isRunning
    }

    final func startRunning() {
        guard !running else {
            return
        }
        session.startRunning()
    }

    final func stopRunning() {
        guard running else {
            return
        }
        session.stopRunning()
    }
}
