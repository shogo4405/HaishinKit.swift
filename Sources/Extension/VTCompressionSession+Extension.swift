import Foundation
import VideoToolbox

extension VTCompressionSession {
    func prepareToEncodeFrames() -> OSStatus {
        VTCompressionSessionPrepareToEncodeFrames(self)
    }
}

extension VTCompressionSession: VTSessionConvertible {
    // MARK: VTSessionConvertible
    @discardableResult
    @inline(__always)
    func encodeFrame(_ imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime, outputHandler: @escaping VTCompressionOutputHandler) -> OSStatus {
        var flags: VTEncodeInfoFlags = []
        return VTCompressionSessionEncodeFrame(
            self,
            imageBuffer: imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: duration,
            frameProperties: nil,
            infoFlagsOut: &flags,
            outputHandler: outputHandler
        )
    }

    @discardableResult
    @inline(__always)
    func decodeFrame(_ sampleBuffer: CMSampleBuffer, outputHandler: @escaping VTDecompressionOutputHandler) -> OSStatus {
        return noErr
    }

    func invalidate() {
        VTCompressionSessionInvalidate(self)
    }
}
