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

    weak var drawable: NetStreamDrawable? {
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
    var fps: Float64 = IOMixer.defaultFPS {
        didSet {
            guard let device = capture?.device, let data = device.actualFPS(fps) else {
                return
            }
            fps = data.fps
            codec.expectedFrameRate = data.fps
            do {
                try device.lockForConfiguration()
                device.activeVideoMinFrameDuration = data.duration
                device.activeVideoMaxFrameDuration = data.duration
                device.unlockForConfiguration()
            } catch {
                logger.error("while locking device for fps:", error)
            }
        }
    }

    var videoSettings: [NSObject: AnyObject] = IOMixer.defaultVideoSettings {
        didSet {
            capture?.output.videoSettings = videoSettings as? [String: Any]
            multiCamCapture?.output.videoSettings = videoSettings as? [String: Any]
        }
    }

    var isVideoMirrored = false {
        didSet {
            guard isVideoMirrored != oldValue else {
                return
            }
            capture?.output.connections.filter({ $0.isVideoMirroringSupported }).forEach { connection in
                connection.isVideoMirrored = isVideoMirrored
            }
        }
    }

    var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
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
            guard videoOrientation != oldValue else {
                return
            }
            capture?.output.connections.filter({ $0.isVideoOrientationSupported }).forEach { connection in
                connection.videoOrientation = videoOrientation
            }
            multiCamCapture?.output.connections.filter({ $0.isVideoOrientationSupported }).forEach { connection in
                connection.videoOrientation = videoOrientation
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
            } catch {
                logger.error("while locking device for autofocus:", error)
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
            } catch {
                logger.error("while locking device for focusPointOfInterest:", error)
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
            } catch {
                logger.error("while locking device for exposurePointOfInterest:", error)
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
            } catch {
                logger.error("while locking device for autoexpose:", error)
            }
        }
    }

    @available(macOS, unavailable)
    var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode = .off {
        didSet {
            guard preferredVideoStabilizationMode != oldValue else {
                return
            }
            capture?.output.connections.filter({ $0.isVideoStabilizationSupported }).forEach { connection in
                connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
        }
    }

    private(set) var capture: IOVideoCaptureUnit? {
        didSet {
            oldValue?.output.setSampleBufferDelegate(nil, queue: nil)
            oldValue?.detachSession(mixer?.session)
            capture?.attachSession(mixer?.session)
        }
    }

    private(set) var multiCamCapture: IOVideoCaptureUnit? {
        didSet {
            multiCamSampleBuffer = nil
            oldValue?.output.setSampleBufferDelegate(nil, queue: nil)
            oldValue?.detachSession(mixer?.session)
            multiCamCapture?.attachSession(mixer?.session)
        }
    }
    #endif

    var multiCamCaptureSettings: MultiCamCaptureSetting = .default

    private(set) var screen: CaptureSessionConvertible? {
        didSet {
            if let oldValue = oldValue {
                oldValue.delegate = nil
            }
            if let screen = screen {
                screen.delegate = self
            }
        }
    }

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
        #if os(iOS) || os(macOS)
        capture = nil
        multiCamCapture = nil
        #endif
    }

    #if os(iOS) || os(macOS)
    func attachCamera(_ camera: AVCaptureDevice?) throws {
        guard let mixer, capture?.device != camera else {
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
        if camera == multiCamCapture?.device {
            multiCamCapture = nil
        }
        capture = try? IOVideoCaptureUnit(camera, videoSettings: videoSettings)
        capture?.output.connections.forEach { connection in
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = videoOrientation
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isVideoMirrored
            }
            #if os(iOS)
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
            #endif
        }
        capture?.output.setSampleBufferDelegate(self, queue: lockQueue)
        fps *= 1
        drawable?.position = camera.position
    }

    @available(iOS 13.0, *)
    func attachMultiCamera(_ camera: AVCaptureDevice?) throws {
        #if os(iOS)
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            throw Error.multiCamNotSupported
        }
        #endif
        guard let mixer, multiCamCapture?.device != camera else {
            return
        }
        guard let camera else {
            mixer.isMultiCamSessionEnabled = false
            mixer.session.beginConfiguration()
            defer {
                mixer.session.commitConfiguration()
            }
            multiCamCapture = nil
            return
        }
        mixer.isMultiCamSessionEnabled = true
        mixer.session.beginConfiguration()
        defer {
            mixer.session.commitConfiguration()
        }
        if capture?.device == camera {
            capture = nil
        }
        multiCamCapture = try? IOVideoCaptureUnit(camera, videoSettings: videoSettings)
        multiCamCapture?.output.connections.forEach { connection in
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = videoOrientation
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isVideoMirrored
            }
            #if os(iOS)
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
            #endif
        }
        multiCamCapture?.output.setSampleBufferDelegate(self, queue: lockQueue)
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
        } catch {
            logger.error("while setting torch:", error)
        }
    }
    #endif

    #if os(macOS)
    func attachScreen(_ screen: AVCaptureScreenInput?) {
        mixer?.session.beginConfiguration()
        defer {
            mixer?.session.commitConfiguration()
        }
        guard let screen else {
            capture = nil
            return
        }
        capture = IOVideoCaptureUnit(screen, videoSettings: videoSettings)
        capture?.output.setSampleBufferDelegate(self, queue: lockQueue)
    }
    #endif

    func attachScreen(_ screen: CaptureSessionConvertible?, useScreenSize: Bool = true) {
        guard let screen = screen else {
            self.screen?.stopRunning()
            self.screen = nil
            return
        }
        #if os(iOS) || os(macOS)
        capture = nil
        #endif
        if useScreenSize {
            codec.width = screen.attributes["Width"] as! Int32
            codec.height = screen.attributes["Height"] as! Int32
        }
        self.screen = screen
    }

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
        if isVideoMirrored {
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
            case .split(let direction):
                buffer.split(multiCamPixelBuffer, direction: direction.transformDirection)
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
        codec.inputBuffer(
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
        pixelBuffer = nil
    }
}

