import Foundation

/// The type of flv tag.
enum FLVTagType: UInt8 {
    /// The Audio tag,
    case audio = 8
    /// The Video tag.
    case video = 9
    /// The Data tag.
    case data = 18

    var streamId: UInt16 {
        switch self {
        case .audio, .video:
            return UInt16(rawValue)
        case .data:
            return 0
        }
    }

    var headerSize: Int {
        switch self {
        case .audio:
            return 2
        case .video:
            return 5
        case .data:
            return 0
        }
    }
}
