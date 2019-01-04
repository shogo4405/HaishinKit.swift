import Foundation

public enum FLVVideoCodec: UInt8 {
    case sorensonH263 = 2
    case screen1 = 3
    case on2VP6 = 4
    case on2VP6Alpha = 5
    case screen2 = 6
    case avc = 7
    case unknown = 0xFF

    var isSupported: Bool {
        switch self {
        case .sorensonH263:
            return false
        case .screen1:
            return false
        case .on2VP6:
            return false
        case .on2VP6Alpha:
            return false
        case .screen2:
            return false
        case .avc:
            return true
        case .unknown:
            return false
        }
    }
}
