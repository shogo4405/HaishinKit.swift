public enum FLVSoundRate: UInt8 {
    case kHz5_5 = 0
    case kHz11 = 1
    case kHz22 = 2
    case kHz44 = 3

    public var floatValue: Float64 {
        switch self {
        case .kHz5_5:
            return 5500
        case .kHz11:
            return 11025
        case .kHz22:
            return 22050
        case .kHz44:
            return 44100
        }
    }
}
