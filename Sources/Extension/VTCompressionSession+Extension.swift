import Foundation
import VideoToolbox

extension VTCompressionSession: VTSessionConvertible {
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

    func invalidate() {
        VTCompressionSessionInvalidate(self)
    }
}

extension VTCompressionSession {
    func prepareToEncodeFrame() -> OSStatus {
        VTCompressionSessionPrepareToEncodeFrames(self)
    }
}
