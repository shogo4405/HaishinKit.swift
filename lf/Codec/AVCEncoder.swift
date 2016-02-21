import Foundation
import AVFoundation
import VideoToolbox
import CoreFoundation

final class AVCEncoder: NSObject {

    static let supportedSettingsKeys:[String] = [
        "fps",
        "width",
        "height",
        "bitrate",
        "profileLevel",
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
    static let defaultBitrate:UInt32 = 160 * 1024

    static let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferIOSurfacePropertiesKey: [:],
        kCVPixelBufferOpenGLESCompatibilityKey: true,
    ]

    var fps:Int = AVCEncoder.defaultFPS
    var width:Int32 = AVCEncoder.defaultWidth {
        didSet {
            invalidateSession = true
        }
    }
    var height:Int32 = AVCEncoder.defaultHeight {
        didSet {
            invalidateSession = true
        }
    }
    var bitrate:UInt32 = AVCEncoder.defaultBitrate {
        didSet {
            dispatch_async(lockQueue) {
                guard let session:VTCompressionSessionRef = self._session else {
                    return
                }
                let number:CFNumberRef = CFNumberCreate(nil, .SInt32Type, &self.bitrate)
                let status:OSStatus = VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, number)
                if (status != noErr) {
                    print("error setting video bitrate")
                }
            }
        }
    }
    var profileLevel:String = kVTProfileLevel_H264_Baseline_3_0 as String {
        didSet {
            invalidateSession = true
        }
    }
    
    var aspectRatio16by9:Bool = true
    var keyframeInterval:Int = 2

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
    private var invalidateSession:Bool = true

    // @see: https://developer.apple.com/library/mac/releasenotes/General/APIDiffsMacOSX10_8/VideoToolbox.html
    private var properties:[NSString: NSObject] {
        var properties:[NSString: NSObject] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
            kVTCompressionPropertyKey_ProfileLevel: profileLevel,
            kVTCompressionPropertyKey_AverageBitRate: Int(bitrate),
            kVTCompressionPropertyKey_ExpectedFrameRate: fps,
            kVTCompressionPropertyKey_MaxKeyFrameInterval: fps * keyframeInterval,
            kVTCompressionPropertyKey_AllowFrameReordering: false,
            kVTCompressionPropertyKey_PixelTransferProperties: [
                "ScalingMode": "Trim"
            ]
        ]
        if (aspectRatio16by9) {
            properties[kVTCompressionPropertyKey_AspectRatio16x9] = kCFBooleanTrue
        }
        return properties
    }

    private var callback:VTCompressionOutputCallback = {(
        outputCallbackRefCon:UnsafeMutablePointer<Void>,
        sourceFrameRefCon:UnsafeMutablePointer<Void>,
        status:OSStatus,
        infoFlags:VTEncodeInfoFlags,
        sampleBuffer:CMSampleBuffer?) in
        guard status == noErr else {
            print(status)
            return
        }
        let encoder:AVCEncoder = unsafeBitCast(outputCallbackRefCon, AVCEncoder.self)
        encoder.formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer!)
        encoder.delegate?.sampleOuput(video: sampleBuffer!)
    }

    private var _session:VTCompressionSessionRef? = nil
    private var session:VTCompressionSessionRef? {
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
                guard status == noErr else {
                    print("VTCompressionSessionCreate error \(status)")
                    return nil
                }
                invalidateSession = false
                status = VTSessionSetProperties(_session!, properties)
                VTCompressionSessionPrepareToEncodeFrames(_session!)
            }
            return _session
        }
        set {
            if let session:VTCompressionSessionRef = _session {
                VTCompressionSessionInvalidate(session)
            }
            _session = newValue
        }
    }

    func encodeImageBuffer(imageBuffer:CVImageBuffer, presentationTimeStamp:CMTime, duration:CMTime) {
        if (invalidateSession) {
            session = nil
        }
        guard let session:VTCompressionSessionRef = session else {
            return
        }
        var flags:VTEncodeInfoFlags = VTEncodeInfoFlags()
        VTCompressionSessionEncodeFrame(session, imageBuffer, presentationTimeStamp, duration, nil, nil, &flags)
    }
}

// MARK: - Encoder
extension AVCEncoder: Encoder {
    func dispose() {
        dispatch_async(lockQueue) {
            self.session = nil
            self.formatDescription = nil
        }
    }
}

//MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension AVCEncoder: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        guard let image:CVImageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        encodeImageBuffer(image, presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer), duration: CMSampleBufferGetDuration(sampleBuffer))
    }
}
