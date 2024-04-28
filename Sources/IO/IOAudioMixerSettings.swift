import AVFoundation
import Foundation

/// Constraints on the audio mixier settings.
public struct IOAudioMixerSettings {
    /// The default value.
    public static let `default` = IOAudioMixerSettings()
    /// Maximum sampleRate supported by the system
    public static let maximumSampleRate: Float64 = 48000.0

    #if os(macOS)
    static let commonFormat: AVAudioCommonFormat = .pcmFormatFloat32
    #else
    static let commonFormat: AVAudioCommonFormat = .pcmFormatInt16
    #endif

    /// Specifies the sampleRate of audio output.
    public let sampleRate: Float64
    /// Specifies the channels of audio output.
    public let channels: UInt32
    /// Specifies the muted that indicates whether the audio output is muted.
    public var isMuted = false
    /// Specifies the main track number.
    public var mainTrack: UInt8 = 0
    /// Specifies the track settings.
    public var tracks: [UInt8: IOAudioMixerTrackSettings] = .init()

    /// Creates a new instance of a settings.
    public init(
        sampleRate: Float64 = 0,
        channels: UInt32 = 0
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
    }

    func invalidateOutputFormat(_ oldValue: Self) -> Bool {
        return !(sampleRate == oldValue.sampleRate &&
                    channels == oldValue.channels)
    }

    func makeOutputFormat(_ formatDescription: CMFormatDescription?) -> AVAudioFormat? {
        guard let format = AVAudioUtil.makeAudioFormat(formatDescription) else {
            return nil
        }
        let sampleRate = min(sampleRate == 0 ? format.sampleRate : sampleRate, Self.maximumSampleRate)
        let channelCount = channels == 0 ? format.channelCount : channels
        if let channelLayout = AVAudioUtil.makeChannelLayout(channelCount) {
            return .init(
                commonFormat: Self.commonFormat,
                sampleRate: sampleRate,
                interleaved: format.isInterleaved,
                channelLayout: channelLayout
            )
        }
        return .init(
            commonFormat: Self.commonFormat,
            sampleRate: sampleRate,
            channels: min(channelCount, 2),
            interleaved: format.isInterleaved
        )
    }
}
