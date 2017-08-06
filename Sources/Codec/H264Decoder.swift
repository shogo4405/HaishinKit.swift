import CoreVideo
import Foundation
import AVFoundation
import VideoToolbox
import CoreFoundation

protocol VideoDecoderDelegate: class {
    func sampleOutput(video sampleBuffer: CMSampleBuffer)
}

// MARK: -
final class H264Decoder {
    #if os(iOS)
    static let defaultAttributes:[NSString: AnyObject] = [
    kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA),
        kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject,
        kCVPixelBufferOpenGLESCompatibilityKey: NSNumber(booleanLiteral: true),
    ]
    #else
    static let defaultAttributes:[NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA),
        kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject,
        kCVPixelBufferOpenGLCompatibilityKey: NSNumber(booleanLiteral: true),
    ]
    #endif

    var formatDescription:CMFormatDescription? = nil {
        didSet {
            if let atoms:[String: AnyObject] = formatDescription?.getExtension(by: "SampleDescriptionExtensionAtoms"), let avcC:Data =  atoms["avcC"] as? Data {
                let config:AVCConfigurationRecord = AVCConfigurationRecord(data: avcC)
                isBaseline = config.AVCProfileIndication == 66
            }
            invalidateSession = true
        }
    }
    weak var delegate:VideoDecoderDelegate?


    private var isBaseline:Bool = true
    private var buffers:[CMSampleBuffer] = []
    private var attributes:[NSString:AnyObject] {
        return H264Decoder.defaultAttributes
    }
    private var minimumGroupOfPictures:Int = 12
    private(set) var status:OSStatus = noErr {
        didSet {
            if (status != noErr) {
                logger.warn("\(self.status)")
            }
        }
    }
    private var invalidateSession:Bool = true
    private var callback:VTDecompressionOutputCallback = {(
        decompressionOutputRefCon:UnsafeMutableRawPointer?,
        sourceFrameRefCon:UnsafeMutableRawPointer?,
        status:OSStatus,
        infoFlags:VTDecodeInfoFlags,
        imageBuffer:CVBuffer?,
        presentationTimeStamp:CMTime,
        duration:CMTime) in
        let decoder:H264Decoder = Unmanaged<H264Decoder>.fromOpaque(decompressionOutputRefCon!).takeUnretainedValue()
        decoder.didOutputForSession(status, infoFlags: infoFlags, imageBuffer: imageBuffer, presentationTimeStamp: presentationTimeStamp, duration: duration)
    }

    private var _session:VTDecompressionSession? = nil
    private var session:VTDecompressionSession! {
        get {
            if (_session == nil)  {
                guard let formatDescription:CMFormatDescription = formatDescription else {
                    return nil
                }
                var record:VTDecompressionOutputCallbackRecord = VTDecompressionOutputCallbackRecord(
                    decompressionOutputCallback: callback,
                    decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
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
        var flagsOut:VTDecodeInfoFlags = VTDecodeInfoFlags()
        let decodeFlags:VTDecodeFrameFlags = VTDecodeFrameFlags(rawValue:
            VTDecodeFrameFlags._EnableAsynchronousDecompression.rawValue |
            VTDecodeFrameFlags._EnableTemporalProcessing.rawValue
        )
        return VTDecompressionSessionDecodeFrame(session, sampleBuffer, decodeFlags, nil, &flagsOut)
    }

    func didOutputForSession(_ status:OSStatus, infoFlags:VTDecodeInfoFlags, imageBuffer:CVImageBuffer?, presentationTimeStamp:CMTime, duration:CMTime) {
        guard let imageBuffer:CVImageBuffer = imageBuffer, status == noErr else {
            return
        }

        var timingInfo:CMSampleTimingInfo = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: kCMTimeInvalid
        )

        var videoFormatDescription:CMVideoFormatDescription? = nil
        self.status = CMVideoFormatDescriptionCreateForImageBuffer(
            kCFAllocatorDefault,
            imageBuffer,
            &videoFormatDescription
        )

        var sampleBuffer:CMSampleBuffer? = nil
        self.status = CMSampleBufferCreateForImageBuffer(
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

        if (isBaseline) {
            delegate?.sampleOutput(video: buffer)
        } else {
            buffers.append(buffer)
            buffers.sort(by: { (lhs: CMSampleBuffer, rhs: CMSampleBuffer) -> Bool in
                return lhs.presentationTimeStamp < rhs.presentationTimeStamp
            })
            if (minimumGroupOfPictures <= buffers.count) {
                delegate?.sampleOutput(video: buffers.removeFirst())
            }
        }
    }

    func clear() {
        buffers.removeAll()
    }
}
