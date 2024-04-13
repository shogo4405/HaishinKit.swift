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
    let channel: Int = 0
    let defaultResamplerSettings: IOAudioResamplerSettings
    let resamplersSettings: [Int: IOAudioResamplerSettings]

    init(defaultResamplerSettings: IOAudioResamplerSettings) {
        self.defaultResamplerSettings = defaultResamplerSettings
        self.resamplersSettings = [
            channel: defaultResamplerSettings
        ]
    }

    init(resamplersSettings: [Int: IOAudioResamplerSettings] = [:]) {
        let defaultSettings = resamplersSettings[channel] ?? .init()
        self.defaultResamplerSettings = defaultSettings
        self.resamplersSettings = resamplersSettings.merging([channel: defaultSettings]) { _, settings in
            settings
        }
    }

    func resamplerSettings(channel: Int, sampleRate: Float64, channels: UInt32) -> IOAudioResamplerSettings {
        let preferredSettings = resamplersSettings[channel] ?? .init()
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

    func append(_ buffer: CMSampleBuffer, channel: UInt8)
    func append(_ buffer: AVAudioPCMBuffer, when: AVAudioTime, channel: UInt8)
}
