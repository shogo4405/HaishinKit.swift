import AVFoundation
import CoreImage

final class VideoCaptureUnit: CaptureUnit {
    enum Error: Swift.Error {
        case multiCamNotSupported
    }

    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.VideoCaptureUnit.lock")

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
            for capture in devices.values {
                capture.setFrameRate(frameRate)
            }
        }
    }

    #if os(iOS) || os(tvOS) || os(macOS)
    var isTorchEnabled = false {
        didSet {
            guard #available(tvOS 17.0, *) else {
                return
            }
            setTorchMode(isTorchEnabled ? .on : .off)
        }
    }
    #endif

    @available(tvOS 17.0, *)
    var hasDevice: Bool {
        !devices.lazy.filter { $0.value.device != nil }.isEmpty
    }

    #if os(iOS) || os(macOS)
    var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            guard videoOrientation != oldValue else {
                return
            }
            session.configuration { _ in
                for capture in devices.values {
                    capture.videoOrientation = videoOrientation
                }
            }
        }
    }
    #endif

    var inputs: AsyncStream<(UInt8, CMSampleBuffer)> {
        AsyncStream<(UInt8, CMSampleBuffer)> { continutation in
            self.inputsContinuation = continutation
        }
    }

    var output: AsyncStream<CMSampleBuffer> {
        AsyncStream<CMSampleBuffer> { continutation in
            self.outputContinuation = continutation
        }
    }

    private lazy var videoMixer = {
        var videoMixer = VideoMixer<VideoCaptureUnit>()
        videoMixer.delegate = self
        return videoMixer
    }()

    private var outputContinuation: AsyncStream<CMSampleBuffer>.Continuation?
    private var inputsContinuation: AsyncStream<(UInt8, CMSampleBuffer)>.Continuation?

    #if os(tvOS)
    private var _devices: [UInt8: Any] = [:]
    @available(tvOS 17.0, *)
    var devices: [UInt8: VideoDeviceUnit] {
        return _devices as! [UInt8: VideoDeviceUnit]
    }
    #elseif os(iOS) || os(macOS) || os(visionOS)
    var devices: [UInt8: VideoDeviceUnit] = [:]
    #endif

    private let session: CaptureSession

    init(_ session: CaptureSession) {
        self.session = session
    }

    func append(_ track: UInt8, buffer: CMSampleBuffer) {
        videoMixer.append(track, sampleBuffer: buffer)
    }

    @available(tvOS 17.0, *)
    func attachVideo(_ track: UInt8, device: AVCaptureDevice?, configuration: VideoDeviceConfigurationBlock?) throws {
        guard devices[track]?.device != device else {
            return
        }
        if hasDevice && device != nil && devices[track]?.device == nil && session.isMultiCamSessionEnabled == false {
            throw Error.multiCamNotSupported
        }
        try session.configuration { _ in
            for capture in devices.values where capture.device == device {
                try? capture.attachDevice(nil, session: session, videoUnit: self)
            }
            guard let capture = self.device(for: track) else {
                return
            }
            try? configuration?(capture)
            videoMixer.reset(track)
            try capture.attachDevice(device, session: session, videoUnit: self)
        }
    }

    #if os(iOS) || os(tvOS) || os(macOS)
    @available(tvOS 17.0, *)
    func setTorchMode(_ torchMode: AVCaptureDevice.TorchMode) {
        for capture in devices.values {
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
            for capture in devices.values {
                session.detachCapture(capture)
            }
        } else {
            for capture in devices.values {
                session.attachCapture(capture)
            }
        }
    }

    @available(tvOS 17.0, *)
    func makeDataOutput(_ track: UInt8) -> IOVideoCaptureUnitDataOutput {
        return .init(track: track, videoMixer: videoMixer)
    }

    func finish() {
        inputsContinuation?.finish()
        outputContinuation?.finish()
    }

    @available(tvOS 17.0, *)
    private func device(for track: UInt8) -> VideoDeviceUnit? {
        #if os(tvOS)
        if _devices[track] == nil {
            _devices[track] = .init(track)
        }
        return _devices[track] as? VideoDeviceUnit
        #else
        if devices[track] == nil {
            devices[track] = .init(track)
        }
        return devices[track]
        #endif
    }
}

extension VideoCaptureUnit: VideoMixerDelegate {
    // MARK: VideoMixerDelegate
    func videoMixer(_ videoMixer: VideoMixer<VideoCaptureUnit>, track: UInt8, didInput sampleBuffer: CMSampleBuffer) {
        inputsContinuation?.yield((track, sampleBuffer))
    }

    func videoMixer(_ videoMixer: VideoMixer<VideoCaptureUnit>, didOutput sampleBuffer: CMSampleBuffer) {
        outputContinuation?.yield(sampleBuffer)
    }
}
