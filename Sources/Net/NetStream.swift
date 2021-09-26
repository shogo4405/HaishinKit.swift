import AVFoundation
import CoreImage

/// The `NetStream` class is the foundation of a RTMPStream, HTTPStream.
open class NetStream: NSObject {
    private static let queueKey = DispatchSpecificKey<UnsafeMutableRawPointer>()
    private static let queueValue = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)

    public let lockQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetStream.lock")
        queue.setSpecific(key: queueKey, value: queueValue)
        return queue
    }()

    open private(set) var mixer = AVMixer()
    open var metadata: [String: Any?] = [:]
    open var context: CIContext? {
        get { mixer.videoIO.context }
        set { mixer.videoIO.context = newValue }
    }

#if os(iOS) || os(macOS)
    open var torch: Bool {
        get {
            var torch: Bool = false
            ensureLockQueue {
                torch = self.mixer.videoIO.torch
            }
            return torch
        }
        set {
            lockQueue.async {
                self.mixer.videoIO.torch = newValue
            }
        }
    }

    /// Specify stream video orientation.
    open var videoOrientation: AVCaptureVideoOrientation {
        get { mixer.videoIO.orientation }
        set { mixer.videoIO.orientation = newValue }
    }
#endif

    /// Specify stream audio compression properties.
    open var audioSettings: Setting<AudioCodec, AudioCodec.Option> {
        get { mixer.audioIO.codec.settings }
        set { mixer.audioIO.codec.settings = newValue }
    }

    /// Specify stream video compression properties.
    open var videoSettings: Setting<VideoCodec, VideoCodec.Option> {
        get { mixer.videoIO.encoder.settings }
        set { mixer.videoIO.encoder.settings = newValue }
    }

    /// Specify stream avsession properties.
    open var captureSettings: Setting<AVMixer, AVMixer.Option> {
        get { mixer.settings }
        set { mixer.settings = newValue }
    }

    open var recorderSettings: [AVMediaType: [String: Any]] {
        get { mixer.recorder.outputSettings }
        set { mixer.recorder.outputSettings = newValue }
    }

    deinit {
        metadata.removeAll()
    }

#if os(iOS) || os(macOS)
    open func attachCamera(_ camera: AVCaptureDevice?, onError: ((_ error: NSError) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.mixer.videoIO.attachCamera(camera)
            } catch let error as NSError {
                onError?(error)
            }
        }
    }

    open func attachAudio(_ audio: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool = false, onError: ((_ error: NSError) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.mixer.audioIO.attachAudio(audio, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession)
            } catch let error as NSError {
                onError?(error)
            }
        }
    }

    open func setPointOfInterest(_ focus: CGPoint, exposure: CGPoint) {
        mixer.videoIO.focusPointOfInterest = focus
        mixer.videoIO.exposurePointOfInterest = exposure
    }
#endif

    open func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, withType: AVMediaType, options: [NSObject: AnyObject]? = nil) {
        switch withType {
        case .audio:
            mixer.audioIO.lockQueue.async {
                self.mixer.audioIO.appendSampleBuffer(sampleBuffer)
            }
        case .video:
            mixer.videoIO.lockQueue.async {
                self.mixer.videoIO.encodeSampleBuffer(sampleBuffer)
            }
        default:
            break
        }
    }

    open func registerVideoEffect(_ effect: VideoEffect) -> Bool {
        mixer.videoIO.lockQueue.sync {
            self.mixer.videoIO.registerEffect(effect)
        }
    }

    open func unregisterVideoEffect(_ effect: VideoEffect) -> Bool {
        mixer.videoIO.lockQueue.sync {
            self.mixer.videoIO.unregisterEffect(effect)
        }
    }

    open func registerAudioEffect(_ effect: AudioEffect) -> Bool {
        mixer.audioIO.lockQueue.sync {
            self.mixer.audioIO.registerEffect(effect)
        }
    }

    open func unregisterAudioEffect(_ effect: AudioEffect) -> Bool {
        mixer.audioIO.lockQueue.sync {
            self.mixer.audioIO.unregisterEffect(effect)
        }
    }

    func ensureLockQueue(callback: () -> Void) {
        if DispatchQueue.getSpecific(key: NetStream.queueKey) == NetStream.queueValue {
            callback()
        } else {
            lockQueue.sync {
                callback()
            }
        }
    }
}
