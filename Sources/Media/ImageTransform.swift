import Foundation

/// The type of image transform direction.
public enum ImageTransform: String, Codable {
    /// The north direction.
    case north
    /// The south direction.
    case south
    /// The east direciton.
    case east
    /// The west direction.
    case west

    var opposite: ImageTransform {
        switch self {
        case .north:
            return .south
        case .south:
            return .north
        case .east:
            return .west
        case .west:
            return .east
        }
    }

    func tx(_ width: Double) -> Double {
        switch self {
        case .north:
            return 0.0
        case .south:
            return Double.leastNonzeroMagnitude
        case .east:
            return width / 4.0
        case .west:
            return -(width / 4.0)
        }
    }

    func ty(_ height: Double) -> Double {
        switch self {
        case .north:
            return height / 4.0
        case .south:
            return -(height / 4.0)
        case .east:
            return Double.leastNonzeroMagnitude
        case .west:
            return 0.0
        }
    }

    func makeRect(_ rect: CGRect) -> CGRect {
        switch self {
        case .north:
            return .init(origin: .init(x: 0, y: 0), size: .init(width: rect.width, height: rect.height / 2))
        case .south:
            return .init(origin: .init(x: 0, y: rect.height / 2), size: .init(width: rect.width, height: rect.height / 2))
        case .east:
            return .init(origin: .init(x: rect.width / 2, y: 0), size: .init(width: rect.width / 2, height: rect.height))
        case .west:
            return .init(origin: .init(x: 0, y: 0), size: .init(width: rect.width / 2, height: rect.height))
        }
    }
}
