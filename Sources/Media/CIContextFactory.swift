import Foundation

public protocol CIContextFactory {
    func create() -> CIContext?
}

public enum DefaultCIContextFactory: CIContextFactory {
    case none

    public func create() -> CIContext? {
        switch self {
        case .none:
            return nil
        }
    }
}
