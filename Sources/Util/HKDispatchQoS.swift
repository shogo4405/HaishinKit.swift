import Foundation

public enum HKDispatchQoS: Int, Sendable {
    case userInteractive
    case userInitiated
    case `default`
    case utility
    case background
    case unspecified

    internal var dispatchOos: DispatchQoS {
        switch self {
        case .userInteractive:
            return .userInitiated
        case .userInitiated:
            return .userInitiated
        case .`default`:
            return .default
        case .utility:
            return .utility
        case .background:
            return .background
        case .unspecified:
            return .unspecified
        }
    }
}
