import Foundation
import VideoToolbox

struct VTSessionHolder {
    private(set) var isInvalidateSession = false
    private(set) var session: VTSessionConvertible?

    mutating func makeSession(_ videoCodec: VideoCodec) -> OSStatus {
        session?.invalidate()
        session = nil
        var session: VTCompressionSession?
        var status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: videoCodec.width,
            height: videoCodec.height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )
        guard status == noErr, let session else {
            videoCodec.delegate?.videoCodec(videoCodec, errorOccurred: .failedToCreate(status: status))
            return status
        }
        status = session.setOptions(videoCodec.options())
        status = session.prepareToEncodeFrame()
        guard status == noErr else {
            videoCodec.delegate?.videoCodec(videoCodec, errorOccurred: .failedToPrepare(status: status))
            return status
        }
        self.session = session
        isInvalidateSession = false
        return noErr
    }

    mutating func invalidateSession() {
        isInvalidateSession = true
    }
}
