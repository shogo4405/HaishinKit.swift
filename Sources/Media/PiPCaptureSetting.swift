import CoreMedia
import Foundation

/// The PiPCaptureSetting represents the pip capture settings for the video capture.
@available(macOS, unavailable)
@available(tvOS, unavailable)
public struct PiPCaptureSetting {
    public static let `default` = PiPCaptureSetting(
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
