import AVFoundation
import Foundation

@available(tvOS 17.0, *)
extension AVFrameRateRange {
    func clamp(rate: Float64) -> Float64 {
        max(minFrameRate, min(maxFrameRate, rate))
    }

    func contains(frameRate: Float64) -> Bool {
        (minFrameRate...maxFrameRate) ~= frameRate
    }
}
