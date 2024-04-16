import AVFoundation

/// The IOAudioMixerError  error domain codes.
public enum IOAudioMixerError: Swift.Error {
    /// Invalid resample settings.
    case invalidSampleRate
    /// Mixer is unable to provide input data.
    case unableToProvideInputData
    /// Mixer is unable to make sure that all resamplers output the same audio format.
    case unableToEnforceAudioFormat
}

protocol IOAudioMixerDelegate: AnyObject {
    func audioMixer(_ audioMixer: any IOAudioMixerConvertible, didOutput audioFormat: AVAudioFormat)
    func audioMixer(_ audioMixer: any IOAudioMixerConvertible, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime)
    func audioMixer(_ audioMixer: any IOAudioMixerConvertible, errorOccurred error: IOAudioUnitError)
}

/// Constraints on the audio mixier settings.
public struct IOAudioMixerSettings {
    /// The default value.
    public static let `default` = IOAudioMixerSettings()

    /// Specifies the main track number.
    public var mainTrack: UInt8 = 0
    /// Specifies the channels of audio output.
    public var channels: UInt32
    /// Specifies the sampleRate of audio output.
    public var sampleRate: Float64
    /// Specifies the track settings.
    public var tracks: [UInt8: IOAudioMixerTrackSettings] = .init()

    /// Creates a new instance of a settings.
    public init(
        mainTrack: UInt8 = 0,
        channels: UInt32 = 0,
        sampleRate: Float64 = 0,
        tracks: [UInt8: IOAudioMixerTrackSettings] = .init()
    ) {
        self.mainTrack = mainTrack
        self.channels = channels
        self.sampleRate = sampleRate
        self.tracks = tracks
    }
}

protocol IOAudioMixerConvertible: AnyObject {
    var delegate: (any IOAudioMixerDelegate)? { get set }
    var settings: IOAudioMixerSettings { get set }

    func append(_ buffer: CMSampleBuffer, track: UInt8)
    func append(_ buffer: AVAudioPCMBuffer, when: AVAudioTime, track: UInt8)
}

extension IOAudioMixerConvertible {
    static func makeAudioFormat(_ inSourceFormat: inout AudioStreamBasicDescription) -> AVAudioFormat? {
        if inSourceFormat.mFormatID == kAudioFormatLinearPCM && kLinearPCMFormatFlagIsBigEndian == (inSourceFormat.mFormatFlags & kLinearPCMFormatFlagIsBigEndian) {
            let interleaved = !((inSourceFormat.mFormatFlags & kLinearPCMFormatFlagIsNonInterleaved) == kLinearPCMFormatFlagIsNonInterleaved)
            if let channelLayout = Self.makeChannelLayout(inSourceFormat.mChannelsPerFrame) {
                return .init(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: inSourceFormat.mSampleRate,
                    interleaved: interleaved,
                    channelLayout: channelLayout
                )
            }
            return .init(
                commonFormat: .pcmFormatInt16,
                sampleRate: inSourceFormat.mSampleRate,
                channels: inSourceFormat.mChannelsPerFrame,
                interleaved: interleaved
            )
        }
        if let layout = Self.makeChannelLayout(inSourceFormat.mChannelsPerFrame) {
            return .init(streamDescription: &inSourceFormat, channelLayout: layout)
        }
        return .init(streamDescription: &inSourceFormat)
    }

    private static func makeChannelLayout(_ numberOfChannels: UInt32) -> AVAudioChannelLayout? {
        guard 2 < numberOfChannels else {
            return nil
        }
        switch numberOfChannels {
        case 4:
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_AudioUnit_4)
        case 5:
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_AudioUnit_5)
        case 6:
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_AudioUnit_6)
        case 8:
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_AudioUnit_8)
        default:
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | numberOfChannels)
        }
    }
}
