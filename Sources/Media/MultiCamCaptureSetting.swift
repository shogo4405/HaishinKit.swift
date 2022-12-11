import Accelerate
import CoreMedia
import Foundation

/// The MultiCamCaptureSetting represents the pip capture settings for the video capture.
public struct MultiCamCaptureSetting {
    public enum TransformDirection {
        case north
        case south
        case east
        case west

        var transformDirection: vImage_Buffer.TransformDirection {
            switch self {
            case .north:
                return .north
            case .south:
                return .south
            case .east:
                return .east
            case .west:
                return .west
            }
        }
    }

    public enum Mode {
        case pip
        case split(direction: TransformDirection)
    }

    public static let `default` = MultiCamCaptureSetting(
        mode: .pip,
        cornerRadius: 16.0,
        regionOfInterest: .init(
            origin: CGPoint(x: 16, y: 16),
            size: .init(width: 160, height: 160)
        )
    )

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
