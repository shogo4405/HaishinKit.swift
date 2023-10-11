import AVFoundation
import CoreImage

final class IOVideoUnit: NSObject, IOUnit {
    typealias FormatDescription = CMVideoFormatDescription

    enum Error: Swift.Error {
        case multiCamNotSupported
    }

    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.IOVideoUnit.lock")
    weak var drawable: (any NetStreamDrawable)? {
        didSet {
            #if os(iOS) || os(macOS)
            drawable?.videoOrientation = videoOrientation
            #endif
        }
    }
    var multiCamCaptureSettings: MultiCamCaptureSettings = .default
    weak var mixer: IOMixer?
    var muted: Bool {
        get {
            videoMixer.muted
        }
        set {
            videoMixer.muted = newValue
        }
    }
    var settings: VideoCodecSettings {
        get {
            return codec.settings
        }
        set {
            codec.settings = newValue
        }
    }
    private(set) var inputFormat: FormatDescription?
    var outputFormat: FormatDescription? {
        codec.outputFormat
    }
    #if os(iOS) || os(macOS) || os(tvOS)
    var frameRate = IOMixer.defaultFrameRate {
        didSet {
            if #available(tvOS 17.0, *) {
                capture.setFrameRate(frameRate)
                multiCamCapture.setFrameRate(frameRate)
            }
        }
    }

    var torch = false {
        didSet {
            guard torch != oldValue else {
                return
            }
            if #available(tvOS 17.0, *) {
                setTorchMode(torch ? .on : .off)
            }
        }
    }
    #endif

    var context: CIContext = .init()
    var isRunning: Atomic<Bool> = .init(false)

    #if os(iOS) || os(macOS)
    var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            guard videoOrientation != oldValue else {
                return
            }
            mixer?.session.beginConfiguration()
            defer {
                mixer?.session.commitConfiguration()
                // https://github.com/shogo4405/HaishinKit.swift/issues/190
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if self.torch {
                        self.setTorchMode(.on)
                    }
                }
            }
            drawable?.videoOrientation = videoOrientation
            capture.videoOrientation = videoOrientation
            multiCamCapture.videoOrientation = videoOrientation
        }
    }
    #endif

    #if os(tvOS)
    private var _capture: Any?
    @available(tvOS 17.0, *)
    var capture: IOVideoCaptureUnit {
        if _capture == nil {
            _capture = IOVideoCaptureUnit()
        }
        return _capture as! IOVideoCaptureUnit
    }

    private var _multiCamCapture: Any?
    @available(tvOS 17.0, *)
    var multiCamCapture: IOVideoCaptureUnit {
        if _multiCamCapture == nil {
            _multiCamCapture = IOVideoCaptureUnit()
        }
        return _multiCamCapture as! IOVideoCaptureUnit
    }
    #elseif os(iOS) || os(macOS)
    private(set) var capture: IOVideoCaptureUnit = .init()
    private(set) var multiCamCapture: IOVideoCaptureUnit = .init()
    #endif
    private lazy var videoMixer: IOVideoMixer = {
        var videoMixer = IOVideoMixer<IOVideoUnit>()
        videoMixer.delegate = self
        return videoMixer
    }()
    private lazy var codec: VideoCodec = {
        var codec = VideoCodec<IOMixer>(lockQueue: lockQueue)
        codec.delegate = mixer
        return codec
    }()

    deinit {
        if Thread.isMainThread {
            self.drawable?.attachStream(nil)
        } else {
            DispatchQueue.main.sync {
                self.drawable?.attachStream(nil)
            }
        }
    }

    #if os(iOS) || os(tvOS) || os(macOS)
    @available(tvOS 17.0, *)
    func attachCamera(_ device: AVCaptureDevice?) throws {
        guard let mixer, self.capture.device != device else {
            return
        }
        guard let device else {
            mixer.session.beginConfiguration()
            defer {
                mixer.session.commitConfiguration()
            }
            capture.detachSession(mixer.session)
            try capture.attachDevice(nil, videoUnit: self)
            inputFormat = nil
            codec.passthrough = true
            return
        }
        mixer.session.beginConfiguration()
        defer {
            mixer.session.commitConfiguration()
            if torch {
                setTorchMode(.on)
            }
        }
        if multiCamCapture.device == device {
            try multiCamCapture.attachDevice(nil, videoUnit: self)
        }
        try capture.attachDevice(device, videoUnit: self)
        codec.passthrough = false
    }

    @available(iOS 13.0, tvOS 17.0, *)
    func attachMultiCamera(_ device: AVCaptureDevice?) throws {
        #if os(iOS)
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            throw Error.multiCamNotSupported
        }
        #endif
        guard let mixer, multiCamCapture.device != device else {
            return
        }
        guard let device else {
            mixer.session.beginConfiguration()
            defer {
                mixer.session.commitConfiguration()
            }
            multiCamCapture.detachSession(mixer.session)
            try multiCamCapture.attachDevice(nil, videoUnit: self)
            return
        }
        mixer.isMultiCamSessionEnabled = true
        mixer.session.beginConfiguration()
        defer {
            mixer.session.commitConfiguration()
        }
        if capture.device == device {
            try multiCamCapture.attachDevice(nil, videoUnit: self)
        }
        try multiCamCapture.attachDevice(device, videoUnit: self)
    }

    @available(tvOS 17.0, *)
    func setTorchMode(_ torchMode: AVCaptureDevice.TorchMode) {
        capture.setTorchMode(torchMode)
        multiCamCapture.setTorchMode(torchMode)
    }
    #endif

    #if os(macOS)
    func attachScreen(_ input: AVCaptureScreenInput?) {
        guard let mixer else {
            return
        }
        mixer.session.beginConfiguration()
        defer {
            mixer.session.commitConfiguration()
        }
        guard let input else {
            return
        }
        multiCamCapture.attachScreen(input, videoUnit: self)
    }
    #endif

    func registerEffect(_ effect: VideoEffect) -> Bool {
        return videoMixer.registerEffect(effect)
    }

    func unregisterEffect(_ effect: VideoEffect) -> Bool {
        return videoMixer.unregisterEffect(effect)
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        switch sampleBuffer.formatDescription?._mediaSubType {
        case kCVPixelFormatType_1Monochrome,
             kCVPixelFormatType_2Indexed,
             kCVPixelFormatType_8Indexed,
             kCVPixelFormatType_1IndexedGray_WhiteIsZero,
             kCVPixelFormatType_2IndexedGray_WhiteIsZero,
             kCVPixelFormatType_4IndexedGray_WhiteIsZero,
             kCVPixelFormatType_8IndexedGray_WhiteIsZero,
             kCVPixelFormatType_16BE555,
             kCVPixelFormatType_16LE555,
             kCVPixelFormatType_16LE5551,
             kCVPixelFormatType_16BE565,
             kCVPixelFormatType_16LE565,
             kCVPixelFormatType_24RGB,
             kCVPixelFormatType_24BGR,
             kCVPixelFormatType_32ARGB,
             kCVPixelFormatType_32BGRA,
             kCVPixelFormatType_32ABGR,
             kCVPixelFormatType_32RGBA,
             kCVPixelFormatType_64ARGB,
             kCVPixelFormatType_48RGB,
             kCVPixelFormatType_32AlphaGray,
             kCVPixelFormatType_16Gray,
             kCVPixelFormatType_30RGB,
             kCVPixelFormatType_422YpCbCr8,
             kCVPixelFormatType_4444YpCbCrA8,
             kCVPixelFormatType_4444YpCbCrA8R,
             kCVPixelFormatType_4444AYpCbCr8,
             kCVPixelFormatType_4444AYpCbCr16,
             kCVPixelFormatType_444YpCbCr8,
             kCVPixelFormatType_422YpCbCr16,
             kCVPixelFormatType_422YpCbCr10,
             kCVPixelFormatType_444YpCbCr10,
             kCVPixelFormatType_420YpCbCr8Planar,
             kCVPixelFormatType_420YpCbCr8PlanarFullRange,
             kCVPixelFormatType_422YpCbCr_4A_8BiPlanar,
             kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
             kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
             kCVPixelFormatType_422YpCbCr8_yuvs,
             kCVPixelFormatType_422YpCbCr8FullRange,
             kCVPixelFormatType_OneComponent8,
             kCVPixelFormatType_TwoComponent8,
             kCVPixelFormatType_OneComponent16Half,
             kCVPixelFormatType_OneComponent32Float,
             kCVPixelFormatType_TwoComponent16Half,
             kCVPixelFormatType_TwoComponent32Float,
             kCVPixelFormatType_64RGBAHalf,
             kCVPixelFormatType_128RGBAFloat:
            inputFormat = sampleBuffer.formatDescription
            videoMixer.append(sampleBuffer, channel: 0, isVideoMirrored: false)
        default:
            inputFormat = sampleBuffer.formatDescription
            codec.append(sampleBuffer)
        }
    }

    func setConfigurationRecord(_ config: any DecoderConfigurationRecord) {
        _ = config.makeFormatDescription(&inputFormat)
    }
}

