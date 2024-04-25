import AVFoundation
import Foundation

/// Constraints on the audio mixier settings.
public struct IOAudioMixerSettings {
    /// The default value.
    public static let `default` = IOAudioMixerSettings()

    /// Specifies the channels of audio output.
    public let channels: UInt32
    /// Specifies the sampleRate of audio output.
    public let sampleRate: Float64
    /// Specifies the muted that indicates whether the audio output is muted.
    public var isMuted = false
    /// Specifies the main track number.
    public var mainTrack: UInt8 = 0
    /// Specifies the track settings.
    public var tracks: [UInt8: IOAudioMixerTrackSettings] = .init()

    /// Creates a new instance of a settings.
    public init(
        channels: UInt32 = 0,
        sampleRate: Float64 = 0
    ) {
        self.channels = channels
        self.sampleRate = sampleRate
    }

    func invalidateOutputFormat(_ oldValue: Self) -> Bool {
        return !(sampleRate == oldValue.sampleRate &&
                    channels == oldValue.channels)
    }

    func makeOutputFormat(_ formatDescription: CMFormatDescription?) -> AVAudioFormat? {
        guard let format = AVAudioUtil.makeAudioFormat(formatDescription) else {
            return nil
        }
        return .init(
            commonFormat: format.commonFormat,
            sampleRate: min(sampleRate == 0 ? format.sampleRate : sampleRate, AudioCodecSettings.maximumSampleRate),
            channels: min(channels == 0 ? format.channelCount : channels, AudioCodecSettings.maximumNumberOfChannels),
            interleaved: format.isInterleaved
        )
    }
}
