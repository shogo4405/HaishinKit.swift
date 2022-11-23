import AVFoundation
import CoreImage

final class AVVideoIOUnit: NSObject, AVIOUnit {
    static let defaultAttributes: [NSString: NSObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue
    ]

    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.VideoIOComponent.lock")

    var context: CIContext? {
        didSet {
            for effect in effects {
                effect.ciContext = context
            }
        }
    }

    #if os(iOS) || os(macOS)
    weak var drawable: NetStreamDrawable? {
        didSet {
            drawable?.orientation = orientation
        }
    }
    #else
    weak var drawable: NetStreamDrawable?
    #endif

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
    weak var mixer: AVMixer?
    var muted = false

    private(set) var effects: Set<VideoEffect> = []

    private var extent = CGRect.zero {
        didSet {
            guard extent != oldValue else {
                return
            }
            pixelBufferPool = nil
        }
    }

    private var attributes: [NSString: NSObject] {
        var attributes: [NSString: NSObject] = Self.defaultAttributes
        attributes[kCVPixelBufferWidthKey] = NSNumber(value: Int(extent.width))
        attributes[kCVPixelBufferHeightKey] = NSNumber(value: Int(extent.height))
        return attributes
    }

    private var _pixelBufferPool: CVPixelBufferPool?
    private var pixelBufferPool: CVPixelBufferPool! {
        get {
            if _pixelBufferPool == nil {
                var pixelBufferPool: CVPixelBufferPool?
                CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary?, &pixelBufferPool)
                _pixelBufferPool = pixelBufferPool
            }
            return _pixelBufferPool!
        }
        set {
            _pixelBufferPool = newValue
        }
    }

    #if os(iOS) || os(macOS)
    var fps: Float64 = AVMixer.defaultFPS {
        didSet {
            guard let device = capture?.device, let data = device.actualFPS(fps) else {
                return
            }
            fps = data.fps
            codec.expectedFrameRate = data.fps
            logger.info("\(data)")

            do {
                try device.lockForConfiguration()
                device.activeVideoMinFrameDuration = data.duration
                device.activeVideoMaxFrameDuration = data.duration
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for fps: \(error)")
            }
        }
    }

    var position: AVCaptureDevice.Position = .back

    var videoSettings: [NSObject: AnyObject] = AVMixer.defaultVideoSettings {
        didSet {
            capture?.output.videoSettings = videoSettings as? [String: Any]
        }
    }

    var isVideoMirrored = false {
        didSet {
            guard isVideoMirrored != oldValue else {
                return
            }
            capture?.output.connections.forEach { connection in
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = isVideoMirrored
                }
            }
        }
    }

    var orientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            drawable?.orientation = orientation
            guard orientation != oldValue else {
                return
            }
            capture?.output.connections.filter({ $0.isVideoOrientationSupported }).forEach { connection in
                connection.videoOrientation = orientation
                if torch {
                    setTorchMode(.on)
                }
                #if os(iOS)
                connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
                #endif
            }
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

    var continuousAutofocus = false {
        didSet {
            guard continuousAutofocus != oldValue else {
                return
            }
            let focusMode: AVCaptureDevice.FocusMode = continuousAutofocus ? .continuousAutoFocus : .autoFocus
            guard let device = capture?.device, device.isFocusModeSupported(focusMode) else {
                logger.warn("focusMode(\(focusMode.rawValue)) is not supported")
                return
            }
            do {
                try device.lockForConfiguration()
                device.focusMode = focusMode
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for autofocus: \(error)")
            }
        }
    }

    var focusPointOfInterest: CGPoint? {
        didSet {
            guard
                let device = capture?.device,
                let focusPointOfInterest,
                device.isFocusPointOfInterestSupported else {
                return
            }
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = focusPointOfInterest
                device.focusMode = continuousAutofocus ? .continuousAutoFocus : .autoFocus
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for focusPointOfInterest: \(error)")
            }
        }
    }

    var exposurePointOfInterest: CGPoint? {
        didSet {
            guard
                let device = capture?.device,
                let exposurePointOfInterest,
                device.isExposurePointOfInterestSupported else {
                return
            }
            do {
                try device.lockForConfiguration()
                device.exposurePointOfInterest = exposurePointOfInterest
                device.exposureMode = continuousExposure ? .continuousAutoExposure : .autoExpose
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for exposurePointOfInterest: \(error)")
            }
        }
    }

    var continuousExposure = false {
        didSet {
            guard continuousExposure != oldValue else {
                return
            }
            let exposureMode: AVCaptureDevice.ExposureMode = continuousExposure ? .continuousAutoExposure : .autoExpose
            guard let device = capture?.device, device.isExposureModeSupported(exposureMode) else {
                logger.warn("exposureMode(\(exposureMode.rawValue)) is not supported")
                return
            }
            do {
                try device.lockForConfiguration()
                device.exposureMode = exposureMode
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for autoexpose: \(error)")
            }
        }
    }

    #if os(iOS)
    var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode = .off {
        didSet {
            guard preferredVideoStabilizationMode != oldValue else {
                return
            }
            capture?.output.connections.forEach { connection in
                connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
        }
    }
    #endif
    var capture: AVCaptureIOUnit<AVCaptureVideoDataOutput>? {
        didSet {
            oldValue?.output.setSampleBufferDelegate(nil, queue: nil)
            oldValue?.detach(mixer?.session)
        }
    }
    #endif

    #if os(iOS)
    var screen: CaptureSessionConvertible? {
        didSet {
            if let oldValue = oldValue {
                oldValue.delegate = nil
            }
            if let screen = screen {
                screen.delegate = self
            }
        }
    }
    #endif

    private var lastImageBuffer: CVPixelBuffer?

    deinit {
        if Thread.isMainThread {
            self.drawable?.attachStream(nil)
        } else {
            DispatchQueue.main.sync {
                self.drawable?.attachStream(nil)
            }
        }
        #if os(iOS) || os(macOS)
        capture = nil
        #endif
    }

    #if os(iOS) || os(macOS)
    func attachCamera(_ camera: AVCaptureDevice?) throws {
        guard let mixer else {
            return
        }

        mixer.session.beginConfiguration()
        defer {
            mixer.session.commitConfiguration()
            if torch {
                setTorchMode(.on)
            }
        }

        guard let camera else {
            mixer.mediaSync = .passthrough
            capture = nil
            return
        }

        mixer.mediaSync = .video
        #if os(iOS)
        screen = nil
        #endif

        capture = AVCaptureIOUnit(try AVCaptureDeviceInput(device: camera)) {
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = videoSettings as? [String: Any]
            return output
        }
        capture?.attach(mixer.session)
        capture?.output.connections.forEach { connection in
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = orientation
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isVideoMirrored
            }
            #if os(iOS)
            connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            #endif
        }
        capture?.output.setSampleBufferDelegate(self, queue: lockQueue)

        fps *= 1
        position = camera.position
        drawable?.position = camera.position
    }

    func setTorchMode(_ torchMode: AVCaptureDevice.TorchMode) {
        guard let device = capture?.device, device.isTorchModeSupported(torchMode) else {
            logger.warn("torchMode(\(torchMode)) is not supported")
            return
        }
        do {
            try device.lockForConfiguration()
            device.torchMode = torchMode
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.error("while setting torch: \(error)")
        }
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

        if drawable != nil || !effects.isEmpty {
            let image = effect(buffer, info: sampleBuffer)
            extent = image.extent
            if !effects.isEmpty {
                #if os(macOS)
                pixelBufferPool.createPixelBuffer(&imageBuffer)
                #else
                if buffer.width != Int(extent.width) || buffer.height != Int(extent.height) {
                    pixelBufferPool.createPixelBuffer(&imageBuffer)
                }
                #endif
                imageBuffer?.lockBaseAddress()
                context?.render(image, to: imageBuffer ?? buffer)
            }
            drawable?.enqueue(sampleBuffer)
        }

        if muted {
            if lastImageBuffer == nil {
                pixelBufferPool.createPixelBuffer(&lastImageBuffer)
            }
            imageBuffer = lastImageBuffer
        }

        codec.inputBuffer(
            imageBuffer ?? buffer,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            duration: sampleBuffer.duration
        )

        mixer?.recorder.appendPixelBuffer(
            imageBuffer ?? buffer,
            withPresentationTime: sampleBuffer.presentationTimeStamp
        )

        if !self.muted {
            self.lastImageBuffer = buffer
        }
    }
}

