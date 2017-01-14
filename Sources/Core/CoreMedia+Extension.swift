import CoreMedia
import CoreImage

public enum CMSampleBufferType: String {
    case video = "video"
    case audio = "audio"
}

extension CMSampleBuffer {
    var dependsOnOthers:Bool {
        guard
            let attachments:CFArray = CMSampleBufferGetSampleAttachmentsArray(self, false) else {
            return false
        }
        let attachment:[NSObject: AnyObject] = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFDictionary.self) as [NSObject : AnyObject]
        return attachment["DependsOnOthers" as NSObject] as! Bool
    }
    var dataBuffer:CMBlockBuffer? {
        get {
            return CMSampleBufferGetDataBuffer(self)
        }
        set {
            guard let dataBuffer:CMBlockBuffer = newValue else {
                return
            }
            CMSampleBufferSetDataBuffer(self, dataBuffer)
        }
    }
    var imageBuffer:CVImageBuffer? {
        return CMSampleBufferGetImageBuffer(self)
    }
    var numSamples:CMItemCount {
        return CMSampleBufferGetNumSamples(self)
    }
    var duration:CMTime {
        return CMSampleBufferGetDuration(self)
    }
    var formatDescription:CMFormatDescription? {
        return CMSampleBufferGetFormatDescription(self)
    }
    var decodeTimeStamp:CMTime {
        return CMSampleBufferGetDecodeTimeStamp(self)
    }
    var presentationTimeStamp:CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self)
    }
}

extension CMSampleBuffer: BytesConvertible {
    // MARK: BytesConvertible
    var bytes:[UInt8] {
        get {
            guard let buffer:CMBlockBuffer = dataBuffer else {
                return []
            }
            var bytes:UnsafeMutablePointer<Int8>? = nil
            var length:Int = 0
            guard CMBlockBufferGetDataPointer(buffer, 0, nil, &length, &bytes) == noErr else {
                return []
            }
            return Array(Data(bytes: bytes!, count: length))
        }
        set {
        }
    }
}

// MARK: -
extension CMVideoFormatDescription {
    var dimensions:CMVideoDimensions {
        return CMVideoFormatDescriptionGetDimensions(self)
    }
}

// MARK: -
extension CMAudioFormatDescription {
    var streamBasicDescription:UnsafePointer<AudioStreamBasicDescription>? {
        return CMAudioFormatDescriptionGetStreamBasicDescription(self)
    }
}

// MARK: -
extension CMBlockBuffer {
    var dataLength:Int {
        return CMBlockBufferGetDataLength(self)
    }
}

// MARK: -
extension CVPixelBuffer {
    
    static func create(_ image:CIImage) -> CVPixelBuffer? {
        var buffer:CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(image.extent.width),
            Int(image.extent.height),
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            nil,
            &buffer
        )
        return buffer
    }
    var width:Int {
        return CVPixelBufferGetWidth(self)
    }
    var height:Int {
        return CVPixelBufferGetHeight(self)
    }
}

// MARK: -
extension CMVideoFormatDescription {
    static func create(withPixelBuffer:CVPixelBuffer) -> CMVideoFormatDescription? {
        var formatDescription:CMFormatDescription?
        let status:OSStatus = CMVideoFormatDescriptionCreate(
            kCFAllocatorDefault,
            kCMVideoCodecType_422YpCbCr8,
            Int32(withPixelBuffer.width),
            Int32(withPixelBuffer.height),
            nil,
            &formatDescription
        )
        guard status == noErr else {
            logger.warning("\(status)")
            return nil
        }
        return formatDescription
    }
}

// MARK: -
extension CMSampleTimingInfo {
    init(sampleBuffer:CMSampleBuffer) {
        duration = sampleBuffer.duration
        decodeTimeStamp = sampleBuffer.decodeTimeStamp
        presentationTimeStamp = sampleBuffer.presentationTimeStamp
    }
}
