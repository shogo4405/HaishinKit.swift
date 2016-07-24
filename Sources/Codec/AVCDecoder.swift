import CoreVideo
import Foundation
import AVFoundation
import VideoToolbox
import CoreFoundation

final class AVCDecoder {

    #if os(iOS)
    static let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferIOSurfacePropertiesKey: [:],
        kCVPixelBufferOpenGLESCompatibilityKey: true,
    ]
    #else
    static let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferIOSurfacePropertiesKey: [:],
        kCVPixelBufferOpenGLCompatibilityKey: true,
    ]
    #endif

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
        infoFlags:VTDecodeInfoFlags,
        imageBuffer:CVImageBufferRef?,
        presentationTimeStamp:CMTime,
        duration:CMTime) in
        let decoder:AVCDecoder = unsafeBitCast(decompressionOutputRefCon, AVCDecoder.self)
        decoder.didOutputForSession(status, infoFlags: infoFlags, imageBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, duration: duration)
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
        let decodeFlags:VTDecodeFrameFlags = VTDecodeFrameFlags(rawValue:
            VTDecodeFrameFlags._EnableAsynchronousDecompression.rawValue |
            VTDecodeFrameFlags._EnableTemporalProcessing.rawValue
        )
        var flagsOut:VTDecodeInfoFlags = VTDecodeInfoFlags()
        let status:OSStatus = VTDecompressionSessionDecodeFrame(session, sampleBuffer, decodeFlags, nil, &flagsOut)
        if (status != noErr) {
            logger.warning("\(status)")
        }
        return status
    }

    func didOutputForSession(status:OSStatus, infoFlags:VTDecodeInfoFlags, imageBuffer:CVImageBufferRef?, presentationTimeStamp:CMTime, duration:CMTime) {
        guard let imageBuffer:CVImageBuffer = imageBuffer where status == noErr else {
            return
        }
        delegate?.imageOutput(DecompressionBuffer(
            imageBuffer: imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: duration
        ))
    }
}
