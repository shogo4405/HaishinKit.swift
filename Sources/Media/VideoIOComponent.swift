import CoreImage
import Foundation
import AVFoundation

// MARK: -
final class VideoIOComponent: NSObject {

    static func getActualFPS(fps:Float64, device:AVCaptureDevice) -> (fps:Float64, duration:CMTime)? {
        var durations:[CMTime] = []
        var frameRates:[Float64] = []

        for object:AnyObject in device.activeFormat.videoSupportedFrameRateRanges {
            guard let range:AVFrameRateRange = object as? AVFrameRateRange else {
                continue
            }
            if (range.minFrameRate == range.maxFrameRate) {
                durations.append(range.minFrameDuration)
                frameRates.append(range.maxFrameRate)
                continue
            }
            if (range.minFrameRate <= fps && fps <= range.maxFrameRate) {
                return (fps, CMTimeMake(100, Int32(100 * fps)))
            }

            let actualFPS:Float64 = max(range.minFrameRate, min(range.maxFrameRate, fps))
            return (actualFPS, CMTimeMake(100, Int32(100 * actualFPS)))
        }

        var diff:[Float64] = []
        for frameRate in frameRates {
            diff.append(abs(frameRate - fps))
        }
        if let minElement:Float64 = diff.minElement() {
            for i in 0..<diff.count {
                if (diff[i] == minElement) {
                    return (frameRates[i], durations[i])
                }
            }
        }

        return nil
    }

    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.VideoIOComponent.lock", DISPATCH_QUEUE_SERIAL
    )
    let bufferQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.VideoIOComponent.buffer", DISPATCH_QUEUE_SERIAL
    )

    var view:VideoIOView = VideoIOView()
    var encoder:AVCEncoder = AVCEncoder()
    var decoder:AVCDecoder = AVCDecoder()

    var formatDescription:CMVideoFormatDescriptionRef? {
        didSet {
            decoder.formatDescription = formatDescription
        }
    }

    private var buffers:[DecompressionBuffer] = []
    private var effects:[VisualEffect] = []
    private var rendering:Bool = false

    var fps:Float64 = AVMixer.defaultFPS {
        didSet {
            guard let device:AVCaptureDevice = input?.device,
                data = VideoIOComponent.getActualFPS(fps, device: device) else {
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
    var session:AVCaptureSession!

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
            #if os(iOS)
            if let connection:AVCaptureConnection = view.layer.valueForKey("connection") as? AVCaptureConnection {
                if (connection.supportsVideoOrientation) {
                    connection.videoOrientation = orientation
                }
            }
            #endif
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
            guard let device:AVCaptureDevice = input?.device
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
            guard let device:AVCaptureDevice = input?.device
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
                device:AVCaptureDevice = input?.device,
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
                device:AVCaptureDevice = input?.device,
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
            guard let device:AVCaptureDevice = input?.device
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
                session.removeOutput(output)
            }
            _output = newValue
        }
    }

    private(set) var input:AVCaptureDeviceInput? = nil {
        didSet {
            guard oldValue != input else {
                return
            }
            if let oldValue:AVCaptureDeviceInput = oldValue {
                session.removeInput(oldValue)
            }
            if let input:AVCaptureDeviceInput = input {
                session.addInput(input)
            }
        }
    }

    private(set) var screen:ScreenCaptureSession? = nil {
        didSet {
            guard oldValue != screen else {
                return
            }
            if let oldValue:ScreenCaptureSession = oldValue {
                oldValue.delegate = nil
                oldValue.stopRunning()
            }
            if let screen:ScreenCaptureSession = screen {
                screen.delegate = self
                screen.startRunning()
            }
        }
    }

    override init() {
        super.init()
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
        screen = nil
        do {
            input = try AVCaptureDeviceInput(device: camera)
            session.addOutput(output)
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

    func attachScreen(screen:ScreenCaptureSession?) {
        guard let screen:ScreenCaptureSession = screen else {
            return
        }
        input = nil
        encoder.setValuesForKeysWithDictionary([
            "width": screen.attributes["Width"]!,
            "height": screen.attributes["Height"]!,
        ])
        self.screen = screen
    }

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
        effect.context = view.ciContext
        effects.append(effect)
        return true
    }

    func unregisterEffect(effect:VisualEffect) -> Bool {
        objc_sync_enter(effects)
        defer {
            objc_sync_exit(effects)
        }
        if let i:Int = effects.indexOf(effect) {
            effect.context = nil
            effects.removeAtIndex(i)
            return true
        }
        return false
    }

    func enqueSampleBuffer(bytes:[UInt8], inout timing:CMSampleTimingInfo) {
        dispatch_async(lockQueue) {
            var sample:[UInt8] = bytes
            let sampleSize:Int = bytes.count

            var blockBuffer:CMBlockBufferRef?
            guard CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, &sample, sampleSize, kCFAllocatorNull, nil, 0, sampleSize, 0, &blockBuffer) == noErr else {
                return
            }

            var sampleBuffer:CMSampleBufferRef?
            var sampleSizes:[Int] = [sampleSize]
            guard IsNoErr(CMSampleBufferCreate(kCFAllocatorDefault, blockBuffer!, true, nil, nil, self.formatDescription!, 1, 1, &timing, 1, &sampleSizes, &sampleBuffer)) else {
                return
            }

            self.decoder.decodeSampleBuffer(sampleBuffer!)
        }
    }

    func renderIfNeed() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            guard !self.rendering else {
                return
            }
            self.rendering = true
            while (!self.buffers.isEmpty) {
                var buffer:DecompressionBuffer?
                dispatch_sync(self.bufferQueue) {
                    buffer = self.buffers.removeFirst()
                }
                guard let data:DecompressionBuffer = buffer else {
                    return
                }
                self.view.drawImage(CIImage(CVPixelBuffer: data.imageBuffer!))
                usleep(UInt32(data.duration.value) * 1000)
            }
            self.rendering = false
        }
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
        guard var buffer:CVImageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let image:CIImage = effect(buffer)
        if (!effects.isEmpty) {
            #if os(OSX)
            // green edge hack for OSX
            buffer = createPixelBuffer(image, buffer.width, buffer.height)!
            #endif
            view.ciContext.render(image, toCVPixelBuffer: buffer)
        }
        encoder.encodeImageBuffer(
            buffer,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            duration: sampleBuffer.duration
        )
        view.drawImage(image)
    }
}

// MARK: VideoDecoderDelegate
extension VideoIOComponent: VideoDecoderDelegate {
    func imageOutput(buffer:DecompressionBuffer) {
        dispatch_async(bufferQueue) {
            self.buffers.append(buffer)
        }
        renderIfNeed()
    }
}

// MARK: ScreenCaptureOutputPixelBufferDelegate
extension VideoIOComponent: ScreenCaptureOutputPixelBufferDelegate {
    func didSetSize(size: CGSize) {
        dispatch_async(lockQueue) {
            self.encoder.width = Int32(size.width)
            self.encoder.height = Int32(size.height)
        }
    }
    func pixelBufferOutput(pixelBuffer:CVPixelBufferRef, timestamp:CMTime) {
        encoder.encodeImageBuffer(
            pixelBuffer,
            presentationTimeStamp: timestamp,
            duration: timestamp
        )
    }
}
