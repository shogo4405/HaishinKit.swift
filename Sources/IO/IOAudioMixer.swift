import AVFoundation

/// The IOAudioMixerError  error domain codes.
public enum IOAudioMixerError: Swift.Error {
    /// Mixer is unable to provide input data.
    case unableToProvideInputData
    /// Mixer is unable to make sure that all resamplers output the same audio format.
    case unableToEnforceAudioFormat
}

protocol IOAudioMixerDelegate: AnyObject {
    func audioMixer(_ audioMixer: any IOAudioMixerConvertible, track: UInt8, didInput buffer: AVAudioPCMBuffer, when: AVAudioTime)
    func audioMixer(_ audioMixer: any IOAudioMixerConvertible, didOutput audioFormat: AVAudioFormat)
    func audioMixer(_ audioMixer: any IOAudioMixerConvertible, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime)
    func audioMixer(_ audioMixer: any IOAudioMixerConvertible, errorOccurred error: IOAudioUnitError)
}

protocol IOAudioMixerConvertible: AnyObject {
    var delegate: (any IOAudioMixerDelegate)? { get set }
    var settings: IOAudioMixerSettings { get set }
    var inputFormats: [UInt8: AVAudioFormat] { get }
    var outputFormat: AVAudioFormat? { get }

    func append(_ track: UInt8, buffer: CMSampleBuffer)
    func append(_ track: UInt8, buffer: AVAudioPCMBuffer, when: AVAudioTime)
}
