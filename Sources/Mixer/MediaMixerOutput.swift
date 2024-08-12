import AVFoundation

public protocol MediaMixerOutput: AnyObject, Sendable {
    func mixer(_ mixer: MediaMixer, track: UInt8, didOutput sampleBuffer: CMSampleBuffer)
    func mixer(_ mixer: MediaMixer, track: UInt8, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime)
}
