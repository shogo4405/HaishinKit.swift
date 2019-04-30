import AVFoundation

final class VideoIOComponent: IOComponent {
    #if os(macOS)
    static let defaultAttributes: [NSString: NSObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
        kCVPixelBufferOpenGLCompatibilityKey: kCFBooleanTrue
    ]
    #else
    static let defaultAttributes: [NSString: NSObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
        kCVPixelBufferOpenGLESCompatibilityKey: kCFBooleanTrue
    ]
    #endif

    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.VideoIOComponent.lock")

    var context: CIContext? {
        didSet {
            for effect in effects {
                effect.ciContext = context
            }
        }
    }

    #if os(iOS) || os(macOS)
    var drawable: NetStreamDrawable? = nil {
        didSet {
            drawable?.orientation = orientation
        }
    }
    #else
    var drawable: NetStreamDrawable?
    #endif

    var formatDescription: CMVideoFormatDescription? {
        didSet {
            decoder.formatDescription = formatDescription
        }
    }
    lazy var encoder = H264Encoder()
    lazy var decoder = H264Decoder()
    lazy var queue: DisplayLinkedQueue = {
        let queue = DisplayLinkedQueue()
        queue.delegate = self
        return queue
    }()

    private(set) var effects: Set<VisualEffect> = []

    private var extent = CGRect.zero {
        didSet {
            guard extent != oldValue else {
                return
            }
            pixelBufferPool = nil
        }
    }