extension IOVideoUnit: IOUnitDecoding {
    // MARK: IOUnitDecoding
    func startDecoding(_ audioEndinge: AVAudioEngine) {
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
        if capture?.output == captureOutput {
            guard mixer?.useSampleBuffer(sampleBuffer: sampleBuffer, mediaType: AVMediaType.video) == true else {
                return
            }
            appendSampleBuffer(sampleBuffer)
        } else if multiCamCapture?.output == captureOutput {
            multiCamSampleBuffer = sampleBuffer
        }
    }
}
#endif

extension IOVideoUnit: VideoCodecDelegate {
    // MARK: VideoCodecDelegate
    func videoCodec(_ codec: VideoCodec, didSet formatDescription: CMFormatDescription?) {
    }

    func videoCodec(_ codec: VideoCodec, didOutput sampleBuffer: CMSampleBuffer) {
        drawable?.enqueue(sampleBuffer)
    }

    func videoCodec(_ codec: VideoCodec, errorOccurred error: VideoCodec.Error) {
    }
}

extension IOVideoUnit: CaptureSessionDelegate {
    // MARK: CaptureSessionDelegate
    func session(_ session: CaptureSessionConvertible, didSet size: CGSize) {
        lockQueue.async {
            self.codec.width = Int32(size.width)
            self.codec.height = Int32(size.height)
        }
    }

    func session(_ session: CaptureSessionConvertible, didOutput pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        var timingInfo = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        var videoFormatDescription: CMVideoFormatDescription?
        var status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &videoFormatDescription
        )
        guard status == noErr else {
            return
        }
        var sampleBuffer: CMSampleBuffer?
        status = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: videoFormatDescription!,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        guard let sampleBuffer, status == noErr else {
            return
        }
        appendSampleBuffer(sampleBuffer)
    }
}
