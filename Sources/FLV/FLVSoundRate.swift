/// The type of flv supports audio sound rates.
public enum FLVSoundRate: UInt8 {
    /// The sound rate of  5,500.0kHz.
    case kHz5_5 = 0
    /// Ths sound rate of 11,000.0kHz.
    case kHz11 = 1
    /// The sound rate of 22,050.0kHz.
    case kHz22 = 2
    /// Ths sound rate of 44,100.0kHz.
    case kHz44 = 3

    /// The float typed value.
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
