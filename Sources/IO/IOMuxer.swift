import AVFoundation
import Foundation

/// A type that multiplexer for streaming.
public protocol IOMuxer: Runner, AnyObject {
    /// Specifies the audioFormat.
    var audioFormat: AVAudioFormat? { get set }
    /// Specifies the videoFormat.
    var videoFormat: CMFormatDescription? { get set }

    /// Appends an audio.
    func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime)

    /// Appends a video or an audio.
    func append(_ sampleBuffer: CMSampleBuffer)
}
