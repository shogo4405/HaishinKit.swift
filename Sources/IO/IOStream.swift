import AVFAudio
import AVFoundation
import CoreImage
import CoreMedia
#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif
#if canImport(UIKit)
import UIKit
#endif

public protocol IOStream: Actor {
    /// The current state of the stream.
    var readyState: IOStreamReadyState { get async }

    /// Specifies the audio compression properties.
    var audioSettings: AudioCodecSettings { get async }

    /// Sets the audio compression properties.
    func setAudioSettings(_ audioSettings: AudioCodecSettings) async

    /// Specifies the video compression properties.
    var videoSettings: VideoCodecSettings { get async }

    /// Sets the video compression properties.
    func setVideoSettings(_ videoSettings: VideoCodecSettings) async

    /// Attaches an AVAudioEngine instance for playback.
    func attachAudioEngine(_ audioEngine: AVAudioEngine?) async

    /// Appends a CMSampleBuffer.
    /// - Parameters:
    ///   - sampleBuffer:The sample buffer to append.
    func append(_ sampleBuffer: CMSampleBuffer) async

    /// Appends an AVAudioBuffer.
    /// - Parameters:
    ///   - audioBuffer:The audio buffer to append.
    ///   - when: The audio time to append.
    ///   - track: Track number used for mixing.
    func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) async

    func addObserver(_ obserber: some IOStreamObserver) async

    func removeObserver(_ observer: some IOStreamObserver) async
}


/// The enumeration defines the state an IOStream client is in.
public enum IOStreamReadyState: Int, Sendable, Equatable {
    case idle
    case play
    case playing
    case publish
    case publishing
}
