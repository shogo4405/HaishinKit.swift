import AVFoundation

/// The IOAudioMixerError  error domain codes.
enum AudioMixerError: Swift.Error {
    /// Mixer is unable to provide input data.
    case unableToProvideInputData
}

protocol AudioMixerDelegate: AnyObject {
    func audioMixer(_ audioMixer: some AudioMixer, track: UInt8, didInput buffer: AVAudioPCMBuffer, when: AVAudioTime)
    func audioMixer(_ audioMixer: some AudioMixer, didOutput audioFormat: AVAudioFormat)
    func audioMixer(_ audioMixer: some AudioMixer, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime)
    func audioMixer(_ audioMixer: some AudioMixer, errorOccurred error: IOAudioUnitError)
}

protocol AudioMixer: AnyObject {
    var delegate: (any AudioMixerDelegate)? { get set }
    var settings: AudioMixerSettings { get set }
    var inputFormats: [UInt8: AVAudioFormat] { get }
    var outputFormat: AVAudioFormat? { get }

    func append(_ track: UInt8, buffer: CMSampleBuffer)
    func append(_ track: UInt8, buffer: AVAudioPCMBuffer, when: AVAudioTime)
}
