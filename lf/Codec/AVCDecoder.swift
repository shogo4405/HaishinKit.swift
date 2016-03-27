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

    var buffers:[DecompressionBuffer] = []

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
        presentationDuration:CMTime) in
        let decoder:AVCDecoder = unsafeBitCast(decompressionOutputRefCon, AVCDecoder.self)
        decoder.didOutputForSession(status, infoFlags: infoFlags, imageBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, presentationDuration: presentationDuration)
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

    func didOutputForSession(status:OSStatus, infoFlags:VTDecodeInfoFlags, imageBuffer:CVImageBufferRef?,presentationTimeStamp:CMTime, presentationDuration:CMTime) {
        buffers.append(DecompressionBuffer(
            imageBuffer: imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            presentationDuration:  presentationDuration
        ))
        if (12 <= buffers.count) {
            buffers.sortInPlace {(lhr:DecompressionBuffer, rhr:DecompressionBuffer) -> Bool in
                return lhr.presentationTimeStamp.value < rhr.presentationTimeStamp.value
            }
            for buffer in buffers {
                delegate?.imageOutput(buffer.imageBuffer, presentationTimeStamp: buffer.presentationTimeStamp, presentationDuration: presentationDuration)
            }
            buffers.removeAll(keepCapacity: false)
        }
    }
}
