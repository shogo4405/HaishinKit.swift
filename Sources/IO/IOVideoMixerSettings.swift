import Accelerate
import CoreMedia
import Foundation

/// Constraints on the audio mixier settings.
public struct IOVideoMixerSettings: Codable {
    /// The default setting for the stream.
    public static let `default`: IOVideoMixerSettings = .init()

    /// The type of image rendering mode.
    public enum Mode: String, Codable {
        /// The input buffer will be used as it is. No effects will be applied.
        case passthrough
        /// Off-screen rendering will be performed to allow for more flexible drawing.
        case offscreen
    }

    /// Specifies the image rendering mode.
    public var mode: Mode = .offscreen

    /// Specifies the muted indicies whether freeze video signal or not.
    public var isMuted = false

    /// Specifies the main track number.
    public var mainTrack: UInt8 = 0
}
