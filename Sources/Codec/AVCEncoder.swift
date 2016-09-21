import Foundation
import AVFoundation
import VideoToolbox
import CoreFoundation

protocol VideoEncoderDelegate: class {
    func didSetFormatDescription(video formatDescription:CMFormatDescription?)
    func sampleOutput(video sampleBuffer: CMSampleBuffer)
}

// MARK: -
final class AVCEncoder: NSObject {

    static let supportedSettingsKeys:[String] = [
        "width",
        "height",
        "bitrate",
        "profileLevel",
        "dataRateLimits",
        "enabledHardwareEncoder", // macOS only
        "maxKeyFrameIntervalDuration",
    ]

    static let defaultWidth:Int32 = 480
    static let defaultHeight:Int32 = 272
    static let defaultBitrate:UInt32 = 160 * 1024

    #if os(iOS)
    static let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject,
        kCVPixelBufferOpenGLESCompatibilityKey: true as AnyObject,
    ]
    #else
    static let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject,
        kCVPixelBufferOpenGLCompatibilityKey: true as AnyObject,
    ]
    #endif
    static let defaultDataRateLimits:[Int] = [0, 0]

    var width:Int32 = AVCEncoder.defaultWidth {
        didSet {
            guard width != oldValue else {
                return
            }
            invalidateSession = true
        }
    }
    var height:Int32 = AVCEncoder.defaultHeight {
        didSet {
            guard height != oldValue else {
                return
            }
            invalidateSession = true
        }
    }
    var enabledHardwareEncoder:Bool = true {
        didSet {
            guard enabledHardwareEncoder != oldValue else {
                return
            }
            invalidateSession = true
        }
    }
    var bitrate:UInt32 = AVCEncoder.defaultBitrate {
        didSet {
            guard bitrate != oldValue else {
                return
            }
            lockQueue.async {
                guard let session:VTCompressionSession = self._session else {
                    return
                }
                self.status = VTSessionSetProperty(
                    session,
                    kVTCompressionPropertyKey_AverageBitRate,
                    Int(self.bitrate) as CFTypeRef
                )
            }
        }
    }
    var lockQueue:DispatchQueue = DispatchQueue(
        label: "com.github.shogo4405.lf.AVCEncoder.lock", attributes: []
    )
    var expectedFPS:Float64 = AVMixer.defaultFPS {
        didSet {
            guard expectedFPS != oldValue else {
                return
            }
            lockQueue.async {
                guard let session:VTCompressionSession = self._session else {
                    return
                }
                self.status = VTSessionSetProperty(
                    session,
                    kVTCompressionPropertyKey_ExpectedFrameRate,
                    NSNumber(value: self.expectedFPS)
                )
            }
        }
    }
    var dataRateLimits:[Int] = AVCEncoder.defaultDataRateLimits {
        didSet {
            guard dataRateLimits != oldValue else {
                return
            }
            if (dataRateLimits == AVCEncoder.defaultDataRateLimits) {
                invalidateSession = true
                return
            }
            lockQueue.async {
                guard let session:VTCompressionSession = self._session else {
                    return
                }
                self.status = VTSessionSetProperty(
                    session,
                    kVTCompressionPropertyKey_DataRateLimits,
                    self.dataRateLimits as CFTypeRef
                )
            }
        }
    }
    var profileLevel:String = kVTProfileLevel_H264_Baseline_3_1 as String {
        didSet {
            guard profileLevel != oldValue else {
                return
            }
            invalidateSession = true
        }
    }
    var maxKeyFrameIntervalDuration:Double = 2.0 {
        didSet {
            guard maxKeyFrameIntervalDuration != oldValue else {
                return
            }
            lockQueue.async {
                guard let session:VTCompressionSession = self._session else {
                    return
                }
                self.status = VTSessionSetProperty(
                    session,
                    kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,
                    NSNumber(value: self.maxKeyFrameIntervalDuration)
                )
            }
        }
    }
    var formatDescription:CMFormatDescription? = nil {
        didSet {
            guard !CMFormatDescriptionEqual(formatDescription, oldValue) else {
                return
            }
            delegate?.didSetFormatDescription(video: formatDescription)
        }
    }
    weak var delegate:VideoEncoderDelegate?
    internal(set) var running:Bool = false
    fileprivate(set) var status:OSStatus = noErr
    fileprivate var attributes:[NSString: AnyObject] {
        var attributes:[NSString: AnyObject] = AVCEncoder.defaultAttributes
        attributes[kCVPixelBufferWidthKey] = NSNumber(value: width)
        attributes[kCVPixelBufferHeightKey] = NSNumber(value: height)
        return attributes
    }
    fileprivate var invalidateSession:Bool = true

    // @see: https://developer.apple.com/library/mac/releasenotes/General/APIDiffsMacOSX10_8/VideoToolbox.html
    fileprivate var properties:[NSString: NSObject] {
        let isBaseline:Bool = profileLevel.contains("Baseline")
        var properties:[NSString: NSObject] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
            kVTCompressionPropertyKey_ProfileLevel: profileLevel as NSObject,
            kVTCompressionPropertyKey_AverageBitRate: Int(bitrate) as NSObject,
            kVTCompressionPropertyKey_ExpectedFrameRate: NSNumber(value: expectedFPS),
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: NSNumber(value: maxKeyFrameIntervalDuration),
            kVTCompressionPropertyKey_AllowFrameReordering: !isBaseline as NSObject,
            kVTCompressionPropertyKey_PixelTransferProperties: [
                "ScalingMode": "Trim"
            ] as NSObject
        ]

