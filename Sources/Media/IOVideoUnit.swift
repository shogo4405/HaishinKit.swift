import AVFoundation
import CoreImage

final class IOVideoUnit: NSObject, IOUnit {
    enum Error: Swift.Error {
        case multiCamNotSupported
    }

    static let defaultAttributes: [NSString: NSObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue
    ]

    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.VideoIOComponent.lock")

    var context: CIContext = .init() {
        didSet {
            for effect in effects {
                effect.ciContext = context
            }
        }
    }

    weak var drawable: (any NetStreamDrawable)? {
        didSet {
            #if os(iOS) || os(macOS)
            drawable?.videoOrientation = videoOrientation
            #endif
        }
    }

    var formatDescription: CMVideoFormatDescription? {
        didSet {
            codec.formatDescription = formatDescription
        }
    }

    lazy var codec: VideoCodec = {
        var codec = VideoCodec()
        codec.lockQueue = lockQueue
        return codec
    }()

    weak var mixer: IOMixer?

    var muted = false

    private(set) var effects: Set<VideoEffect> = []

    private var extent = CGRect.zero {
        didSet {
            guard extent != oldValue else {
                return
            }
            CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary?, &pixelBufferPool)
            pixelBufferPool?.createPixelBuffer(&pixelBuffer)
        }
    }

    private var attributes: [NSString: NSObject] {
        var attributes: [NSString: NSObject] = Self.defaultAttributes
        attributes[kCVPixelBufferWidthKey] = NSNumber(value: Int(extent.width))
        attributes[kCVPixelBufferHeightKey] = NSNumber(value: Int(extent.height))
        return attributes
    }

    private var pixelBufferPool: CVPixelBufferPool?

    #if os(iOS) || os(macOS)
    var frameRate = IOMixer.defaultFrameRate {
        didSet {
            guard frameRate != oldValue else {
                return
            }
            codec.settings.expectedFrameRate = frameRate
            capture.setFrameRate(frameRate)
            multiCamCapture.setFrameRate(frameRate)
        }
    }

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

    var torch = false {
        didSet {
            guard torch != oldValue else {
                return
            }
            setTorchMode(torch ? .on : .off)
        }
    }

    private(set) var capture: IOVideoCaptureUnit = .init()
    private(set) var multiCamCapture: IOVideoCaptureUnit = .init()
    #endif

    var multiCamCaptureSettings: MultiCamCaptureSettings = .default

    private var pixelBuffer: CVPixelBuffer?
    private var multiCamSampleBuffer: CMSampleBuffer?

    deinit {
        if Thread.isMainThread {
            self.drawable?.attachStream(nil)
        } else {
            DispatchQueue.main.sync {
                self.drawable?.attachStream(nil)
            }
        }
    }

    #if os(iOS) || os(macOS)
    func attachCamera(_ device: AVCaptureDevice?) throws {
        guard let mixer, self.capture.device != device else {
            return
        }
        guard let device else {
            mixer.mediaSync = .passthrough
            mixer.session.beginConfiguration()
            defer {
                mixer.session.commitConfiguration()
            }
            capture.detachSession(mixer.session)
            try capture.attachDevice(nil, videoUnit: self)
            return
        }
        mixer.mediaSync = .video
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
    }

    @available(iOS 13.0, *)
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
            mixer.isMultiCamSessionEnabled = false
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

    @available(iOS, unavailable)
    func attachScreen(_ input: AVCaptureScreenInput?) {
        guard let mixer else {
            return
        }
        mixer.session.beginConfiguration()
        defer {
            mixer.session.commitConfiguration()
        }
        guard let input else {
            mixer.mediaSync = .passthrough
            return
        }
        mixer.mediaSync = .video
        multiCamCapture.attachScreen(input, videoUnit: self)
    }

    func setTorchMode(_ torchMode: AVCaptureDevice.TorchMode) {
        capture.setTorchMode(torchMode)
        multiCamCapture.setTorchMode(torchMode)
    }
    #endif

    @inline(__always)
    func effect(_ buffer: CVImageBuffer, info: CMSampleBuffer?) -> CIImage {
        var image = CIImage(cvPixelBuffer: buffer)
        for effect in effects {
            image = effect.execute(image, info: info)
        }
        return image
    }

    func registerEffect(_ effect: VideoEffect) -> Bool {
        effect.ciContext = context
        return effects.insert(effect).inserted
    }

    func unregisterEffect(_ effect: VideoEffect) -> Bool {
        effect.ciContext = nil
        return effects.remove(effect) != nil
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let buffer = sampleBuffer.imageBuffer else {
            return
        }
        var imageBuffer: CVImageBuffer?
        buffer.lockBaseAddress()
        defer {
            buffer.unlockBaseAddress()
            imageBuffer?.unlockBaseAddress()
        }
        #if os(macOS)
        if capture.isVideoMirrored == true {
            buffer.reflectHorizontal()
        }
        #endif
        if let multiCamPixelBuffer = multiCamSampleBuffer?.imageBuffer {
            multiCamPixelBuffer.lockBaseAddress()
            switch multiCamCaptureSettings.mode {
            case .pip:
                buffer.over(
                    multiCamPixelBuffer,
                    regionOfInterest: multiCamCaptureSettings.regionOfInterest,
                    radius: multiCamCaptureSettings.cornerRadius
                )
            case .splitView:
                buffer.split(multiCamPixelBuffer, direction: multiCamCaptureSettings.direction)
            }
            multiCamPixelBuffer.unlockBaseAddress()
        }
        if drawable != nil || !effects.isEmpty {
            let image = effect(buffer, info: sampleBuffer)
            extent = image.extent
            if !effects.isEmpty {
                #if os(macOS)
                pixelBufferPool?.createPixelBuffer(&imageBuffer)
                #else
                if buffer.width != Int(extent.width) || buffer.height != Int(extent.height) {
                    pixelBufferPool?.createPixelBuffer(&imageBuffer)
                }
                #endif
                imageBuffer?.lockBaseAddress()
                context.render(image, to: imageBuffer ?? buffer)
            }
            drawable?.enqueue(sampleBuffer)
        }
        if muted {
            imageBuffer = pixelBuffer
        }
        codec.appendImageBuffer(
            imageBuffer ?? buffer,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            duration: sampleBuffer.duration
        )
        mixer?.recorder.appendPixelBuffer(
            imageBuffer ?? buffer,
            withPresentationTime: sampleBuffer.presentationTimeStamp
        )
        if !muted {
            pixelBuffer = buffer
        }
    }
}