extension AVVideoIOUnit: AVIOUnitEncoding {
    // MARK: AVIOUnitEncoding
    func startEncoding(_ delegate: AVCodecDelegate) {
        #if os(iOS)
        screen?.startRunning()
        #endif
        codec.delegate = delegate
        codec.startRunning()
    }

    func stopEncoding() {
        #if os(iOS)
        screen?.stopRunning()
        #endif
        codec.stopRunning()
        codec.delegate = nil
        lastImageBuffer = nil
    }
}

extension AVVideoIOUnit: AVIOUnitDecoding {
    // MARK: AVIOUnitDecoding
    func startDecoding(_ audioEndinge: AVAudioEngine) {
        codec.delegate = self
        codec.startRunning()
    }

    func stopDecoding() {
        codec.stopRunning()
        drawable?.enqueue(nil)
        lastImageBuffer = nil
    }
}

#if os(iOS) || os(macOS)
extension AVVideoIOUnit: AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard mixer?.useSampleBuffer(sampleBuffer: sampleBuffer, mediaType: AVMediaType.video) == true else {
            return
        }
        #if os(macOS)
        if connection.isVideoMirrored {
            sampleBuffer.reflectHorizontal()
        }
        #endif
        appendSampleBuffer(sampleBuffer)
    }
}
#endif

extension AVVideoIOUnit: VideoCodecDelegate {
    // MARK: VideoCodecDelegate
    func videoCodec(_ codec: VideoCodec, didSet formatDescription: CMFormatDescription?) {
    }

    func videoCodec(_ codec: VideoCodec, didOutput sampleBuffer: CMSampleBuffer) {
        drawable?.enqueue(sampleBuffer)
    }

    func videoCodec(_ codec: VideoCodec, errorOccurred error: VideoCodec.Error) {
    }
}
