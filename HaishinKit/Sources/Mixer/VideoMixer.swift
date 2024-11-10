import CoreImage
import CoreMedia
import Foundation

protocol VideoMixerDelegate: AnyObject {
    func videoMixer(_ videoMixer: VideoMixer<Self>, track: UInt8, didInput sampleBuffer: CMSampleBuffer)
    func videoMixer(_ videoMixer: VideoMixer<Self>, didOutput sampleBuffer: CMSampleBuffer)
}

private let kVideoMixer_lockFlags = CVPixelBufferLockFlags(rawValue: .zero)

final class VideoMixer<T: VideoMixerDelegate> {
    weak var delegate: T?
    var settings: VideoMixerSettings = .default
    private(set) var inputFormats: [UInt8: CMFormatDescription] = [:]
    private var currentPixelBuffer: CVPixelBuffer?

    func append(_ track: UInt8, sampleBuffer: CMSampleBuffer) {
        inputFormats[track] = sampleBuffer.formatDescription
        delegate?.videoMixer(self, track: track, didInput: sampleBuffer)
        switch settings.mode {
        case .offscreen:
            break
        case .passthrough:
            if settings.mainTrack == track {
                outputSampleBuffer(sampleBuffer)
            }
        }
    }

    func reset(_ track: UInt8) {
        inputFormats[track] = nil
    }

    @inline(__always)
    private func outputSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        defer {
            currentPixelBuffer = sampleBuffer.imageBuffer
        }
        guard settings.isMuted else {
            delegate?.videoMixer(self, didOutput: sampleBuffer)
            return
        }
        do {
            try sampleBuffer.imageBuffer?.mutate(kVideoMixer_lockFlags) { imageBuffer in
                try imageBuffer.copy(currentPixelBuffer)
            }
            delegate?.videoMixer(self, didOutput: sampleBuffer)
        } catch {
            logger.warn(error)
        }
    }
}
