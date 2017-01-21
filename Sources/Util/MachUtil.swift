import Foundation

public struct MachUtil {
    static public let nanosPerUsec:UInt64 = 1000
    static public let nanosPerMsec:UInt64 = 1000 * 1000
    static public let nanosPerSec:UInt64 = 1000 * 1000 * 1000

    private static var timebase:mach_timebase_info_data_t = {
        var timebase:mach_timebase_info_data_t = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return timebase
    }()

    static public func nanosToAbs(_ nanos:UInt64) -> UInt64 {
        return nanos * UInt64(timebase.denom) / UInt64(timebase.numer)
    }

    static public func absToNanos(_ abs:UInt64) -> UInt64 {
        return abs * UInt64(timebase.numer) / UInt64(timebase.denom)
    }
}
