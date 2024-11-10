@preconcurrency import AVFoundation

enum AudioMixerError: Swift.Error {
    /// Mixer is failed to create the AVAudioConverter.
    case failedToCreate(from: AVAudioFormat?, to: AVAudioFormat?)
    /// Mixer is faild to convert the an audio buffer.
    case failedToConvert(error: NSError)
    /// Mixer is unable to provide input data.
    case unableToProvideInputData
    /// Mixer is failed to mix the audio buffers.
    case failedToMix(error: any Error)
}

protocol AudioMixerDelegate: AnyObject {
    func audioMixer(_ audioMixer: some AudioMixer, track: UInt8, didInput buffer: AVAudioPCMBuffer, when: AVAudioTime)
    func audioMixer(_ audioMixer: some AudioMixer, didOutput audioFormat: AVAudioFormat)
    func audioMixer(_ audioMixer: some AudioMixer, didOutput audioBuffer: AVAudioPCMBuffer, when: AVAudioTime)
    func audioMixer(_ audioMixer: some AudioMixer, errorOccurred error: AudioMixerError)
}

protocol AudioMixer: AnyObject {
    var delegate: (any AudioMixerDelegate)? { get set }
    var settings: AudioMixerSettings { get set }
    var inputFormats: [UInt8: AVAudioFormat] { get }
    var outputFormat: AVAudioFormat? { get }

    func append(_ track: UInt8, buffer: CMSampleBuffer)
    func append(_ track: UInt8, buffer: AVAudioPCMBuffer, when: AVAudioTime)
}
