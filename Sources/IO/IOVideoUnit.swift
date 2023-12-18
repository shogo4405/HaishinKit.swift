import AVFoundation
import CoreImage

/// The IOVideoUnit error domain codes.
public enum IOVideoUnitError: Error {
    /// The IOVideoUnit failed to attach device.
    case failedToAttach(error: (any Error)?)
    /// The IOVideoUnit failed to create the VTSession.
    case failedToCreate(status: OSStatus)
    /// The IOVideoUnit  failed to prepare the VTSession.
    case failedToPrepare(status: OSStatus)
    /// The IOVideoUnit failed to encode or decode a flame.
    case failedToFlame(status: OSStatus)
    /// The IOVideoUnit failed to set an option.
    case failedToSetOption(status: OSStatus, option: VTSessionOption)
}

final class IOVideoUnit: NSObject, IOUnit {
    typealias FormatDescription = CMVideoFormatDescription

    enum Error: Swift.Error {
        case multiCamNotSupported
    }

    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.IOVideoUnit.lock")
    weak var drawable: (any IOStreamDrawable)? {
        didSet {
            #if os(iOS) || os(macOS)
            drawable?.videoOrientation = videoOrientation
            #endif
        }
    }
    var mixerSettings: IOVideoMixerSettings {
        get {
            return videoMixer.settings
        }
        set {
            videoMixer.settings = newValue
        }
    }
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
            guard #available(tvOS 17.0, *) else {
                return
            }
            for capture in captures.values {
                capture.setFrameRate(frameRate)
            }
        }
    }

    var torch = false {
        didSet {
            guard #available(tvOS 17.0, *), torch != oldValue else {
                return
            }
            setTorchMode(torch ? .on : .off)
        }
    }
    @available(tvOS 17.0, *)
    var hasDevice: Bool {
        !captures.lazy.filter { $0.value.device != nil }.isEmpty
    }
    #endif

    var context: CIContext {
        get {
            return lockQueue.sync { self.videoMixer.context }
        }
        set {
            lockQueue.async {
                self.videoMixer.context = newValue
            }
        }
    }

    var isRunning: Atomic<Bool> {
        return codec.isRunning
    }

    #if os(iOS) || os(macOS)
    var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            guard videoOrientation != oldValue else {
                return
            }
            mixer?.session.configuration { _ in
                drawable?.videoOrientation = videoOrientation
                for capture in captures.values {
                    capture.videoOrientation = videoOrientation
                }
            }
            // https://github.com/shogo4405/HaishinKit.swift/issues/190
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if self.torch {
                    self.setTorchMode(.on)
                }
            }
        }
    }
    #endif

    #if os(tvOS)
    private var _captures: [UInt8: Any] = [:]
    @available(tvOS 17.0, *)
    private var captures: [UInt8: IOVideoCaptureUnit] {
        return _captures as! [UInt8: IOVideoCaptureUnit]
    }
    #elseif os(iOS) || os(macOS)
    private var captures: [UInt8: IOVideoCaptureUnit] = [:]
    #endif

    private lazy var videoMixer = {
        var videoMixer = IOVideoMixer<IOVideoUnit>()
        videoMixer.delegate = self
        return videoMixer
    }()

    private lazy var codec = {
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

    func registerEffect(_ effect: VideoEffect) -> Bool {
        return videoMixer.registerEffect(effect)
    }

    func unregisterEffect(_ effect: VideoEffect) -> Bool {
        return videoMixer.unregisterEffect(effect)
    }

    func append(_ sampleBuffer: CMSampleBuffer, channel: UInt8 = 0) {
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
            videoMixer.append(sampleBuffer, channel: channel, isVideoMirrored: false)
        default:
            inputFormat = sampleBuffer.formatDescription
            codec.append(sampleBuffer)
        }
    }

    #if os(iOS) || os(tvOS) || os(macOS)
    @available(tvOS 17.0, *)
    func attachCamera(_ device: AVCaptureDevice?, channel: UInt8, configuration: IOVideoCaptureConfigurationBlock?) throws {
        guard captures[channel]?.device != device else {
            return
        }
        if hasDevice && device != nil && captures[channel]?.device == nil && mixer?.session.isMultiCamSessionEnabled == false {
            throw Error.multiCamNotSupported
        }
        try mixer?.session.configuration { _ in
            for capture in captures.values where capture.device == device {
                try? capture.attachDevice(nil, videoUnit: self)
            }
            let capture = self.capture(for: channel)
            configuration?(capture, nil)
            try capture?.attachDevice(device, videoUnit: self)
            if device == nil {
                videoMixer.detach(channel)
            }
        }
        if device != nil && drawable != nil {
            // Start captureing if not running.
            mixer?.session.startRunning()
        }
    }

    @available(tvOS 17.0, *)
    func setTorchMode(_ torchMode: AVCaptureDevice.TorchMode) {
        for capture in captures.values {
            capture.setTorchMode(torchMode)
        }
    }

    @available(tvOS 17.0, *)
    func capture(for channel: UInt8) -> IOVideoCaptureUnit? {
        #if os(tvOS)
        if _captures[channel] == nil {
            _captures[channel] = IOVideoCaptureUnit()
        }
        return _captures[channel] as? IOVideoCaptureUnit
        #else
        if captures[channel] == nil {
            captures[channel] = .init()
        }
        return captures[channel]
        #endif
    }

    @available(tvOS 17.0, *)
    func setBackgroundMode(_ background: Bool) {
        guard let session = mixer?.session, !session.isMultitaskingCameraAccessEnabled else {
            return
        }
        if background {
            for capture in captures.values {
                mixer?.session.detachCapture(capture)
            }
        } else {
            for capture in captures.values {
                mixer?.session.attachCapture(capture)
            }
        }
    }
    #endif

    #if os(macOS)
    func attachScreen(_ input: AVCaptureScreenInput?, channel: UInt8) {
        mixer?.session.configuration { _ in
            let capture = capture(for: channel)
            for capture in captures.values where capture.input == input {
                capture.attachScreen(nil, videoUnit: self)
            }
            capture?.attachScreen(input, videoUnit: self)
        }
    }
    #endif
}

extension IOVideoUnit: Running {
    // MARK: Running
    func startRunning() {
        #if os(iOS)
        codec.passthrough = captures[0]?.preferredVideoStabilizationMode == .off
        #endif
        codec.startRunning()
    }

    func stopRunning() {
        codec.stopRunning()
    }
}

#if os(iOS) || os(tvOS) || os(macOS)
@available(tvOS 17.0, *)
extension IOVideoUnit: AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if captures[0]?.output == captureOutput {
            videoMixer.append(sampleBuffer, channel: 0, isVideoMirrored: connection.isVideoMirrored)
        } else if captures[1]?.output == captureOutput {
            videoMixer.append(sampleBuffer, channel: 1, isVideoMirrored: connection.isVideoMirrored)
        }
    }
}
#endif

extension IOVideoUnit: IOVideoMixerDelegate {
    // MARK: IOVideoMixerDelegate
    func videoMixer(_ videoMixer: IOVideoMixer<IOVideoUnit>, didOutput sampleBuffer: CMSampleBuffer) {
        inputFormat = sampleBuffer.formatDescription
        drawable?.enqueue(sampleBuffer)
    }

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
