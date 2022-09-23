import Foundation
import VideoToolbox

extension VTDecompressionSession: VTSessionConvertible {
    static let defaultDecodeFlags: VTDecodeFrameFlags = [
        ._EnableAsynchronousDecompression,
        ._EnableTemporalProcessing
    ]

    func inputBuffer(_ imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime, outputHandler: @escaping VTCompressionOutputHandler) {
    }

    func inputBuffer(_ sampleBuffer: CMSampleBuffer, outputHandler: @escaping VTDecompressionOutputHandler) {
        var flagsOut: VTDecodeInfoFlags = []
        VTDecompressionSessionDecodeFrame(
            self,
            sampleBuffer: sampleBuffer,
            flags: Self.defaultDecodeFlags,
            infoFlagsOut: &flagsOut,
            outputHandler: outputHandler
        )
    }

    func invalidate() {
        VTDecompressionSessionInvalidate(self)
    }
}