#if os(OSX)
        if (enabledHardwareEncoder) {
            properties[kVTVideoEncoderSpecification_EncoderID] = "com.apple.videotoolbox.videoencoder.h264.gva" as NSObject
            properties["EnableHardwareAcceleratedVideoEncoder"] = true as NSObject
            properties["RequireHardwareAcceleratedVideoEncoder"] = true as NSObject
        }
#endif

        if (dataRateLimits != AVCEncoder.defaultDataRateLimits) {
            properties[kVTCompressionPropertyKey_DataRateLimits] = dataRateLimits as NSObject
        }
        if (!isBaseline) {
            properties[kVTCompressionPropertyKey_H264EntropyMode] = kVTH264EntropyMode_CABAC
        }
        return properties
    }

    fileprivate var callback:VTCompressionOutputCallback = {(
        outputCallbackRefCon:UnsafeMutableRawPointer?,
        sourceFrameRefCon:UnsafeMutableRawPointer?,
        status:OSStatus,
        infoFlags:VTEncodeInfoFlags,
        sampleBuffer:CMSampleBuffer?) in
        guard let sampleBuffer:CMSampleBuffer = sampleBuffer , status == noErr else {
            return
        }
        let encoder:AVCEncoder = unsafeBitCast(outputCallbackRefCon, to: AVCEncoder.self)
        encoder.formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        encoder.delegate?.sampleOutput(video: sampleBuffer)
    }

    fileprivate var _session:VTCompressionSession? = nil
    fileprivate var session:VTCompressionSession? {
        get {
            if (_session == nil)  {
                guard VTCompressionSessionCreate(
                    kCFAllocatorDefault,
                    width,
                    height,
                    kCMVideoCodecType_H264,
                    nil,
                    attributes as CFDictionary?,
                    nil,
                    callback,
                    unsafeBitCast(self, to: UnsafeMutableRawPointer.self),
                    &_session
                    ) == noErr else {
                    logger.warning("create a VTCompressionSessionCreate")
                    return nil
                }
                invalidateSession = false
                status = VTSessionSetProperties(_session!, properties as CFDictionary)
                status = VTCompressionSessionPrepareToEncodeFrames(_session!)
            }
            return _session
        }
        set {
            if let session:VTCompressionSession = _session {
                VTCompressionSessionInvalidate(session)
            }
            _session = newValue
        }
    }

    func encodeImageBuffer(_ imageBuffer:CVImageBuffer, presentationTimeStamp:CMTime, duration:CMTime) {
        guard running else {
            return
        }
        if (invalidateSession) {
            session = nil
        }
        guard let session:VTCompressionSession = session else {
            return
        }
        var flags:VTEncodeInfoFlags = VTEncodeInfoFlags()
        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer,
            presentationTimeStamp,
            duration,
            nil,
            nil,
            &flags
        )
    }

#if os(iOS)
    func applicationWillEnterForeground(_ notification:Notification) {
        invalidateSession = true
    }
    func didAudioSessionInterruption(_ notification:Notification) {
        guard
            let userInfo:[AnyHashable: Any] = notification.userInfo,
            let value:NSNumber = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber,
            let type:AVAudioSessionInterruptionType = AVAudioSessionInterruptionType(rawValue: value.uintValue)
            else {
                return
        }
        switch type {
        case .ended:
            invalidateSession = true
        default:
            break
        }
    }
#endif
}

extension AVCEncoder: Runnable {
    // MARK: Runnable
    func startRunning() {
        lockQueue.async {
            self.running = true
#if os(iOS)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(AVCEncoder.didAudioSessionInterruption(_:)),
                name: NSNotification.Name.AVAudioSessionInterruption,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(AVCEncoder.applicationWillEnterForeground(_:)),
                name: NSNotification.Name.UIApplicationWillEnterForeground,
                object: nil
            )
#endif
        }
    }

    func stopRunning() {
        lockQueue.async {
            self.session = nil
            self.formatDescription = nil
#if os(iOS)
            NotificationCenter.default.removeObserver(self)
#endif
            self.running = false
        }
    }
}
