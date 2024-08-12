import AVFoundation
import CoreImage

final class VideoCaptureUnit: CaptureUnit {
    enum Error: Swift.Error {
        case multiCamNotSupported
    }

    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.IOVideoUnit.lock")

    var mixerSettings: VideoMixerSettings {
        get {
            return videoMixer.settings
        }
        set {
            videoMixer.settings = newValue
        }
    }
    var inputFormats: [UInt8: CMFormatDescription] {
        return videoMixer.inputFormats
    }
    var frameRate = MediaMixer.defaultFrameRate {
        didSet {
            guard #available(tvOS 17.0, *) else {
                return
            }
            for capture in captures.values {
                capture.setFrameRate(frameRate)
            }
        }
    }

    #if os(iOS) || os(tvOS) || os(macOS)
    var torch = false {
        didSet {
            guard #available(tvOS 17.0, *), torch != oldValue else {
                return
            }
            setTorchMode(torch ? .on : .off)
        }
    }
    #endif

    @available(tvOS 17.0, *)
    var hasDevice: Bool {
        !captures.lazy.filter { $0.value.device != nil }.isEmpty
    }

    #if os(iOS) || os(macOS)
    var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            guard videoOrientation != oldValue else {
                return
            }
            session.configuration { _ in
                for capture in captures.values {
                    capture.videoOrientation = videoOrientation
                }
            }
        }
    }
    #endif

    var inputs: AsyncStream<(UInt8, CMSampleBuffer)> {
        let (stream, continutation) = AsyncStream<(UInt8, CMSampleBuffer)>.makeStream()
        self.inputsContinutation = continutation
        return stream
    }

    var output: AsyncStream<CMSampleBuffer> {
        let (stream, continutation) = AsyncStream<CMSampleBuffer>.makeStream()
        self.continuation = continutation
        return stream
    }

    private lazy var videoMixer = {
        var videoMixer = VideoMixer<VideoCaptureUnit>()
        videoMixer.delegate = self
        return videoMixer
    }()
    private var continuation: AsyncStream<CMSampleBuffer>.Continuation?
    private var inputsContinutation: AsyncStream<(UInt8, CMSampleBuffer)>.Continuation?
    #if os(tvOS)
    private var _captures: [UInt8: Any] = [:]
    @available(tvOS 17.0, *)
    var captures: [UInt8: IOVideoCaptureUnit] {
        return _captures as! [UInt8: IOVideoCaptureUnit]
    }
    #elseif os(iOS) || os(macOS) || os(visionOS)
    var captures: [UInt8: VideoDeviceUnit] = [:]
    #endif
    private let session: CaptureSession

    init(_ session: CaptureSession) {
        self.session = session
    }

    func append(_ track: UInt8, buffer: CMSampleBuffer) {
        videoMixer.append(track, sampleBuffer: buffer)
    }

    @available(tvOS 17.0, *)
    func attachCamera(_ track: UInt8, device: AVCaptureDevice?, configuration: VideoDeviceConfigurationBlock?) throws {
        guard captures[track]?.device != device else {
            return
        }
        if hasDevice && device != nil && captures[track]?.device == nil && session.isMultiCamSessionEnabled == false {
            throw Error.multiCamNotSupported
        }
        try session.configuration { _ in
            for capture in captures.values where capture.device == device {
                try? capture.attachDevice(nil, session: session, videoUnit: self)
            }
            let capture = self.capture(for: track)
            configuration?(capture)
            try capture?.attachDevice(device, session: session, videoUnit: self)
        }
        if device != nil {
            // Start captureing if not running.
            session.startRunning()
        }
        if device == nil {
            videoMixer.reset(track)
        }
    }

    #if os(iOS) || os(tvOS) || os(macOS)
    @available(tvOS 17.0, *)
    func setTorchMode(_ torchMode: AVCaptureDevice.TorchMode) {
        for capture in captures.values {
            capture.setTorchMode(torchMode)
        }
    }
    #endif

    @available(tvOS 17.0, *)
    func setBackgroundMode(_ background: Bool) {
        guard !session.isMultitaskingCameraAccessEnabled else {
            return
        }
        if background {
            for capture in captures.values {
                session.detachCapture(capture)
            }
        } else {
            for capture in captures.values {
                session.attachCapture(capture)
            }
        }
    }

    @available(tvOS 17.0, *)
    func makeDataOutput(_ track: UInt8) -> IOVideoCaptureUnitDataOutput {
        return .init(track: track, videoMixer: videoMixer)
    }

    @available(tvOS 17.0, *)
    func capture(for track: UInt8) -> VideoDeviceUnit? {
        #if os(tvOS)
        if _captures[track] == nil {
            _captures[track] = .init(track)
        }
        return _captures[track] as? IOVideoCaptureUnit
        #else
        if captures[track] == nil {
            captures[track] = .init(track)
        }
        return captures[track]
        #endif
    }
}

extension VideoCaptureUnit: VideoMixerDelegate {
    // MARK: IOVideoMixerDelegate
    func videoMixer(_ videoMixer: VideoMixer<VideoCaptureUnit>, track: UInt8, didInput sampleBuffer: CMSampleBuffer) {
        inputsContinutation?.yield((track, sampleBuffer))
    }

    func videoMixer(_ videoMixer: VideoMixer<VideoCaptureUnit>, didOutput sampleBuffer: CMSampleBuffer) {
        continuation?.yield(sampleBuffer)
    }
}
