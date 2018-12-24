import Foundation
import AVFoundation

/// The SoundTransform class
public struct SoundTransform {
    static public let defaultVolume: Float = 1.0
    static public let defaultPan: Float = 0

    /// The volume, ranging from 0 (silent) to 1 (full volume)
    public var volume = SoundTransform.defaultVolume
    /// The panning of the sound
    public var pan = SoundTransform.defaultPan

    func apply(_ playerNode: AVAudioPlayerNode?) {
        playerNode?.volume = volume
        playerNode?.pan = pan
    }
}
