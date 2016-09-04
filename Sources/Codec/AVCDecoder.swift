import CoreVideo
import Foundation
import AVFoundation
import VideoToolbox
import CoreFoundation

protocol VideoDecoderDelegate: class {
    func sampleOutput(video sampleBuffer: CMSampleBuffer)
}

// MARK: -
final class AVCDecoder {

    #if os(iOS)
    static let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA) as AnyObject,
        kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject,
        kCVPixelBufferOpenGLESCompatibilityKey: true as AnyObject,
    ]
    #else
    static let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA) as AnyObject,
        kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject,
        kCVPixelBufferOpenGLCompatibilityKey: true as AnyObject,
    ]
    #endif

    var running:Bool = false
    var lockQueue:DispatchQueue = DispatchQueue(
        label: "com.github.shogo4405.lf.AVCDecoder.lock", attributes: []
    )
    var formatDescription:CMFormatDescription? = nil {
        didSet {
            invalidateSession = true
        }
    }
    weak var delegate:VideoDecoderDelegate?

    fileprivate var attributes:[NSString:  AnyObject] {
        return AVCDecoder.defaultAttributes
    }
    fileprivate var invalidateSession:Bool = true
    fileprivate var callback:VTDecompressionOutputCallback = {(
        decompressionOutputRefCon:UnsafeMutableRawPointer?,
        sourceFrameRefCon:UnsafeMutableRawPointer?,
        status:OSStatus,
        infoFlags:VTDecodeInfoFlags,
        imageBuffer:CVBuffer?,
        presentationTimeStamp:CMTime,
        duration:CMTime) in
        let decoder:AVCDecoder = unsafeBitCast(decompressionOutputRefCon, to: AVCDecoder.self)
        decoder.didOutputForSession(status, infoFlags: infoFlags, imageBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, duration: duration)
    }

    fileprivate var _session:VTDecompressionSession? = nil
    fileprivate var session:VTDecompressionSession! {
        get {
            if (_session == nil)  {
                guard let formatDescription:CMFormatDescription = formatDescription else {
                    return nil
                }
                var record:VTDecompressionOutputCallbackRecord = VTDecompressionOutputCallbackRecord(
                    decompressionOutputCallback: callback,
                    decompressionOutputRefCon: unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
                )
                guard VTDecompressionSessionCreate(
                    kCFAllocatorDefault,
                    formatDescription,
                    nil,
                    attributes as CFDictionary?,
                    &record,
                    &_session ) == noErr else {
                    return nil
                }
                invalidateSession = false
            }
            return _session!
        }
        set {
            if let session:VTDecompressionSession = _session {
                VTDecompressionSessionInvalidate(session)
            }
            _session = newValue
        }
    }

    func decodeSampleBuffer(_ sampleBuffer:CMSampleBuffer) -> OSStatus {
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

    func didOutputForSession(_ status:OSStatus, infoFlags:VTDecodeInfoFlags, imageBuffer:CVImageBuffer?, presentationTimeStamp:CMTime, duration:CMTime) {
        guard let imageBuffer:CVImageBuffer = imageBuffer , status == noErr else {
            return
        }
        var timingInfo:CMSampleTimingInfo = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: kCMTimeInvalid
        )
        var videoFormatDescription:CMVideoFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(
            kCFAllocatorDefault,
            imageBuffer,
            &videoFormatDescription
        )
        var sampleBuffer:CMSampleBuffer? = nil
        CMSampleBufferCreateForImageBuffer(
            kCFAllocatorDefault,
            imageBuffer,
            true,
            nil,
            nil,
            videoFormatDescription!,
            &timingInfo,
            &sampleBuffer
        )
        guard let buffer:CMSampleBuffer = sampleBuffer else {
            return
        }
        delegate?.sampleOutput(video: buffer)
    }
}
