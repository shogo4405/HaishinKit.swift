import Accelerate
import CoreMedia
import Foundation

@available(*, deprecated, renamed: "IOVideoMixerSettings")
public typealias MultiCamCaptureSettings = IOVideoMixerSettings

/// The IOVideoMixerSettings represents the pip capture settings for the video capture.
public struct IOVideoMixerSettings: Codable {
    /// The type of image display mode.
    public enum Mode: String, Codable {
        /// The picture in picture mode means video stream playing within an inset window, freeing the rest of the screen for other tasks.
        case pip
        /// The split view means video stream playing within two individual windows.
        case splitView
    }

    /// The default setting for the stream.
    public static let `default` = IOVideoMixerSettings(
        mode: .pip,
        cornerRadius: 16.0,
        regionOfInterest: .init(
            origin: CGPoint(x: 16, y: 16),
            size: .init(width: 160, height: 160)
        ),
        direction: .east
    )

    /// The image display mode.
    public let mode: Mode
    /// The cornerRadius of the picture in picture image.
    public let cornerRadius: CGFloat
    /// The region of the picture in picture image.
    public let regionOfInterest: CGRect
    /// The direction of the splitView position.
    public let direction: ImageTransform
    /// Specifies the main channel number.
    public var channel: UInt8 = 0
    /// Specifies if effects are always rendered to a new buffer.
    public var alwaysUseBufferPoolForVideoEffects: Bool = false

    /// Create a new IOVideoMixerSettings.
    public init(mode: Mode, cornerRadius: CGFloat, regionOfInterest: CGRect, direction: ImageTransform) {
        self.mode = mode
        self.cornerRadius = cornerRadius
        self.regionOfInterest = regionOfInterest
        self.direction = direction
    }
}
