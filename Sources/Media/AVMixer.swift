#if os(iOS)
import UIKit
#endif
import Foundation
import AVFoundation

final public class AVMixer: NSObject {

    static let supportedSettingsKeys:[String] = [
        "fps",
        "sessionPreset",
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
    public var session:AVCaptureSession! {
        if (_session == nil) {
            _session = AVCaptureSession()
            _session?.beginConfiguration()
            _session?.sessionPreset = AVMixer.defaultSessionPreset
            _session?.commitConfiguration()
        }
        return _session!
    }

    public private(set) lazy var recorder:AVMixerRecorder = AVMixerRecorder()

    public var sampleBuffers:[CMSampleBufferType:CMSampleBuffer?] {
        return [
            .video: videoIO.sampleBuffer,
            .audio: audioIO.sampleBuffer,
        ]
    }

    private(set) lazy var audioIO:AudioIOComponent = {
       return AudioIOComponent(mixer: self)
    }()

    private(set) lazy var videoIO:VideoIOComponent = {
       return VideoIOComponent(mixer: self)
    }()
}

extension AVMixer {
    final func startPlaying() {
        videoIO.queue.startRunning()
    }
    final func stopPlaying() {
        videoIO.queue.stopRunning()
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
