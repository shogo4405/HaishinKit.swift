import AVFAudio
import AVFoundation
import CoreImage
import CoreMedia

/// The interface is the foundation of the RTMPStream and SRTStream.
public protocol HKStream: Actor, MediaMixerOutput {
    /// The current state of the stream.
    var readyState: HKStreamReadyState { get }
    /// The sound transform value control.
    var soundTransform: SoundTransform? { get async }
    /// The audio compression properties.
    var audioSettings: AudioCodecSettings { get }
    /// The video compression properties.
    var videoSettings: VideoCodecSettings { get }

    /// Sets the bitrate storategy object.
    func setBitrateStorategy(_ bitrateStorategy: (some HKStreamBitRateStrategy)?)

    /// Sets the audio compression properties.
    func setAudioSettings(_ audioSettings: AudioCodecSettings)

    /// Sets the video compression properties.
    func setVideoSettings(_ videoSettings: VideoCodecSettings)

    /// Sets the sound transform value control.
    func setSoundTransform(_ soundTransfrom: SoundTransform) async

    /// Sets the video input buffer counts.
    func setVideoInputBufferCounts(_ videoInputBufferCounts: Int)

    /// Appends a CMSampleBuffer.
    /// - Parameters:
    ///   - sampleBuffer:The sample buffer to append.
    func append(_ sampleBuffer: CMSampleBuffer)

    /// Appends an AVAudioBuffer.
    /// - Parameters:
    ///   - audioBuffer:The audio buffer to append.
    ///   - when: The audio time to append.
    func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime)

    /// Attaches an audio player instance for playback.
    func attachAudioPlayer(_ audioPlayer: AudioPlayer?) async

    /// Adds an output observer.
    func addOutput(_ obserber: some HKStreamOutput)

    /// Removes an output observer.
    func removeOutput(_ observer: some HKStreamOutput)

    /// Dispatch a network monitor event.
    func dispatch(_ event: NetworkMonitorEvent) async
}
