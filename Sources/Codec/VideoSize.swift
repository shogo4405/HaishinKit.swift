import Foundation

/// The VideoSize class represents video width and height.
public struct VideoSize: Equatable, Codable {
    /// The video width.
    public let width: Int32
    /// The video height.
    public let height: Int32

    /// Creates a VideoSize object.
    public init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
    }

    /// Swap width for height.
    public func swap() -> VideoSize {
        return VideoSize(width: height, height: width)
    }
}
