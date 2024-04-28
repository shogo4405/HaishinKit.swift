import AVFoundation

/// The IOAudioMixerError  error domain codes.
enum IOAudioMixerError: Swift.Error {
    /// Mixer is unable to provide input data.
    case unableToProvideInputData
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
