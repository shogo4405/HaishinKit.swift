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

struct IOAudioMixerSettings {
    let mainTrack: Int = 0
    let defaultResamplerSettings: IOAudioResamplerSettings
    let resamplersSettings: [Int: IOAudioResamplerSettings]

    init(defaultResamplerSettings: IOAudioResamplerSettings) {
        self.defaultResamplerSettings = defaultResamplerSettings
        self.resamplersSettings = [
            mainTrack: defaultResamplerSettings
        ]
    }

    init(resamplersSettings: [Int: IOAudioResamplerSettings] = [:]) {
        let defaultSettings = resamplersSettings[mainTrack] ?? .init()
        self.defaultResamplerSettings = defaultSettings
        self.resamplersSettings = resamplersSettings.merging([mainTrack: defaultSettings]) { _, settings in
            settings
        }
    }

    func resamplerSettings(track: Int, sampleRate: Float64, channels: UInt32) -> IOAudioResamplerSettings {
        let preferredSettings = resamplersSettings[track] ?? .init()
        return .init(
            sampleRate: sampleRate,
            channels: channels,
            downmix: preferredSettings.downmix,
            channelMap: preferredSettings.channelMap
        )
    }
}

protocol IOAudioMixerConvertible: AnyObject {
    var inputFormat: AVAudioFormat? { get }
    var settings: IOAudioMixerSettings { get set }

    func append(_ buffer: CMSampleBuffer, track: UInt8)
    func append(_ buffer: AVAudioPCMBuffer, when: AVAudioTime, track: UInt8)
}
