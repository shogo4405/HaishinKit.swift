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
        /// The VideoCodec failed to set an option.
        case failedToSetOption(status: OSStatus, option: VTSessionOption)
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
            sessionHolder.invalidateSession()
        }
    }

    var width: Int32 = VideoCodec.defaultWidth {
        didSet {
            guard width != oldValue else {
                return
            }
            sessionHolder.invalidateSession()
        }
    }
    var height: Int32 = VideoCodec.defaultHeight {
        didSet {
            guard height != oldValue else {
                return
            }
            sessionHolder.invalidateSession()
        }
    }
    #if os(macOS)
    var enabledHardwareEncoder = true {
        didSet {
            guard enabledHardwareEncoder != oldValue else {
                return
            }
            sessionHolder.invalidateSession()
        }
    }
    #endif
    var bitrate: UInt32 = VideoCodec.defaultBitrate {
        didSet {
            guard bitrate != oldValue else {
                return
            }
            let option = VTSessionOption(key: .averageBitRate, value: NSNumber(value: bitrate))
            if let status = sessionHolder.session?.setOption(option), status != noErr {
                delegate?.videoCodec(self, errorOccurred: .failedToSetOption(status: status, option: option))
            }
        }
    }
    var profileLevel: String = kVTProfileLevel_H264_Baseline_3_1 as String {
        didSet {
            guard profileLevel != oldValue else {
                return
            }
            sessionHolder.invalidateSession()
        }
    }
    var maxKeyFrameIntervalDuration: Double = 2.0 {
        didSet {
            guard maxKeyFrameIntervalDuration != oldValue else {
                return
            }
            sessionHolder.invalidateSession()
        }
    }
    // swiftlint:disable discouraged_optional_boolean
    var allowFrameReordering: Bool? = false {
        didSet {
            guard allowFrameReordering != oldValue else {
                return
            }
            sessionHolder.invalidateSession()
        }
    }
    var locked: UInt32 = 0
    var lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.VideoCodec.lock")
    var expectedFPS: Float64 = AVMixer.defaultFPS {
        didSet {
            guard expectedFPS != oldValue else {
                return
            }
            let option = VTSessionOption(key: .expectedFrameRate, value: NSNumber(value: expectedFPS))
            if let status = sessionHolder.session?.setOption(option), status != noErr {
                print(status)
                delegate?.videoCodec(self, errorOccurred: .failedToSetOption(status: status, option: option))
            }
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
    private var lastImageBuffer: CVImageBuffer?
    private var sessionHolder = VTSessionHolder()

    init() {
        settings.observer = self
    }

    func inputBuffer(_ imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime) {
        guard isRunning.value && locked == 0 else {
            return
        }
        if sessionHolder.isInvalidateSession {
            _ = sessionHolder.makeSession(self)
        }
        sessionHolder.session?.inputBuffer(
            muted ? lastImageBuffer ?? imageBuffer : imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: duration
        ) { [unowned self] status, _, sampleBuffer in
            guard let sampleBuffer, status == noErr else {
                self.delegate?.videoCodec(self, errorOccurred: .failedToFlame(status: status))
                return
            }
            self.formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
            self.delegate?.videoCodec(self, didOutput: sampleBuffer)
            if !self.muted || self.lastImageBuffer == nil {
                self.lastImageBuffer = imageBuffer
            }
        }
    }

    func options() -> Set<VTSessionOption> {
        let isBaseline = profileLevel.contains("Baseline")
        var options = Set<VTSessionOption>([
            .init(key: .realTime, value: kCFBooleanTrue),
            .init(key: .profileLevel, value: profileLevel as NSObject),
            .init(key: .averageBitRate, value: NSNumber(value: bitrate)),
            .init(key: .expectedFrameRate, value: NSNumber(value: expectedFPS)),
            .init(key: .maxKeyFrameIntervalDuration, value: NSNumber(value: maxKeyFrameIntervalDuration)),
            .init(key: .allowFrameReordering, value: (allowFrameReordering ?? !isBaseline) as NSObject)
        ])
        #if os(OSX)
        if enabledHardwareEncoder {
            #if arch(arm64)
            options.insert(.init(key: .init(CFString: kVTVideoEncoderSpecification_EncoderID), value: "com.apple.videotoolbox.videoencoder.ave.avc" as NSObject))
            #else
            options.insert(.init(key: .init(CFString: kVTVideoEncoderSpecification_EncoderID), value: "com.apple.videotoolbox.videoencoder.h264.gva" as NSObject))
            #endif
            options.insert(.init(key: .init(CFString: "EnableHardwareAcceleratedVideoEncoder" as CFString), value: kCFBooleanTrue))
            options.insert(.init(key: .init(CFString: "RequireHardwareAcceleratedVideoEncoder" as CFString), value: kCFBooleanTrue))
        }
        #endif
        if !isBaseline {
            options.insert(.init(key: .H264EntropyMode, value: kVTH264EntropyMode_CABAC))
        }
        return options
    }

    #if os(iOS)
    @objc
    private func applicationWillEnterForeground(_ notification: Notification) {
        sessionHolder.invalidateSession()
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
            sessionHolder.invalidateSession()
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
            self.sessionHolder.invalidateSession()
            self.lastImageBuffer = nil
            self.formatDescription = nil
            #if os(iOS)
            NotificationCenter.default.removeObserver(self)
            #endif
            self.isRunning.mutate { $0 = false }
        }
    }
}
