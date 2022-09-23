import Foundation
import VideoToolbox

extension VTDecompressionSession: VTSessionConvertible {
    func inputBuffer(_ imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime, outputHandler: @escaping VTCompressionOutputHandler) {
    }

    func invalidate() {
        VTDecompressionSessionInvalidate(self)
    }
}
