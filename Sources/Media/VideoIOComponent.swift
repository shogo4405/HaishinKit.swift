import CoreImage
import Foundation
import AVFoundation

final class VideoIOComponent: IOComponent {
    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.VideoIOComponent.lock", DISPATCH_QUEUE_SERIAL
    )
    var encoder:AVCEncoder = AVCEncoder()
    var decoder:AVCDecoder = AVCDecoder()
    var drawable:StreamDrawable?
    var formatDescription:CMVideoFormatDescriptionRef? {
        didSet {
            decoder.formatDescription = formatDescription
        }
    }
    private lazy var queue:DecompressionBufferClockedQueue = {
        let queue:DecompressionBufferClockedQueue = DecompressionBufferClockedQueue()
        queue.delegate = self
        return queue
    }()
    private var effects:[VisualEffect] = []

    var fps:Float64 = AVMixer.defaultFPS {
        didSet {
            guard let device:AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                data = DeviceUtil.getActualFPS(fps, device: device) else {
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

    var videoSettings:[NSObject:AnyObject] = AVMixer.defaultVideoSettings {
        didSet {
            output.videoSettings = videoSettings
        }
    }

    var orientation:AVCaptureVideoOrientation = .Portrait {
        didSet {
            guard orientation != oldValue else {
                return
            }
            drawable?.orientation = orientation
            for connection in output.connections {
                if let connection:AVCaptureConnection = connection as? AVCaptureConnection {
                    if (connection.supportsVideoOrientation) {
                        connection.videoOrientation = orientation
                    }
                }
            }
        }
    }

    #if os(iOS)
    var torch:Bool = false {
        didSet {
            let torchMode:AVCaptureTorchMode = torch ? .On : .Off
            guard let device:AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device
                where device.isTorchModeSupported(torchMode) && device.torchAvailable else {
                logger.warning("torchMode(\(torchMode)) is not supported")
                return
            }
            do {
                try device.lockForConfiguration()
                device.torchMode = torchMode
                device.unlockForConfiguration()
            }
            catch let error as NSError {
                logger.error("while setting torch: \(error)")
            }
        }
    }
    #endif
    
    var continuousAutofocus:Bool = false {
        didSet {
            guard continuousAutofocus != oldValue else {
                return
            }
            let focusMode:AVCaptureFocusMode = continuousAutofocus ? .ContinuousAutoFocus : .AutoFocus
            guard let device:AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device
                where device.isFocusModeSupported(focusMode) else {
                logger.warning("focusMode(\(focusMode.rawValue)) is not supported")
                return
            }
            do {
                try device.lockForConfiguration()
                device.focusMode = focusMode
                device.unlockForConfiguration()
            }
            catch let error as NSError {
                logger.error("while locking device for autofocus: \(error)")
            }
        }
    }

    var focusPointOfInterest:CGPoint? {
        didSet {
            guard let
                device:AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                point:CGPoint = focusPointOfInterest
            where
                device.focusPointOfInterestSupported else {
                return
            }
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = point
                device.focusMode = .AutoFocus
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for focusPointOfInterest: \(error)")
            }
        }
    }

    var exposurePointOfInterest:CGPoint? {
        didSet {
            guard let
                device:AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                point:CGPoint = exposurePointOfInterest
            where
                device.exposurePointOfInterestSupported else {
                return
            }
            do {
                try device.lockForConfiguration()
                device.exposurePointOfInterest = point
                device.exposureMode = .AutoExpose
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for exposurePointOfInterest: \(error)")
            }
        }
    }

    var continuousExposure:Bool = false {
        didSet {
            guard continuousExposure != oldValue else {
                return
            }
            let exposureMode:AVCaptureExposureMode = continuousExposure ? .ContinuousAutoExposure : .AutoExpose
            guard let device:AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device
                where device.isExposureModeSupported(exposureMode) else {
                logger.warning("exposureMode(\(exposureMode.rawValue)) is not supported")
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

    private var _output:AVCaptureVideoDataOutput? = nil
    var output:AVCaptureVideoDataOutput! {
        get {
            if (_output == nil) {
                _output = AVCaptureVideoDataOutput()
                _output!.alwaysDiscardsLateVideoFrames = true
                _output!.videoSettings = videoSettings
            }
            return _output!
        }
        set {
            if (_output == newValue) {
                return
            }
            if let output:AVCaptureVideoDataOutput = _output {
                output.setSampleBufferDelegate(nil, queue: nil)
                mixer.session.removeOutput(output)
            }
            _output = newValue
        }
    }

    private(set) var input:AVCaptureInput? = nil {
        didSet {
            guard oldValue != input else {
                return
            }
            if let oldValue:AVCaptureInput = oldValue {
                mixer.session.removeInput(oldValue)
            }
            if let input:AVCaptureInput = input {
                mixer.session.addInput(input)
            }
        }
    }

    #if !os(OSX)
    private(set) var screen:ScreenCaptureSession? = nil {
        didSet {
            guard oldValue != screen else {
                return
            }
            if let oldValue:ScreenCaptureSession = oldValue {
                oldValue.delegate = nil
            }
            if let screen:ScreenCaptureSession = screen {
                screen.delegate = self
            }
        }
    }
    #endif

    override init(mixer: AVMixer) {
        super.init(mixer: mixer)
        encoder.lockQueue = lockQueue
        decoder.lockQueue = lockQueue
        decoder.delegate = self
    }

    func attachCamera(camera:AVCaptureDevice?) {
        output = nil
        guard let camera:AVCaptureDevice = camera else {
            input = nil
            return
        }
        #if os(iOS)
        screen = nil
        #endif
        do {
            input = try AVCaptureDeviceInput(device: camera)
            mixer.session.addOutput(output)
            for connection in output.connections {
                guard let connection:AVCaptureConnection = connection as? AVCaptureConnection else {
                    continue
                }
                if (connection.supportsVideoOrientation) {
                    connection.videoOrientation = orientation
                }
            }
            output.setSampleBufferDelegate(self, queue: lockQueue)
        } catch let error as NSError {
            logger.error("\(error)")
        }

        fps = fps * 1
        drawable?.position = camera.position

        #if os(iOS)
        do {
            try camera.lockForConfiguration()
            let torchMode:AVCaptureTorchMode = torch ? .On : .Off
            if (camera.isTorchModeSupported(torchMode)) {
                camera.torchMode = torchMode
            }
            camera.unlockForConfiguration()
        } catch let error as NSError {
            logger.error("\(error)")
        }
        #endif
    }

    #if os(OSX)
    func attachScreen(screen:AVCaptureScreenInput?) {
        output = nil
        guard let _:AVCaptureScreenInput = screen else {
            input = nil
            return
        }
        input = screen
        mixer.session.addOutput(output)
        output.setSampleBufferDelegate(self, queue: lockQueue)
        mixer.session.startRunning()
    }
    #else
    func attachScreen(screen:ScreenCaptureSession?, useScreenSize:Bool = true) {
        guard let screen:ScreenCaptureSession = screen else {
            self.screen?.stopRunning()
            self.screen = nil
            return
        }
        input = nil
        output = nil
        if (useScreenSize) {
            encoder.setValuesForKeysWithDictionary([
                "width": screen.attributes["Width"]!,
                "height": screen.attributes["Height"]!,
            ])
        }
        self.screen = screen
    }
    #endif

    func effect(buffer:CVImageBufferRef) -> CIImage {
        var image:CIImage = CIImage(CVPixelBuffer: buffer)
        for effect in effects {
            image = effect.execute(image)
        }
        return image
    }

    func registerEffect(effect:VisualEffect) -> Bool {
        objc_sync_enter(effects)
        defer {
            objc_sync_exit(effects)
        }
        if let _:Int = effects.indexOf(effect) {
            return false
        }
        effects.append(effect)
        return true
    }

    func unregisterEffect(effect:VisualEffect) -> Bool {
        objc_sync_enter(effects)
        defer {
            objc_sync_exit(effects)
        }
        if let i:Int = effects.indexOf(effect) {
            effects.removeAtIndex(i)
            return true
        }
        return false
    }

    func createPixelBuffer(image:CIImage, _ width:Int, _ height:Int) -> CVPixelBuffer? {
        var buffer:CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            nil,
            &buffer
        )
        return buffer
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate
extension VideoIOComponent: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(captureOutput:AVCaptureOutput!, didOutputSampleBuffer sampleBuffer:CMSampleBuffer!, fromConnection connection:AVCaptureConnection!) {
        mixer.recorder.appendSampleBuffer(sampleBuffer, mediaType: AVMediaTypeVideo)
        guard var buffer:CVImageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let image:CIImage = effect(buffer)
        if (!effects.isEmpty) {
            #if os(OSX)
            // green edge hack for OSX
            buffer = createPixelBuffer(image, buffer.width, buffer.height)!
            #endif
            drawable?.render(image, toCVPixelBuffer: buffer)
        }
        encoder.encodeImageBuffer(
            buffer,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            duration: sampleBuffer.duration
        )
        drawable?.drawImage(image)
    }
}

// MARK: VideoDecoderDelegate
extension VideoIOComponent: VideoDecoderDelegate {
    func imageOutput(buffer:DecompressionBuffer) {
        queue.enqueue(buffer)
    }
}

// MARK: ClockedQueueDelegate
extension VideoIOComponent: ClockedQueueDelegate {
    func queue(buffer: Any) {
        guard let buffer:DecompressionBuffer = buffer as? DecompressionBuffer else {
            return
        }
        drawable?.drawImage(CIImage(CVPixelBuffer: buffer.imageBuffer!))
    }
}

#if os(iOS)
// MARK: ScreenCaptureOutputPixelBufferDelegate
extension VideoIOComponent: ScreenCaptureOutputPixelBufferDelegate {
    func didSetSize(size: CGSize) {
        dispatch_async(lockQueue) {
            self.encoder.width = Int32(size.width)
            self.encoder.height = Int32(size.height)
        }
    }
    func pixelBufferOutput(pixelBuffer:CVPixelBufferRef, timestamp:CMTime) {
        if (!effects.isEmpty) {
            drawable?.render(effect(pixelBuffer), toCVPixelBuffer: pixelBuffer)
        }
        encoder.encodeImageBuffer(
            pixelBuffer,
            presentationTimeStamp: timestamp,
            duration: timestamp
        )
    }
}
#endif

