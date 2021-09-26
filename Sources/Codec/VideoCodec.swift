import AVFoundation
import CoreFoundation
import VideoToolbox

#if os(iOS)
import UIKit
#endif

public protocol VideoCodecDelegate: AnyObject {
    func videoCodec(_ codec: VideoCodec, didSet formatDescription: CMFormatDescription?)
    func videoCodec(_ codec: VideoCodec, didOutput sampleBuffer: CMSampleBuffer)
}

// MARK: -
public final class VideoCodec {
    public enum Option: String, KeyPathRepresentable, CaseIterable {
        case muted
        case width
        case height
        case bitrate
        case profileLevel
        #if os(macOS)
        case enabledHardwareEncoder
        #endif
        case maxKeyFrameIntervalDuration
        case scalingMode

        public var keyPath: AnyKeyPath {
            switch self {
            case .muted:
                return \VideoCodec.muted
            case .width:
                return \VideoCodec.width
            case .height:
                return \VideoCodec.height
            case .bitrate:
                return \VideoCodec.bitrate
            #if os(macOS)
            case .enabledHardwareEncoder:
                return \VideoCodec.enabledHardwareEncoder
            #endif
            case .maxKeyFrameIntervalDuration:
                return \VideoCodec.maxKeyFrameIntervalDuration
            case .scalingMode:
                return \VideoCodec.scalingMode
            case .profileLevel:
                return \VideoCodec.profileLevel
            }
        }
    }

    public static let defaultWidth: Int32 = 480
    public static let defaultHeight: Int32 = 272
    public static let defaultBitrate: UInt32 = 160 * 1000
    public static let defaultScalingMode: ScalingMode = .trim

    static let defaultAttributes: [NSString: AnyObject] = [
        kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject,
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue
    ]

    public var settings: Setting<VideoCodec, Option> = [:] {
        didSet {
            settings.observer = self
        }
    }
    public private(set) var isRunning: Atomic<Bool> = .init(false)

    var muted = false
    var scalingMode: ScalingMode = VideoCodec.defaultScalingMode {
        didSet {
            guard scalingMode != oldValue else {
                return
            }
            invalidateSession = true
        }
    }

    var width: Int32 = VideoCodec.defaultWidth {
        didSet {
            guard width != oldValue else {
                return
            }
            invalidateSession = true
        }
    }
    var height: Int32 = VideoCodec.defaultHeight {
        didSet {
            guard height != oldValue else {
                return
            }
            invalidateSession = true
        }
    }
    #if os(macOS)
    var enabledHardwareEncoder = true {
        didSet {
            guard enabledHardwareEncoder != oldValue else {
                return
            }
            invalidateSession = true
        }
    }
    #endif
    var bitrate: UInt32 = VideoCodec.defaultBitrate {
        didSet {
            guard bitrate != oldValue else {
                return
            }
            setProperty(kVTCompressionPropertyKey_AverageBitRate, Int(bitrate) as CFTypeRef)
        }
    }
    var profileLevel: String = kVTProfileLevel_H264_Baseline_3_1 as String {
        didSet {
            guard profileLevel != oldValue else {
                return
            }
            invalidateSession = true
        }
    }
    var maxKeyFrameIntervalDuration: Double = 2.0 {
        didSet {
            guard maxKeyFrameIntervalDuration != oldValue else {
                return
            }
            invalidateSession = true
        }
    }
    var locked: UInt32 = 0
    var lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.H264Encoder.lock")
    var expectedFPS: Float64 = AVMixer.defaultFPS {
        didSet {
            guard expectedFPS != oldValue else {
                return
            }
            setProperty(kVTCompressionPropertyKey_ExpectedFrameRate, NSNumber(value: expectedFPS))
        }
    }
    var formatDescription: CMFormatDescription? {
        didSet {
            guard !CMFormatDescriptionEqual(formatDescription, otherFormatDescription: oldValue) else {
                return
            }
            delegate?.videoCodec(self, didSet: formatDescription)
        }
    }
    weak var delegate: VideoCodecDelegate?

    private(set) var status: OSStatus = noErr
    private var attributes: [NSString: AnyObject] {
        var attributes: [NSString: AnyObject] = VideoCodec.defaultAttributes
        attributes[kCVPixelBufferWidthKey] = NSNumber(value: width)
        attributes[kCVPixelBufferHeightKey] = NSNumber(value: height)
        return attributes
    }
    private var invalidateSession = true
    private var lastImageBuffer: CVImageBuffer?

