import Foundation

public struct MachUtil {
    public static let nanosPerUsec: UInt64 = 1000
    public static let nanosPerMsec: UInt64 = 1000 * 1000
    public static let nanosPerSec: UInt64 = 1000 * 1000 * 1000

    private static var timebase: mach_timebase_info_data_t = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return timebase
    }()

    public static func nanosToAbs(_ nanos: UInt64) -> UInt64 {
        nanos * UInt64(timebase.denom) / UInt64(timebase.numer)
    }

    public static func absToNanos(_ abs: UInt64) -> UInt64 {
        abs * UInt64(timebase.numer) / UInt64(timebase.denom)
    }
}
