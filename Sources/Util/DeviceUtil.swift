import AVFoundation

#if os(iOS)
extension AVCaptureDevice.Format {
    @available(iOS, obsoleted: 13.0)
    var isMultiCamSupported: Bool {
        return false
    }
}
#elseif os(macOS)
extension AVCaptureDevice.Format {
    var isMultiCamSupported: Bool {
        return true
    }
}
#endif

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
    func isFrameRateSupported(_ frameRate: Float64) -> Bool {
        var durations: [CMTime] = []
        var frameRates: [Float64] = []
        for range in videoSupportedFrameRateRanges {
            if range.minFrameRate == range.maxFrameRate {
                durations.append(range.minFrameDuration)
                frameRates.append(range.maxFrameRate)
                continue
            }
            if range.contains(frameRate: frameRate) {
                return true
            }
            return false
        }
        let diff = frameRates.map { abs($0 - frameRate) }
        if let minElement: Float64 = diff.min() {
            for i in 0..<diff.count where diff[i] == minElement {
                return true
            }
        }
        return false
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
