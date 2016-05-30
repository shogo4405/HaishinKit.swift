import Foundation
import AVFoundation
import VideoToolbox
import CoreFoundation

final class AVCEncoder: NSObject {

    static let supportedSettingsKeys:[String] = [
        "width",
        "height",
        "bitrate",
        "profileLevel",
        "maxKeyFrameIntervalDuration",
    ]

    static let defaultWidth:Int32 = 480
    static let defaultHeight:Int32 = 272
    static let defaultBitrate:UInt32 = 160 * 1024
    static let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferIOSurfacePropertiesKey: [:],
        kCVPixelBufferOpenGLESCompatibilityKey: true,
    ]

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
                IsNoErr(VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, number), "setting video bitrate \(number)")
            }
        }
    }
    var lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.AVCEncoder.lock", DISPATCH_QUEUE_SERIAL
    )
    var expectedFPS:Float64 = AVMixer.defaultFPS {
        didSet {
            dispatch_async(lockQueue) {
                guard let session:VTCompressionSessionRef = self._session else {
                    return
                }
                let properties:[NSString: NSObject] = [
                    kVTCompressionPropertyKey_MaxKeyFrameInterval: NSNumber(double: self.expectedFPS),
                ]
                VTSessionSetProperties(session, properties)
            }
        }
    }
    var profileLevel:String = kVTProfileLevel_H264_Baseline_3_1 as String {
        didSet {
            invalidateSession = true
        }
    }
    var maxKeyFrameIntervalDuration:Double = 2.0 {
        didSet {
            dispatch_async(lockQueue) {
                guard let session:VTCompressionSessionRef = self._session else {
                    return
                }
                let properties:[NSString: NSObject] = [
                    kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: NSNumber(double: self.maxKeyFrameIntervalDuration),
                ]
                VTSessionSetProperties(session, properties)
            }
        }
    }
    var formatDescription:CMFormatDescriptionRef? = nil {
        didSet {
            guard !CMFormatDescriptionEqual(formatDescription, oldValue) else {
                return
            }
            delegate?.didSetFormatDescription(video: formatDescription)
        }
    }
    weak var delegate:VideoEncoderDelegate?
    internal(set) var running:Bool = false

    private var attributes:[NSString: AnyObject] {
        var attributes:[NSString: AnyObject] = AVCEncoder.defaultAttributes
        attributes[kCVPixelBufferWidthKey] = NSNumber(int: width)
        attributes[kCVPixelBufferHeightKey] = NSNumber(int: height)
        return attributes
    }
    private var invalidateSession:Bool = true

    // @see: https://developer.apple.com/library/mac/releasenotes/General/APIDiffsMacOSX10_8/VideoToolbox.html
    private var properties:[NSString: NSObject] {
        let isBaseline:Bool = profileLevel.containsString("Baseline")
        var properties:[NSString: NSObject] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
            kVTCompressionPropertyKey_ProfileLevel: profileLevel,
            kVTCompressionPropertyKey_AverageBitRate: Int(bitrate),
            kVTCompressionPropertyKey_ExpectedFrameRate: NSNumber(double: expectedFPS),
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: NSNumber(double: maxKeyFrameIntervalDuration),
            kVTCompressionPropertyKey_AllowFrameReordering: !isBaseline,
            kVTCompressionPropertyKey_PixelTransferProperties: [
                "ScalingMode": "Trim"
            ]
        ]
        if (!isBaseline) {
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
        guard let sampleBuffer:CMSampleBuffer = sampleBuffer where status == noErr else {
            logger.error("status = \(status)")
            return
        }
        let encoder:AVCEncoder = unsafeBitCast(outputCallbackRefCon, AVCEncoder.self)
        encoder.formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        encoder.delegate?.sampleOutput(video: sampleBuffer)
    }

    private var _session:VTCompressionSessionRef? = nil
    private var session:VTCompressionSessionRef? {
        get {
            if (_session == nil)  {
                guard IsNoErr(VTCompressionSessionCreate(
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
                ), "VTCompressionSessionCreate") else {
                    return nil
                }
                invalidateSession = false
                IsNoErr(VTSessionSetProperties(_session!, properties))
                IsNoErr(VTCompressionSessionPrepareToEncodeFrames(_session!))
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

    func encodeImageBuffer(imageBuffer:CVImageBuffer, presentationTimeStamp:CMTime, presentationDuration:CMTime) {
        guard running else {
            return
        }
        if (invalidateSession) {
            session = nil
        }
        guard let session:VTCompressionSessionRef = session else {
            return
        }
        var flags:VTEncodeInfoFlags = VTEncodeInfoFlags()
        VTCompressionSessionEncodeFrame(session, imageBuffer, presentationTimeStamp, presentationDuration, nil, nil, &flags)
    }
}

// MARK: Encoder
extension AVCEncoder: Encoder {
    func startRunning() {
        dispatch_async(lockQueue) {
            self.running = true
        }
    }
    func stopRunning() {
        dispatch_async(lockQueue) {
            self.session = nil
            self.formatDescription = nil
            self.running = false
        }
    }
}
