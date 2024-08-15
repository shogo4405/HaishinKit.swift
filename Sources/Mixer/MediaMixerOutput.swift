import AVFoundation

/// A delegate protocol implements to receive stream output events.
public protocol MediaMixerOutput: AnyObject, Sendable {
    /// Tells the receiver to a video buffer incoming.
    func mixer(_ mixer: MediaMixer, track: UInt8, didOutput sampleBuffer: CMSampleBuffer)
    /// Tells the receiver to an audio buffer incoming.
    func mixer(_ mixer: MediaMixer, track: UInt8, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime)
}
