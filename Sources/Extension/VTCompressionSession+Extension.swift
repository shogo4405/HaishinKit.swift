import Foundation
import VideoToolbox

extension VTCompressionSession {
    func prepareToEncodeFrames() -> OSStatus {
        VTCompressionSessionPrepareToEncodeFrames(self)
    }
}

extension VTCompressionSession: VTSessionConvertible {
    @inline(__always)
    func convert(_ sampleBuffer: CMSampleBuffer, continuation: AsyncThrowingStream<CMSampleBuffer, any Error>.Continuation?) {
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            continuation?.finish(throwing: VTSessionError.failedToConvert(status: kVTParameterErr))
            return
        }
        var flags: VTEncodeInfoFlags = []
        VTCompressionSessionEncodeFrame(
            self,
            imageBuffer: imageBuffer,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            duration: sampleBuffer.duration,
            frameProperties: nil,
            infoFlagsOut: &flags,
            outputHandler: { status, _, sampleBuffer in
                if let sampleBuffer {
                    continuation?.yield(sampleBuffer)
                } else {
                    continuation?.finish(throwing: VTSessionError.failedToConvert(status: status))
                }
            }
        )
    }

    func invalidate() {
        VTCompressionSessionInvalidate(self)
    }
}
