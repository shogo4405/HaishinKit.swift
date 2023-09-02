import AVFoundation
import Foundation

#if os(iOS) || os(macOS)
extension AVFrameRateRange {
    func clamp(rate: Float64) -> Float64 {
        max(minFrameRate, min(maxFrameRate, rate))
    }

    func contains(frameRate: Float64) -> Bool {
        (minFrameRate...maxFrameRate) ~= frameRate
    }
}
#endif
