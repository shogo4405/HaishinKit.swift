import AVFoundation

#if os(iOS) || os(macOS)
extension AVFrameRateRange {
    func clamp(rate: Float64) -> Float64 {
        max(minFrameRate, min(maxFrameRate, rate))
    }

    func contains(frameRate: Float64) -> Bool {
        (minFrameRate...maxFrameRate) ~= frameRate
    }
}

extension AVCaptureDevice.Format {
    func getFrameRate(_ frameRate: Float64) -> CMTime? {
        var durations: [CMTime] = []
        var frameRates: [Float64] = []
        for range in videoSupportedFrameRateRanges {
            if range.minFrameRate == range.maxFrameRate {
                durations.append(range.minFrameDuration)
                frameRates.append(range.maxFrameRate)
                continue
            }
            if range.contains(frameRate: frameRate) {
                return CMTimeMake(value: 100, timescale: Int32(100 * frameRate))
            }
            return CMTimeMake(value: 100, timescale: Int32(100 * range.clamp(rate: frameRate)))
        }
        let diff = frameRates.map { abs($0 - frameRate) }
        if let minElement: Float64 = diff.min() {
            for i in 0..<diff.count where diff[i] == minElement {
                return durations[i]
            }
        }
        return nil
    }
}

/// The namespace of DeviceUtil.
public enum DeviceUtil {
    /// Lookup device by localizedName and mediaType.
    public static func device(withLocalizedName: String, mediaType: AVMediaType) -> AVCaptureDevice? {
        AVCaptureDevice.devices().first {
            $0.hasMediaType(mediaType) && $0.localizedName == withLocalizedName
        }
    }
}
#endif
