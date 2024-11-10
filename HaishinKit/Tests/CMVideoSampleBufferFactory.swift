import AVFoundation
import Foundation

enum CMVideoSampleBufferFactory {
    static func makeSampleBuffer(width: Int, height: Int) -> CMSampleBuffer? {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        guard let pixelBuffer else {
            return nil
        }
        var outputFormat: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &outputFormat
        )
        guard let outputFormat else {
            return nil
        }
        var timingInfo = CMSampleTimingInfo()
        var sampleBuffer: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: outputFormat,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        ) == noErr else {
            return nil
        }
        return sampleBuffer
    }
}
