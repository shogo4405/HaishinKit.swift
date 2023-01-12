import Accelerate
import CoreMedia
import Foundation

/// The MultiCamCaptureSetting represents the pip capture settings for the video capture.
public struct MultiCamCaptureSetting {
    /// The type of image display mode.
    public enum Mode {
        /// The picture in picture mode means video stream playing within an inset window, freeing the rest of the screen for other tasks.
        case pip
        /// The split view means video stream playing within two individual windows.
        case splitView(direction: ImageTransform)
    }

    /// The default setting for the stream.
    public static let `default` = MultiCamCaptureSetting(
        mode: .pip,
        cornerRadius: 16.0,
        regionOfInterest: .init(
            origin: CGPoint(x: 16, y: 16),
            size: .init(width: 160, height: 160)
        )
    )

    /// The image display mode.
    public let mode: Mode
    /// The cornerRadius of the picture in picture image.
    public let cornerRadius: CGFloat
    /// The region of the picture in picture image.
    public let regionOfInterest: CGRect

    /// Create a new MultiCamCaptureSetting.
    public init(mode: Mode, cornerRadius: CGFloat, regionOfInterest: CGRect) {
        self.mode = mode
        self.cornerRadius = cornerRadius
        self.regionOfInterest = regionOfInterest
    }
}
