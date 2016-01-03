import Foundation
import AVFoundation
import VideoToolbox

final class AVCEncoder:NSObject, Encoder, AVCaptureVideoDataOutputSampleBufferDelegate {

    static let dictionaryKeys:[String] = [
        "fps",
        "width",
        "height",
        "bitrate",
        "aspectRatio16by9",
        "keyframeInterval",
    ]

    static func getData(bytes: UnsafeMutablePointer<Int8>, length:Int) -> NSData {
        let mutableData:NSMutableData = NSMutableData()
        mutableData.appendBytes(bytes, length: length)
        return mutableData
    }

    static let defaultFPS:Int = 30
    static let defaultWidth:Int32 = 480
    static let defaultHeight:Int32 = 272

    static let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferIOSurfacePropertiesKey: [:],
        kCVPixelBufferOpenGLESCompatibilityKey: true,
    ]

    var fps:Int = AVCEncoder.defaultFPS
    var width:Int32 = AVCEncoder.defaultWidth
    var height:Int32 = AVCEncoder.defaultHeight
    var bitrate:Int32 = 160 * 1000
    var profile:AVCProfileIndication = .Baseline
    var aspectRatio16by9:Bool = true
    var keyframeInterval:Int = AVCEncoder.defaultFPS * 2

    let lockQueue:dispatch_queue_t = dispatch_queue_create("com.github.shogo4405.lf.AVCEncoder.lock", DISPATCH_QUEUE_SERIAL)
    weak var delegate:VideoEncoderDelegate?

    var formatDescription:CMFormatDescriptionRef? = nil {
        didSet {
            if (!CMFormatDescriptionEqual(formatDescription, oldValue)) {
                delegate?.didSetFormatDescription(video: formatDescription)
            }
        }
    }

    private var status:OSStatus = noErr
    private var attributes:[NSString: AnyObject] {
        var attributes:[NSString: AnyObject] = AVCEncoder.defaultAttributes
        attributes[kCVPixelBufferWidthKey] = NSNumber(int: width)
        attributes[kCVPixelBufferHeightKey] = NSNumber(int: height)
        return attributes
    }

    // @see: https://developer.apple.com/library/mac/releasenotes/General/APIDiffsMacOSX10_8/VideoToolbox.html
    private var properties:[NSString: NSObject] {
        var properties:[NSString: NSObject] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
            kVTCompressionPropertyKey_ProfileLevel: profile.autoLevel,
            kVTCompressionPropertyKey_AverageBitRate: Int(bitrate),
            kVTCompressionPropertyKey_ExpectedFrameRate: fps,
            kVTCompressionPropertyKey_MaxKeyFrameInterval: keyframeInterval,
            kVTCompressionPropertyKey_AllowFrameReordering: profile.allowFrameReordering,
            kVTCompressionPropertyKey_PixelTransferProperties: [
                "ScalingMode": "Trim"
            ]
        ]
        if (aspectRatio16by9) {
            properties[kVTCompressionPropertyKey_AspectRatio16x9] = kCFBooleanTrue
        }
        if (profile != .Baseline) {
            properties[kVTCompressionPropertyKey_H264EntropyMode] = kVTH264EntropyMode_CABAC
        }
        return properties
    }

    private var callback:VTCompressionOutputCallback = {(
        outputCallbackRefCon:UnsafeMutablePointer<Void>,
        sourceFrameRefCon:UnsafeMutablePointer<Void>,
        status:OSStatus,
        infoFlags:VTEncodeInfoFlags,
        sampleBuffer:CMSampleBuffer?) in
        let encoder:AVCEncoder = unsafeBitCast(outputCallbackRefCon, AVCEncoder.self)
        encoder.formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer!)
        encoder.delegate?.sampleOuput(video: sampleBuffer!)
    }

    private var _session:VTCompressionSessionRef? = nil
    private var session:VTCompressionSessionRef! {
        get {
            if (_session == nil)  {
                status = VTCompressionSessionCreate(
                    kCFAllocatorDefault,
                    width,
                    height,
                    kCMVideoCodecType_H264,
                    nil,
                    attributes,
                    nil,
                    callback,
                    unsafeBitCast(self, UnsafeMutablePointer<Void>.self),
                    &_session
                )
                if (status == noErr) {
                    status = VTSessionSetProperties(_session!, properties)
                }
                if (status == noErr) {
                    VTCompressionSessionPrepareToEncodeFrames(_session!)
                }
            }
            return _session!
        }
        set {
            if (_session != nil) {
                VTCompressionSessionInvalidate(_session!)
            }
            _session = newValue
        }
    }

    func encodeImageBuffer(imageBuffer:CVImageBuffer, presentationTimeStamp:CMTime, duration:CMTime) {
        var flags:VTEncodeInfoFlags = VTEncodeInfoFlags()
        VTCompressionSessionEncodeFrame(session, imageBuffer, presentationTimeStamp, duration, nil, nil, &flags)
    }

    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        let image:CVImageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer)!
        encodeImageBuffer(image, presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer), duration: CMSampleBufferGetDuration(sampleBuffer))
    }

    func dispose() {
        dispatch_async(lockQueue) {
            self.session = nil
            self.formatDescription = nil
        }
    }
}
