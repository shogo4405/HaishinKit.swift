import AVFoundation
import CoreFoundation
import VideoToolbox

#if os(iOS)
import UIKit
#endif

/**
 * The interface a VideoCodec uses to inform its delegate.
 */
public protocol VideoCodecDelegate: AnyObject {
    /// Tells the receiver to set a formatDescription.
    func videoCodec(_ codec: VideoCodec, didSet formatDescription: CMFormatDescription?)
    /// Tells the receiver to output a encoded or decoded sampleBuffer.
    func videoCodec(_ codec: VideoCodec, didOutput sampleBuffer: CMSampleBuffer)
    /// Tells the receiver to occured an error.
    func videoCodec(_ codec: VideoCodec, errorOccurred error: VideoCodec.Error)
}

// MARK: -
/**
 * The VideoCodec class provides methods for encode or decode for video.
 */
public class VideoCodec {
    /**
     * The VideoCodec error domain codes.
     */
    public enum Error: Swift.Error {
        /// The VideoCodec failed to create the VTSession.
        case failedToCreate(status: OSStatus)
        /// The VideoCodec failed to prepare the VTSession.
        case failedToPrepare(status: OSStatus)
        /// The VideoCodec failed to encode or decode a flame.
        case failedToFlame(status: OSStatus)
    }

    /**
     * The video encoding or decoding options.
     */
    public enum Option: String, KeyPathRepresentable, CaseIterable {
        /// Specifies the muted
        case muted
        /// Specifies the width of video.
        case width
        /// Specifies the height of video.
        case height
        /// Specifies the bitrate.
        case bitrate
        /// Specifies the H264 profile level.
        case profileLevel
        #if os(macOS)
        /// Specifies  the HardwareEncoder is enabled(TRUE), or not(FALSE).
        case enabledHardwareEncoder
        #endif
        /// Specifies the keyframeInterval.
        case maxKeyFrameIntervalDuration
        /// Specifies the scalingMode.
        case scalingMode
        case allowFrameReordering

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
            case .allowFrameReordering:
                return \VideoCodec.allowFrameReordering
            }
        }
    }

    /// The videoCodec's width value. The default value is 480.
    public static let defaultWidth: Int32 = 480
    /// The videoCodec's height value. The default value is 272.
    public static let defaultHeight: Int32 = 272
    /// The videoCodec's bitrate value. The default value is 160,000.
    public static let defaultBitrate: UInt32 = 160 * 1000
    /// The videoCodec's scalingMode value. The default value is trim.
    public static let defaultScalingMode: ScalingMode = .trim
    /// The videoCodec's attributes value.
    public static var defaultAttributes: [NSString: AnyObject]? = [
        kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject,
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue
    ]

    /// Specifies the settings for a VideoCodec.
    public var settings: Setting<VideoCodec, Option> = [:] {
        didSet {
            settings.observer = self
        }
    }
    /// The running value indicating whether the VideoCodec is running.
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
    // swiftlint:disable discouraged_optional_boolean
    var allowFrameReordering: Bool? = false {
        didSet {
            guard allowFrameReordering != oldValue else {
                return
            }
            invalidateSession = true
        }
    }
    var locked: UInt32 = 0
    var lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.VideoCodec.lock")
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

    private var attributes: [NSString: AnyObject]? {
        guard VideoCodec.defaultAttributes != nil else {
            return nil
        }
        var attributes: [NSString: AnyObject] = [:]
        for (key, value) in VideoCodec.defaultAttributes ?? [:] {
            attributes[key] = value
        }
        attributes[kCVPixelBufferWidthKey] = NSNumber(value: width)
        attributes[kCVPixelBufferHeightKey] = NSNumber(value: height)
        return attributes
    }
    private var invalidateSession = true
    private var lastImageBuffer: CVImageBuffer?

    /// - seealso: https://developer.apple.com/library/mac/releasenotes/General/APIDiffsMacOSX10_8/VideoToolbox.html
    private var properties: [NSString: NSObject] {
        let isBaseline: Bool = profileLevel.contains("Baseline")
        var properties: [NSString: NSObject] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
            kVTCompressionPropertyKey_ProfileLevel: profileLevel as NSObject,
            kVTCompressionPropertyKey_AverageBitRate: Int(bitrate) as NSObject,
            kVTCompressionPropertyKey_ExpectedFrameRate: NSNumber(value: expectedFPS),
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: NSNumber(value: maxKeyFrameIntervalDuration),
            kVTCompressionPropertyKey_AllowFrameReordering: (allowFrameReordering ?? !isBaseline) as NSObject,
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
        guard let refcon = outputCallbackRefCon else {
            return
        }
        let codec = Unmanaged<VideoCodec>.fromOpaque(refcon).takeUnretainedValue()
        guard
            let sampleBuffer: CMSampleBuffer = sampleBuffer, status == noErr else {
            if status == kVTParameterErr {
                // on iphone 11 with size=1792x827 this occurs
                logger.error("encoding failed with kVTParameterErr. Perhaps the width x height is too big for the encoder setup?")
                codec.delegate?.videoCodec(codec, errorOccurred: .failedToFlame(status: status))
            }
            return
        }
        codec.formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        codec.delegate?.videoCodec(codec, didOutput: sampleBuffer)
    }

    private var _session: VTCompressionSession?
    private var session: VTCompressionSession? {
        get {
            if _session == nil {
                var status: OSStatus = VTCompressionSessionCreate(
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
                )
                guard status == noErr, let session = _session else {
                    logger.warn("create a VTCompressionSessionCreate")
                    delegate?.videoCodec(self, errorOccurred: .failedToCreate(status: status))
                    return nil
                }
                invalidateSession = false
                status = session.setProperties(properties)
                status = session.prepareToEncodeFrame()
                guard status == noErr else {
                    logger.error("setup failed VTCompressionSessionPrepareToEncodeFrames. Size = \(width)x\(height)")
                    delegate?.videoCodec(self, errorOccurred: .failedToPrepare(status: status))
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
            VTSessionSetProperty(
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
            let type = AVAudioSession.InterruptionType(rawValue: value.uintValue) else {
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
