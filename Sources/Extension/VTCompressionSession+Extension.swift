import Foundation
import VideoToolbox

extension VTCompressionSession {
    func prepareToEncodeFrames() -> OSStatus {
        VTCompressionSessionPrepareToEncodeFrames(self)
    }
}

extension VTCompressionSession: VTSessionConvertible {
    @discardableResult
    @inline(__always)
    func convert(_ sampleBuffer: CMSampleBuffer) async throws -> CMSampleBuffer {
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            throw VTSessionError.failedToConvert(status: kVTParameterErr)
        }
        return try await withCheckedThrowingContinuation { continuation in
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
                        continuation.resume(returning: sampleBuffer)
                    } else {
                        continuation.resume(throwing: VTSessionError.failedToConvert(status: status))
                    }
                }
            )
        }
    }

    func invalidate() {
        VTCompressionSessionInvalidate(self)
    }
}
