#if os(iOS) || os(macOS)
import CoreMedia
import Foundation

/// The MultiCamCaptureSetting represents the pip capture settings for the video capture.
public struct MultiCamCaptureSetting {
    public static let `default` = MultiCamCaptureSetting(
        regionOfInterest: .init(
            origin: CGPoint(x: 16, y: 16),
            size: .init(width: 160, height: 160)
        )
    )

    /// The region of the picture in picture image.
    public let regionOfInterest: CGRect

    /// Create a new PiPCaptureSetting.
    public init(regionOfInterest: CGRect) {
        self.regionOfInterest = regionOfInterest
    }
}
#endif
