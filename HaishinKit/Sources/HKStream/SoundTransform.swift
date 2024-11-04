import AVFoundation
import Foundation

/// A structure represents the volume value controller.
public struct SoundTransform: Equatable, Sendable {
    /// The default volume.
    public static let defaultVolume: Float = 1.0
    /// The default panning of the sound.
    public static let defaultPan: Float = 0

    /// The volume, ranging from 0 (silent) to 1 (full volume)
    public var volume = SoundTransform.defaultVolume
    /// The panning of the sound
    public var pan = SoundTransform.defaultPan

    /// Creates a new instance.
    public init(volume: Float = SoundTransform.defaultVolume, pan: Float = SoundTransform.defaultPan) {
        self.volume = volume
        self.pan = pan
    }

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
