import Foundation
import AVFoundation

#if os(iOS) || os(macOS)
public final class DeviceUtil {
    private init() {
    }

    static public func device(withPosition: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return AVCaptureDevice.devices().first {
            $0.hasMediaType(.video) && $0.position == withPosition
        }
    }

    static public func device(withLocalizedName: String, mediaType: AVMediaType) -> AVCaptureDevice? {
        return AVCaptureDevice.devices().first {
            $0.hasMediaType(mediaType) && $0.localizedName == withLocalizedName
        }
    }

    static func getActualFPS(_ fps: Float64, device: AVCaptureDevice) -> (fps: Float64, duration: CMTime)? {
        var durations: [CMTime] = []
        var frameRates: [Float64] = []

        for object: Any in device.activeFormat.videoSupportedFrameRateRanges {
            guard let range: AVFrameRateRange = object as? AVFrameRateRange else {
                continue
            }
            if range.minFrameRate == range.maxFrameRate {
                durations.append(range.minFrameDuration)
                frameRates.append(range.maxFrameRate)
                continue
            }
            if range.minFrameRate <= fps && fps <= range.maxFrameRate {
                return (fps, CMTimeMake(100, Int32(100 * fps)))
            }

            let actualFPS: Float64 = max(range.minFrameRate, min(range.maxFrameRate, fps))
            return (actualFPS, CMTimeMake(100, Int32(100 * actualFPS)))
        }

        var diff: [Float64] = []
        for frameRate in frameRates {
            diff.append(abs(frameRate - fps))
        }
        if let minElement: Float64 = diff.min() {
            for i in 0..<diff.count where diff[i] == minElement {
                return (frameRates[i], durations[i])
            }
        }

        return nil
    }
}
#endif
