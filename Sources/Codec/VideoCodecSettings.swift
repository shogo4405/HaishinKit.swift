import Foundation
import VideoToolbox

/// The VideoCodecSettings class  specifying video compression settings.
public struct VideoCodecSettings: Codable {
    /// The defulat value.
    public static let `default` = VideoCodecSettings()

    /// A bitRate mode that affectes how to encode the video source.
    public enum BitRateMode: String, Codable {
        /// The average bit rate.
        case average
        /// The constant bit rate.
        @available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
        case constant

        var key: VTSessionOptionKey {
            if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
                switch self {
                case .average:
                    return .averageBitRate
                case .constant:
                    return .constantBitRate
                }
            }
            return .averageBitRate
        }
    }

    /**
     * The scaling mode.
     * - seealso: https://developer.apple.com/documentation/videotoolbox/kvtpixeltransferpropertykey_scalingmode
     * - seealso: https://developer.apple.com/documentation/videotoolbox/vtpixeltransfersession/pixel_transfer_properties/scaling_mode_constants
     */
    public enum ScalingMode: String, Codable {
        /// kVTScalingMode_Normal
        case normal = "Normal"
        /// kVTScalingMode_Letterbox
        case letterbox = "Letterbox"
        /// kVTScalingMode_CropSourceToCleanAperture
        case cropSourceToCleanAperture = "CropSourceToCleanAperture"
        /// kVTScalingMode_Trim
        case trim = "Trim"
    }

    /// Specifies the video size of encoding video.
    public var videoSize: VideoSize
    /// Specifies the bitrate.
    public var bitRate: UInt32
    /// Specifies the keyframeInterval.
    public var maxKeyFrameIntervalDuration: Int32
    /// Specifies the scalingMode.
    public var scalingMode: ScalingMode
    // swiftlint:disable discouraged_optional_boolean
    /// Specifies the allowFrameRecording.
    public var allowFrameReordering: Bool?
    /// Specifies the bitRateMode.
    public var bitRateMode: BitRateMode
    /// Specifies the H264 profileLevel.
    public var profileLevel: String
    /// Specifies  the HardwareEncoder is enabled(TRUE), or not(FALSE) for macOS.
    public var isHardwareEncoderEnabled = true

    var expectedFrameRate: Float64 = IOMixer.defaultFrameRate

    /// Creates a new VideoCodecSettings instance.
    public init(
        videoSize: VideoSize = .init(width: 854, height: 480),
        profileLevel: String = kVTProfileLevel_H264_Baseline_3_1 as String,
        bitRate: UInt32 = 640 * 1000,
        maxKeyFrameIntervalDuration: Int32 = 2,
        scalingMode: ScalingMode = .trim,
        bitRateMode: BitRateMode = .average,
        allowFrameReordering: Bool? = nil,
        isHardwareEncoderEnabled: Bool = true
    ) {
        self.videoSize = videoSize
        self.profileLevel = profileLevel
        self.bitRate = bitRate
        self.maxKeyFrameIntervalDuration = maxKeyFrameIntervalDuration
        self.scalingMode = scalingMode
        self.bitRateMode = bitRateMode
        self.allowFrameReordering = allowFrameReordering
        self.isHardwareEncoderEnabled = isHardwareEncoderEnabled
    }

    func invalidateSession(_ rhs: VideoCodecSettings) -> Bool {
        return !(videoSize == rhs.videoSize &&
                    maxKeyFrameIntervalDuration == rhs.maxKeyFrameIntervalDuration &&
                    scalingMode == rhs.scalingMode &&
                    allowFrameReordering == rhs.allowFrameReordering &&
                    bitRateMode == rhs.bitRateMode &&
                    profileLevel == rhs.profileLevel &&
                    isHardwareEncoderEnabled == rhs.isHardwareEncoderEnabled
        )
    }

    func apply(_ codec: VideoCodec, rhs: VideoCodecSettings) {
        if bitRate != rhs.bitRate {
            let option = VTSessionOption(key: bitRateMode.key, value: NSNumber(value: bitRate))
            if let status = codec.session?.setOption(option), status != noErr {
                codec.delegate?.videoCodec(codec, errorOccurred: .failedToSetOption(status: status, option: option))
            }
        }
    }

    func options() -> Set<VTSessionOption> {
        let isBaseline = profileLevel.contains("Baseline")
        var options = Set<VTSessionOption>([
            .init(key: .realTime, value: kCFBooleanTrue),
            .init(key: .profileLevel, value: profileLevel as NSObject),
            .init(key: bitRateMode.key, value: NSNumber(value: bitRate)),
            // It seemes that VT supports the range 0 to 30.
            .init(key: .expectedFrameRate, value: NSNumber(value: (expectedFrameRate <= 30) ? expectedFrameRate : 0)),
            .init(key: .maxKeyFrameIntervalDuration, value: NSNumber(value: maxKeyFrameIntervalDuration)),
            .init(key: .allowFrameReordering, value: (allowFrameReordering ?? !isBaseline) as NSObject),
            .init(key: .pixelTransferProperties, value: [
                "ScalingMode": scalingMode.rawValue
            ] as NSObject)
        ])
        #if os(macOS)
        if isHardwareEncoderEnabled {
            options.insert(.init(key: .encoderID, value: VideoCodec.encoderName))
            options.insert(.init(key: .enableHardwareAcceleratedVideoEncoder, value: kCFBooleanTrue))
            options.insert(.init(key: .requireHardwareAcceleratedVideoEncoder, value: kCFBooleanTrue))
        }
        #endif
        if !isBaseline {
            options.insert(.init(key: .H264EntropyMode, value: kVTH264EntropyMode_CABAC))
        }
        return options
    }
}