extension IOVideoUnit: Running {
    // MARK: Running
    func startRunning() {
        guard !isRunning.value else {
            return
        }
        codec.startRunning()
        isRunning.mutate { $0 = false }
    }

    func stopRunning() {
        guard isRunning.value else {
            return
        }
        codec.stopRunning()
        isRunning.mutate { $0 = true }
    }
}

#if os(iOS) || os(tvOS) || os(macOS)
@available(tvOS 17.0, *)
extension IOVideoUnit: AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if capture.output == captureOutput {
            inputFormat = sampleBuffer.formatDescription
            videoMixer.append(sampleBuffer, channel: 0, isVideoMirrored: connection.isVideoMirrored)
            drawable?.enqueue(sampleBuffer)
        } else if multiCamCapture.output == captureOutput {
            videoMixer.append(sampleBuffer, channel: 1, isVideoMirrored: connection.isVideoMirrored)
        }
    }
}
#endif

extension IOVideoUnit: IOVideoMixerDelegate {
    // MARK: IOVideoMixerDelegate
    func videoMixer(_ videoMixer: IOVideoMixer<IOVideoUnit>, didOutput imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime) {
        codec.append(
            imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: .invalid
        )
        mixer?.recorder.append(
            imageBuffer,
            withPresentationTime: presentationTimeStamp
        )
    }
}
