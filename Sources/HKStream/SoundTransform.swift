import AVFoundation
import Foundation

/// The SoundTransform class
public struct SoundTransform {
    public static let defaultVolume: Float = 1.0
    public static let defaultPan: Float = 0

    /// The volume, ranging from 0 (silent) to 1 (full volume)
    public var volume = SoundTransform.defaultVolume
    /// The panning of the sound
    public var pan = SoundTransform.defaultPan

    func apply(_ playerNode: AVAudioPlayerNode?) {
        playerNode?.volume = volume
        playerNode?.pan = pan
    }
}

extension SoundTransform: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    public var debugDescription: String {
        Mirror(reflecting: self).debugDescription
    }
}
