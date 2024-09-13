import AVFoundation

/// A delegate protocol implements to receive stream output events.
public protocol MediaMixerOutput: AnyObject, Sendable {
    /// Tells the receiver to a video track id.
    var videoTrackId: UInt8? { get async }
    /// Tells the receiver to an audio track id.
    var audioTrackId: UInt8? { get async }
    /// Tells the receiver to a video buffer incoming.
    func mixer(_ mixer: MediaMixer, didOutput sampleBuffer: CMSampleBuffer)
    /// Tells the receiver to an audio buffer incoming.
    func mixer(_ mixer: MediaMixer, didOutput buffer: AVAudioPCMBuffer, when: AVAudioTime)
    /// Selects track id for streaming.
    func selectTrack(_ id: UInt8?, mediaType: CMFormatDescription.MediaType) async
}
