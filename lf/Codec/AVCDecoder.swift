import Foundation
import AVFoundation
import VideoToolbox
import CoreFoundation

// MARK: - AVCDecoder
final class AVCDecoder: NSObject {
    static let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferIOSurfacePropertiesKey: [:],
        kCVPixelBufferOpenGLESCompatibilityKey: true,
    ]

    var running:Bool = false
    var lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.AVCDecoder.lock", DISPATCH_QUEUE_SERIAL
    )
    var formatDescription:CMFormatDescriptionRef? = nil {
        didSet {
            invalidateSession = true
        }
    }
    weak var delegate:VideoDecoderDelegate?

    private var attributes:[NSString:  AnyObject] {
        return AVCDecoder.defaultAttributes
    }

    private var invalidateSession:Bool = true
    private var callback:VTDecompressionOutputCallback = {(
        decompressionOutputRefCon:UnsafeMutablePointer<Void>,
        sourceFrameRefCon:UnsafeMutablePointer<Void>,
        status:OSStatus,
        infoFlgas:VTDecodeInfoFlags,
        imageBuffer:CVImageBufferRef?,
        presentationTimeStamp:CMTime,
        presentationDuration:CMTime) in
        guard status == noErr else {
            logger.error("\(status)")
            return
        }
        let decoder:AVCDecoder = unsafeBitCast(decompressionOutputRefCon, AVCDecoder.self)
        decoder.delegate?.imageOutput(imageBuffer!,
            presentationTimeStamp: presentationTimeStamp,
            presentationDuration: presentationDuration
        )
    }

    private var _session:VTDecompressionSessionRef? = nil
    private var session:VTDecompressionSessionRef! {
        get {
            if (_session == nil)  {
                guard let formatDescription:CMFormatDescriptionRef = formatDescription else {
                    return nil
                }
                var record:VTDecompressionOutputCallbackRecord = VTDecompressionOutputCallbackRecord(
                    decompressionOutputCallback: callback,
                    decompressionOutputRefCon: unsafeBitCast(self, UnsafeMutablePointer<Void>.self)
                )
                guard VTDecompressionSessionCreate(
                    kCFAllocatorDefault,
                    formatDescription,
                    nil,
                    attributes,
                    &record,
                    &_session ) == noErr else {
                    return nil
                }
                invalidateSession = false
            }
            return _session!
        }
        set {
            if let session:VTDecompressionSessionRef = _session {
                VTDecompressionSessionInvalidate(session)
            }
            _session = newValue
        }
    }

    func decodeSampleBuffer(sampleBuffer:CMSampleBuffer) -> OSStatus {
        guard let session:VTDecompressionSession = session else {
            return kVTInvalidSessionErr
        }
        var decodeFlags:VTDecodeFrameFlags = ._EnableAsynchronousDecompression
        var flagsOut:VTDecodeInfoFlags = VTDecodeInfoFlags()
        return VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer,
            decodeFlags,
            nil,
            &flagsOut
        )
    }
}