    private var attributes: [NSString: NSObject] {
        var attributes: [NSString: NSObject] = VideoIOComponent.defaultAttributes
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
            guard
                let device: AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                let data = device.actualFPS(fps) else {
                    return
            }

            fps = data.fps
            encoder.expectedFPS = data.fps
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
            output.videoSettings = videoSettings as? [String: Any]
        }
    }

    var orientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            drawable?.orientation = orientation
            guard orientation != oldValue else {
                return
            }
            for connection in output.connections where connection.isVideoOrientationSupported {
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

    var torch: Bool = false {
        didSet {
            guard torch != oldValue else {
                return
            }
            setTorchMode(torch ? .on : .off)
        }
    }

    var continuousAutofocus: Bool = false {
        didSet {
            guard continuousAutofocus != oldValue else {
                return
            }
            let focusMode: AVCaptureDevice.FocusMode = continuousAutofocus ? .continuousAutoFocus : .autoFocus
            guard let device: AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                device.isFocusModeSupported(focusMode) else {
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
                let device: AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                let point: CGPoint = focusPointOfInterest,
                device.isFocusPointOfInterestSupported else {
                    return
            }
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = point
                device.focusMode = .continuousAutoFocus
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for focusPointOfInterest: \(error)")
            }
        }
    }

    var exposurePointOfInterest: CGPoint? {
        didSet {
            guard
                let device: AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                let point: CGPoint = exposurePointOfInterest,
                device.isExposurePointOfInterestSupported else {
                    return
            }
            do {
                try device.lockForConfiguration()
                device.exposurePointOfInterest = point
                device.exposureMode = .continuousAutoExposure
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for exposurePointOfInterest: \(error)")
            }
        }
    }

    var continuousExposure: Bool = false {
        didSet {
            guard continuousExposure != oldValue else {
                return
            }
            let exposureMode: AVCaptureDevice.ExposureMode = continuousExposure ? .continuousAutoExposure : .autoExpose
            guard let device: AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                device.isExposureModeSupported(exposureMode) else {
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
    var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode = .auto {
        didSet {
            guard preferredVideoStabilizationMode != oldValue else {
                return
            }
            for connection in output.connections {
                connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
        }
    }
    #endif

    private var _output: AVCaptureVideoDataOutput?
    var output: AVCaptureVideoDataOutput! {
        get {
            if _output == nil {
                _output = AVCaptureVideoDataOutput()
                _output?.alwaysDiscardsLateVideoFrames = true
                _output?.videoSettings = videoSettings as? [String: Any]
            }
            return _output!
        }
        set {
            if _output == newValue {
                return
            }
            if let output: AVCaptureVideoDataOutput = _output {
                output.setSampleBufferDelegate(nil, queue: nil)
                mixer?.session.removeOutput(output)
            }
            _output = newValue
        }
    }

    var input: AVCaptureInput? = nil {
        didSet {
            guard let mixer: AVMixer = mixer, oldValue != input else {
                return
            }
            if let oldValue: AVCaptureInput = oldValue {
                mixer.session.removeInput(oldValue)
            }
            if let input: AVCaptureInput = input, mixer.session.canAddInput(input) {
                mixer.session.addInput(input)
            }
        }
    }
    #endif

    #if os(iOS)
    var screen: ScreenCaptureSession? = nil {
        didSet {
            guard oldValue != screen else {
                return
            }
            if let oldValue: ScreenCaptureSession = oldValue {
                oldValue.delegate = nil
            }
            if let screen: ScreenCaptureSession = screen {
                screen.delegate = self
            }
        }
    }
    #endif

    override init(mixer: AVMixer) {
        super.init(mixer: mixer)
        encoder.lockQueue = lockQueue
        decoder.delegate = self
        #if os(iOS)
        if let orientation: AVCaptureVideoOrientation = DeviceUtil.videoOrientation(by: UIDevice.current.orientation) {
            self.orientation = orientation
        } else if let defaultOrientation = RTMPStream.defaultOrientation {
            self.orientation = defaultOrientation
        }
        #endif
    }

    #if os(iOS) || os(macOS)
    func attachCamera(_ camera: AVCaptureDevice?) throws {
        guard let mixer: AVMixer = mixer else {
            return
        }

        mixer.session.beginConfiguration()
        defer {
            mixer.session.commitConfiguration()
            if torch {
                setTorchMode(.on)
            }
        }

        output = nil
        guard let camera: AVCaptureDevice = camera else {
            input = nil
            return
        }
        #if os(iOS)
        screen = nil
        #endif

        input = try AVCaptureDeviceInput(device: camera)
        mixer.session.addOutput(output)

        for connection in output.connections {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = orientation
            }
            #if os(iOS)
            connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            #endif
        }

        output.setSampleBufferDelegate(self, queue: lockQueue)

        fps *= 1
        position = camera.position
        drawable?.position = camera.position
    }

    func setTorchMode(_ torchMode: AVCaptureDevice.TorchMode) {
        guard let device: AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device, device.isTorchModeSupported(torchMode) else {
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

    func dispose() {
        if Thread.isMainThread {
            self.drawable?.attachStream(nil)
        } else {
            DispatchQueue.main.sync {
                self.drawable?.attachStream(nil)
            }
        }

        input = nil
        output = nil
    }
    #else
    func dispose() {
        if Thread.isMainThread {
            self.drawable?.attachStream(nil)
        } else {
            DispatchQueue.main.sync {
                self.drawable?.attachStream(nil)
            }
        }
    }
    #endif

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let buffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        var imageBuffer: CVImageBuffer?

        CVPixelBufferLockBaseAddress(buffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            if let imageBuffer = imageBuffer {
                CVPixelBufferUnlockBaseAddress(imageBuffer, [])
            }
        }

        if drawable != nil || !effects.isEmpty {
            let image: CIImage = effect(buffer, info: sampleBuffer)
            extent = image.extent
            if !effects.isEmpty {
                #if os(macOS)
                CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &imageBuffer)
                #else
                if buffer.width != Int(extent.width) || buffer.height != Int(extent.height) {
                    CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &imageBuffer)
                }
                #endif
                if let imageBuffer = imageBuffer {
                    CVPixelBufferLockBaseAddress(imageBuffer, [])
                }
                context?.render(image, to: imageBuffer ?? buffer)
            }
            drawable?.draw(image: image)
        }

        encoder.encodeImageBuffer(
            imageBuffer ?? buffer,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            duration: sampleBuffer.duration
        )

        mixer?.recorder.appendPixelBuffer(imageBuffer ?? buffer, withPresentationTime: sampleBuffer.presentationTimeStamp)
    }

    @inline(__always)
    func effect(_ buffer: CVImageBuffer, info: CMSampleBuffer?) -> CIImage {
        var image = CIImage(cvPixelBuffer: buffer)
        for effect in effects {
            image = effect.execute(image, info: info)
        }
        return image
    }

    func registerEffect(_ effect: VisualEffect) -> Bool {
        effect.ciContext = context
        return effects.insert(effect).inserted
    }

    func unregisterEffect(_ effect: VisualEffect) -> Bool {
        effect.ciContext = nil
        return effects.remove(effect) != nil
    }
}

extension VideoIOComponent: AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        appendSampleBuffer(sampleBuffer)
    }
}

extension VideoIOComponent: VideoDecoderDelegate {
    // MARK: VideoDecoderDelegate
    func sampleOutput(video sampleBuffer: CMSampleBuffer) {
        queue.enqueue(sampleBuffer)
    }
}

extension VideoIOComponent: DisplayLinkedQueueDelegate {
    // MARK: DisplayLinkedQueue
    func queue(_ buffer: CMSampleBuffer) {
        drawable?.draw(image: CIImage(cvPixelBuffer: buffer.imageBuffer!))
    }
}