    // @see: https://developer.apple.com/library/mac/releasenotes/General/APIDiffsMacOSX10_8/VideoToolbox.html
    private var properties: [NSString: NSObject] {
        let isBaseline: Bool = profileLevel.contains("Baseline")
        var properties: [NSString: NSObject] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
            kVTCompressionPropertyKey_ProfileLevel: profileLevel as NSObject,
            kVTCompressionPropertyKey_AverageBitRate: Int(bitrate) as NSObject,
            kVTCompressionPropertyKey_ExpectedFrameRate: NSNumber(value: expectedFPS),
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: NSNumber(value: maxKeyFrameIntervalDuration),
            kVTCompressionPropertyKey_AllowFrameReordering: !isBaseline as NSObject,
            kVTCompressionPropertyKey_PixelTransferProperties: [
                "ScalingMode": scalingMode.rawValue
            ] as NSObject
        ]
#if os(OSX)
        if enabledHardwareEncoder {
            #if arch(arm64)
            properties[kVTVideoEncoderSpecification_EncoderID] = "com.apple.videotoolbox.videoencoder.ave.avc" as NSObject
            #else
            properties[kVTVideoEncoderSpecification_EncoderID] = "com.apple.videotoolbox.videoencoder.h264.gva" as NSObject
            #endif
            properties["EnableHardwareAcceleratedVideoEncoder"] = kCFBooleanTrue
            properties["RequireHardwareAcceleratedVideoEncoder"] = kCFBooleanTrue
        }
#endif
        if !isBaseline {
            properties[kVTCompressionPropertyKey_H264EntropyMode] = kVTH264EntropyMode_CABAC
        }
        return properties
    }

    private var callback: VTCompressionOutputCallback = {(outputCallbackRefCon: UnsafeMutableRawPointer?, _: UnsafeMutableRawPointer?, status: OSStatus, _: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?) in
        guard
            let refcon: UnsafeMutableRawPointer = outputCallbackRefCon,
            let sampleBuffer: CMSampleBuffer = sampleBuffer, status == noErr else {
                if status == kVTParameterErr {
                    // on iphone 11 with size=1792x827 this occurs
                    logger.error("encoding failed with kVTParameterErr. Perhaps the width x height is too big for the encoder setup?")
                }
            return
        }
        let codec: VideoCodec = Unmanaged<VideoCodec>.fromOpaque(refcon).takeUnretainedValue()
        codec.formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        codec.delegate?.videoCodec(codec, didOutput: sampleBuffer)
    }

    private var _session: VTCompressionSession?
    private var session: VTCompressionSession? {
        get {
            if _session == nil {
                guard VTCompressionSessionCreate(
                    allocator: kCFAllocatorDefault,
                    width: width,
                    height: height,
                    codecType: kCMVideoCodecType_H264,
                    encoderSpecification: nil,
                    imageBufferAttributes: attributes as CFDictionary?,
                    compressedDataAllocator: nil,
                    outputCallback: callback,
                    refcon: Unmanaged.passUnretained(self).toOpaque(),
                    compressionSessionOut: &_session
                    ) == noErr, let session = _session else {
                    logger.warn("create a VTCompressionSessionCreate")
                    return nil
                }
                invalidateSession = false
                status = session.setProperties(properties)
                status = session.prepareToEncodeFrame()
                guard status == noErr else {
                    logger.error("setup failed VTCompressionSessionPrepareToEncodeFrames. Size = \(width)x\(height)")
                    return nil
                }
            }
            return _session
        }
        set {
            _session?.invalidate()
            _session = newValue
        }
    }

    init() {
        settings.observer = self
    }

    func encodeImageBuffer(_ imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime) {
        guard isRunning.value && locked == 0 else {
            return
        }
        if invalidateSession {
            session = nil
        }
        guard let session: VTCompressionSession = session else {
            return
        }
        var flags: VTEncodeInfoFlags = []
        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: muted ? lastImageBuffer ?? imageBuffer : imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: duration,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags
        )
        if !muted || lastImageBuffer == nil {
            lastImageBuffer = imageBuffer
        }
    }

    private func setProperty(_ key: CFString, _ value: CFTypeRef?) {
        lockQueue.async {
            guard let session: VTCompressionSession = self._session else {
                return
            }
            self.status = VTSessionSetProperty(
                session,
                key: key,
                value: value
            )
        }
    }

#if os(iOS)
    @objc
    private func applicationWillEnterForeground(_ notification: Notification) {
        invalidateSession = true
    }

    @objc
    private func didAudioSessionInterruption(_ notification: Notification) {
        guard
            let userInfo: [AnyHashable: Any] = notification.userInfo,
            let value: NSNumber = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber,
            let type: AVAudioSession.InterruptionType = AVAudioSession.InterruptionType(rawValue: value.uintValue) else {
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

extension VideoCodec: Running {
    // MARK: Running
    public func startRunning() {
        lockQueue.async {
            self.isRunning.mutate { $0 = true }
            OSAtomicAnd32Barrier(0, &self.locked)
#if os(iOS)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.didAudioSessionInterruption),
                name: AVAudioSession.interruptionNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.applicationWillEnterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
#endif
        }
    }

    public func stopRunning() {
        lockQueue.async {
            self.session = nil
            self.lastImageBuffer = nil
            self.formatDescription = nil
#if os(iOS)
            NotificationCenter.default.removeObserver(self)
#endif
            self.isRunning.mutate { $0 = false }
        }
    }
}
