import AVFAudio
import AVFoundation
import CoreImage
import CoreMedia

/// The interface is the foundation of the RTMPStream and SRTStream.
public protocol HKStream: Actor, IOMixerOutput {
    /// The current state of the stream.
    var readyState: HKStreamReadyState { get }

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

    /// Appends a CMSampleBuffer.
    /// - Parameters:
    ///   - sampleBuffer:The sample buffer to append.
    func append(_ sampleBuffer: CMSampleBuffer)

    /// Appends an AVAudioBuffer.
    /// - Parameters:
    ///   - audioBuffer:The audio buffer to append.
    ///   - when: The audio time to append.
    func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime)

    /// Adds an output observer.
    func addOutput(_ obserber: some HKStreamOutput)

    /// Removes an output observer.
    func removeOutput(_ observer: some HKStreamOutput)

    /// Attaches an audio player instance for playback.
    func attachAudioPlayer(_ audioPlayer: AudioPlayer?)

    /// Dispatch a network monitor event.
    func dispatch(_ event: NetworkMonitorEvent)
}

/// The enumeration defines the state a HKStream client is in.
public enum HKStreamReadyState: Int, Sendable {
    /// The stream is idling.
    case idle
    /// The stream has sent a request to play and is waiting for approval from the server.
    case play
    /// The stream is playing.
    case playing
    /// The streamhas sent a request to publish and is waiting for approval from the server.
    case publish
    /// The stream is publishing.
    case publishing
}
