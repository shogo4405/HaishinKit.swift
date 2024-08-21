import CoreImage
import Foundation
import ReplayKit
import VideoToolbox

/// This class allows to rotate image buffers that are provided by ReplayKit.
/// The buffers arrive in portrait orientation and contain buffer-level attachment
/// that allow to determine the target resolution and rotate the buffer accordingly.
@available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
public final class VideoRotator {
    /// VideoRotator domain errors
    public enum Error: Swift.Error {
        /// Provided buffer does not contain image buffer
        case noImageBuffer
        /// Provided buffer does not contain orientation attachment
        case noOrientationInfo
        /// Provided orientation is not supported
        case unsupportedOrientation
        /// Pixel buffer cannot be allocated
        case cannotAllocatePixelBuffer(CVReturn)
        /// Rotation session fails to rotate the image buffer
        case rotationFailure(OSStatus)
    }

    private var pixelInfo = PixelInfo.zero {
        didSet {
            guard pixelInfo != oldValue else {
                return
            }
            rotationPixelBuffer = nil
            pixelBufferStatus = CVPixelBufferCreate(
                kCFAllocatorDefault,
                pixelInfo.width,
                pixelInfo.height,
                pixelInfo.format,
                nil,
                &rotationPixelBuffer
            )
        }
    }
    private var rotationPixelBuffer: CVPixelBuffer?
    private var pixelBufferStatus: CVReturn = kCVReturnSuccess
    private let session: VTPixelRotationSession

    /// Creates a new instance.
    public init?() {
        var session: VTPixelRotationSession?
        let status = VTPixelRotationSessionCreate(kCFAllocatorDefault, &session)
        guard status == noErr, let session else {
            return nil
        }
        self.session = session
    }

    /// Rotates a sample buffer.
    public func rotate(buffer sampleBuffer: CMSampleBuffer) -> Result<CMSampleBuffer, Error> {
        guard let buffer = sampleBuffer.imageBuffer else {
            return .failure(.noImageBuffer)
        }
        try? buffer.lockBaseAddress()
        defer {
            try? buffer.unlockBaseAddress()
        }
        var orientation: CGImagePropertyOrientation?
        orientation = sampleBuffer.orientation
        guard let orientation else {
            return .failure(.noOrientationInfo)
        }
        guard orientation != .up else {
            return .success(sampleBuffer)
        }
        var status: OSStatus
        switch orientation {
        case .left:
            status = session.setOption(.init(key: .rotation, value: ._90))
        case .down:
            status = session.setOption(.init(key: .rotation, value: ._180))
        case .right:
            status = session.setOption(.init(key: .rotation, value: ._270))
        default:
            return .failure(.unsupportedOrientation)
        }
        guard status == noErr else {
            return .failure(.rotationFailure(status))
        }
        switch orientation {
        case .up, .down:
            pixelInfo = .init(width: buffer.width, height: buffer.height, format: buffer.formatType)
        case .left, .right:
            pixelInfo = .init(width: buffer.height, height: buffer.width, format: buffer.formatType)
        default:
            return .failure(.unsupportedOrientation)
        }
        guard let rotationPixelBuffer else {
            return .failure(.cannotAllocatePixelBuffer(pixelBufferStatus))
        }
        status = VTPixelRotationSessionRotateImage(session, buffer, rotationPixelBuffer)
        guard status == noErr else {
            return .failure(.rotationFailure(status))
        }
        var rotatedBuffer: CMSampleBuffer?
        (rotatedBuffer, status) = createSampleBuffer(sampleBuffer, imageBuffer: rotationPixelBuffer)
        guard let rotatedBuffer else {
            return .failure(.rotationFailure(status))
        }
        return .success(rotatedBuffer)
    }

    @inline(__always)
    private func createSampleBuffer(_ inSampleBuffer: CMSampleBuffer, imageBuffer: CVImageBuffer) -> (CMSampleBuffer?, OSStatus) {
        var info = CMSampleTimingInfo()
        info.presentationTimeStamp = inSampleBuffer.presentationTimeStamp
        info.duration = CMSampleBufferGetOutputDuration(inSampleBuffer)
        info.decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(inSampleBuffer)
        var formatDescription: CMFormatDescription?
        var status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescriptionOut: &formatDescription)
        guard status == noErr, let formatDescription else {
            return (nil, status)
        }
        var outSampleBuffer: CMSampleBuffer?
        status = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                          imageBuffer: imageBuffer,
                                                          formatDescription: formatDescription,
                                                          sampleTiming: &info,
                                                          sampleBufferOut: &outSampleBuffer)

        guard status == noErr, let outSampleBuffer else {
            return (nil, status)
        }
        return (outSampleBuffer, noErr)
    }
}

private struct PixelInfo: Hashable, Equatable, CustomStringConvertible {
    static let zero: PixelInfo = .init(width: 0, height: 0, format: 0)

    let width: Int
    let height: Int
    let format: OSType

    public var description: String {
        "PixelInfo(width: \(width), height: \(height), format: \(format))"
    }
}

@available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
private extension CMSampleBuffer {
    var orientation: CGImagePropertyOrientation? {
        get {
            guard let orientationAttachment = CMGetAttachment(
                    self,
                    key: RPVideoSampleOrientationKey as CFString,
                    attachmentModeOut: nil) as? NSNumber
            else { return nil }

            return CGImagePropertyOrientation(rawValue: orientationAttachment.uint32Value)
        }
        set {
            if let value = newValue {
                CMSetAttachment(self,
                                key: RPVideoSampleOrientationKey as CFString,
                                value: NSNumber(value: value.rawValue),
                                attachmentMode: kCMAttachmentMode_ShouldNotPropagate)
            } else {
                CMRemoveAttachment(self, key: RPVideoSampleOrientationKey as CFString)
            }
        }
    }
}
