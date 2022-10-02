import Foundation
import VideoToolbox

extension VTCompressionSession {
    func prepareToEncodeFrames() -> OSStatus {
        VTCompressionSessionPrepareToEncodeFrames(self)
    }
}

extension VTCompressionSession: VTSessionConvertible {
    // MARK: VTSessionConvertible
    func inputBuffer(_ imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime, outputHandler: @escaping VTCompressionOutputHandler) {
        var flags: VTEncodeInfoFlags = []
        VTCompressionSessionEncodeFrame(
            self,
            imageBuffer: imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: duration,
            frameProperties: nil,
            infoFlagsOut: &flags,
            outputHandler: outputHandler
        )
    }

    func inputBuffer(_ sampleBuffer: CMSampleBuffer, outputHandler: @escaping VTDecompressionOutputHandler) {
    }

    func invalidate() {
        VTCompressionSessionInvalidate(self)
    }
}
