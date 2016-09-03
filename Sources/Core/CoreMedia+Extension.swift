import CoreMedia
import CoreImage

extension CMSampleBuffer {
    var dependsOnOthers:Bool {
        return false
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
        let decodeTimestamp:CMTime = CMSampleBufferGetDecodeTimeStamp(self)
        return decodeTimestamp == kCMTimeInvalid ? presentationTimeStamp : decodeTimestamp
    }
    var presentationTimeStamp:CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self)
    }
}

// MARK: BytesConvertible
extension CMSampleBuffer: BytesConvertible {
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
extension CMSampleTimingInfo {
    init(sampleBuffer:CMSampleBuffer) {
        duration = sampleBuffer.duration
        decodeTimeStamp = sampleBuffer.decodeTimeStamp
        presentationTimeStamp = sampleBuffer.presentationTimeStamp
    }
}
