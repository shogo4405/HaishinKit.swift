import Foundation
import VideoToolbox

/// The VideoCodecSettings class  specifying video compression settings.
public struct VideoCodecSettings: Codable {
    /// The defulat value.
    public static let `default` = VideoCodecSettings()

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
    public var bitRateMode: VideoCodec.BitRateMode
    /// Specifies the H264 profileLevel.
    public var profileLevel: String
    /// Specifies  the HardwareEncoder is enabled(TRUE), or not(FALSE) for macOS.
    public var isHardwareEncoderEnabled = true

    var expectedFrameRate: Float64 = 30

    /// Creates a new VideoCodecSettings instance.
    public init(
        videoSize: VideoSize = .init(width: 854, height: 480),
        profileLevel: String = kVTProfileLevel_H264_Baseline_3_1 as String,
        bitRate: UInt32 = 640 * 1000,
        maxKeyFrameIntervalDuration: Int32 = 2,
        scalingMode: ScalingMode = .trim,
        bitRateMode: VideoCodec.BitRateMode = .average,
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
        if expectedFrameRate != rhs.expectedFrameRate {
            let option = VTSessionOption(key: .expectedFrameRate, value: NSNumber(value: expectedFrameRate))
            if let status = codec.session?.setOption(option), status != noErr {
                codec.delegate?.videoCodec(codec, errorOccurred: .failedToSetOption(status: status, option: option))
            }
        }
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
            .init(key: .expectedFrameRate, value: NSNumber(value: expectedFrameRate)),
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
