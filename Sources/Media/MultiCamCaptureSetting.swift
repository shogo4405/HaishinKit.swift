import CoreMedia
import Foundation

/// The MultiCamCaptureSetting represents the pip capture settings for the video capture.
public struct MultiCamCaptureSetting {
    public static let `default` = MultiCamCaptureSetting(
        cornerRadius: 16.0,
        regionOfInterest: .init(
            origin: CGPoint(x: 16, y: 16),
            size: .init(width: 160, height: 160)
        )
    )

    /// The cornerRadius of the picture in picture image.
    public let cornerRadius: CGFloat
    /// The region of the picture in picture image.
    public let regionOfInterest: CGRect

    /// Create a new MultiCamCaptureSetting.
    public init(cornerRadius: CGFloat, regionOfInterest: CGRect) {
        self.cornerRadius = cornerRadius
        self.regionOfInterest = regionOfInterest
    }
}
