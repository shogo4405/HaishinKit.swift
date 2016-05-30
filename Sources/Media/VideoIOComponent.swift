#if os(iOS)
import UIKit
#else
import AppKit
#endif

import CoreImage
import Foundation
import AVFoundation

struct VideoIOData {
    var image:CGImageRef
    var presentationTimeStamp:CMTime
    var presentationDuration:CMTime
}

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

    private var context:CIContext = {
        if let context:CIContext = CIContext(options: [kCIContextUseSoftwareRenderer: NSNumber(bool: false)]) {
            logger.debug("cicontext use hardware renderer")
            return context
        }
        logger.debug("cicontext use software renderer")
        return CIContext()
    }()
    private var buffers:[VideoIOData] = []
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
    
    var continuousAutofocus:Bool = true {
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

    var continuousExposure:Bool = true {
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
            switch camera.position {
            case .Front:
                view.transform3D = CATransform3DMakeRotation(CGFloat(M_PI), 0, 1, 0)
            case .Back:
                view.transform3D = CATransform3DMakeRotation(0, 0, 1, 0)
            default:
                break
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

    func effect(buffer:CVImageBufferRef) -> CVImageBufferRef {
        CVPixelBufferLockBaseAddress(buffer, 0)
        let width:Int = CVPixelBufferGetWidth(buffer)
        let height:Int = CVPixelBufferGetHeight(buffer)
        var image:CIImage = CIImage(CVPixelBuffer: buffer)
        autoreleasepool {
            for effect in effects {
                image = effect.execute(image)
            }
            let contents:CGImageRef = context.createCGImage(image, fromRect: image.extent)
            dispatch_async(dispatch_get_main_queue()) {
                self.view.contents = contents
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, 0)
        return createImageBuffer(image, width, height)!
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

    func createImageBuffer(image:CIImage, _ width:Int, _ height:Int) -> CVImageBufferRef? {
        var buffer:CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
        CVPixelBufferLockBaseAddress(buffer!, 0)
        context.render(image, toCVPixelBuffer: buffer!)
        CVPixelBufferUnlockBaseAddress(buffer!, 0)
        return buffer
    }

    func renderIfNeed() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            guard !self.rendering else {
                return
            }
            self.rendering = true
            while (!self.buffers.isEmpty) {
                var buffer:VideoIOData?
                dispatch_sync(self.bufferQueue) {
                    buffer = self.buffers.removeFirst()
                }
                guard let data:VideoIOData = buffer else {
                    return
                }
                dispatch_async(dispatch_get_main_queue()) {
                    self.view.contents = data.image
                }
                usleep(UInt32(data.presentationDuration.value) * 1000)
            }
            self.rendering = false
        }
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate
extension VideoIOComponent: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(captureOutput:AVCaptureOutput!, didOutputSampleBuffer sampleBuffer:CMSampleBuffer!, fromConnection connection:AVCaptureConnection!) {
        guard let image:CVImageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        encoder.encodeImageBuffer(
            effects.isEmpty ? image : effect(image),
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            presentationDuration: CMSampleBufferGetDuration(sampleBuffer)
        )
        if (effects.isEmpty && view.contents != nil) {
            dispatch_async(dispatch_get_main_queue()) {
                self.view.contents = nil
            }
        }
    }
}

// MARK: VideoDecoderDelegate
extension VideoIOComponent: VideoDecoderDelegate {
    func imageOutput(imageBuffer:CVImageBuffer!, presentationTimeStamp:CMTime, presentationDuration:CMTime) {
        let image:CIImage = CIImage(CVPixelBuffer: imageBuffer)
        let content:CGImageRef = context.createCGImage(image, fromRect: image.extent)
        dispatch_async(bufferQueue) {
            self.buffers.append(VideoIOData(
                image: content,
                presentationTimeStamp: presentationTimeStamp,
                presentationDuration: presentationDuration
            ))
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
            presentationDuration: timestamp
        )
    }
}

// MARK: -
final class VideoIOLayer: AVCaptureVideoPreviewLayer {
    private var surface:CALayer = CALayer()

    override var frame:CGRect {
        get { return super.frame }
        set {
            super.frame = newValue
            surface.frame = newValue
        }
    }

    override var contents:AnyObject? {
        get { return surface.contents }
        set { surface.contents = newValue }
    }

    override var transform:CATransform3D {
        get { return surface.transform }
        set { surface.transform = newValue }
    }

    override var videoGravity:String! {
        get {
            return super.videoGravity
        }
        set {
            super.videoGravity = newValue
            switch newValue {
            case AVLayerVideoGravityResizeAspect:
                surface.contentsGravity = kCAGravityResizeAspect
            case AVLayerVideoGravityResizeAspectFill:
                surface.contentsGravity = kCAGravityResizeAspectFill
            case AVLayerVideoGravityResize:
                surface.contentsGravity = kCAGravityResize
            default:
                surface.contentsGravity = kCAGravityResizeAspect
            }
        }
    }

    override init() {
        super.init()
        initialize()
    }

    override init!(session: AVCaptureSession!) {
        super.init(session: session)
        initialize()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }

    private func initialize() {
        addSublayer(surface)
    }
}

#if os(iOS)
// MARK: -
public class VideoIOView: UIView {
    static public var defaultBackgroundColor:UIColor = UIColor.blackColor()

    override public class func layerClass() -> AnyClass {
        return VideoIOLayer.self
    }

    public var videoGravity:String! = AVLayerVideoGravityResizeAspectFill {
        didSet {
            layer.setValue(videoGravity, forKey: "videoGravity")
        }
    }

    var contents:AnyObject? {
        get { return layer.contents }
        set { layer.contents = newValue }
    }

    var transform3D:CATransform3D {
        get { return layer.transform }
        set { layer.transform = newValue }
    }

    required override public init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }

    private func initialize() {
        backgroundColor = VideoIOView.defaultBackgroundColor
        layer.frame = bounds
        layer.setValue(videoGravity, forKey: "videoGravity")
    }
}
#else
// MARK: -
public class VideoIOView: NSView {
    public var videoGravity:String! = AVLayerVideoGravityResizeAspectFill {
        didSet {
            layer?.setValue(videoGravity, forKey: "videoGravity")
        }
    }

    var contents:AnyObject? {
        get { return layer?.contents }
        set { layer?.contents = newValue }
    }

    var transform3D:CATransform3D {
        get { return layer!.transform }
        set { layer?.transform = newValue }
    }

    required override public init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }

    private func initialize() {
        layer = VideoIOLayer()
        layer?.frame = bounds
        layer?.setValue(videoGravity, forKey: "videoGravity")
    }
}
#endif