extension IOVideoUnit: IOUnitEncoding {
    // MARK: IOUnitEncoding
    func startEncoding(_ delegate: any AVCodecDelegate) {
        codec.delegate = delegate
        codec.startRunning()
    }

    func stopEncoding() {
        codec.stopRunning()
        codec.delegate = nil
        pixelBuffer = nil
    }
}

extension IOVideoUnit: IOUnitDecoding {
    // MARK: IOUnitDecoding
    func startDecoding() {
        codec.delegate = self
        codec.startRunning()
    }

    func stopDecoding() {
        codec.stopRunning()
        drawable?.enqueue(nil)
        pixelBuffer = nil
    }
}

#if os(iOS) || os(macOS)
extension IOVideoUnit: AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if capture.output == captureOutput {
            guard mixer?.useSampleBuffer(sampleBuffer: sampleBuffer, mediaType: AVMediaType.video) == true else {
                return
            }
            appendSampleBuffer(sampleBuffer)
        } else if multiCamCapture.output == captureOutput {
            multiCamSampleBuffer = sampleBuffer
        }
    }
}
#endif

extension IOVideoUnit: VideoCodecDelegate {
    // MARK: VideoCodecDelegate
    func videoCodec(_ codec: VideoCodec, didOutput formatDescription: CMFormatDescription?) {
    }

    func videoCodec(_ codec: VideoCodec, didOutput sampleBuffer: CMSampleBuffer) {
        mixer?.mediaLink.enqueueVideo(sampleBuffer)
    }

    func videoCodec(_ codec: VideoCodec, errorOccurred error: VideoCodec.Error) {
        logger.trace(error)
    }

    func videoCodecWillDropFame(_ codec: VideoCodec) -> Bool {
        return false
    }
}
