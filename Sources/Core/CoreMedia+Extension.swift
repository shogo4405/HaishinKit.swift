import CoreMedia

extension CMSampleBuffer {
    var dependsOnOthers:Bool {
        guard let
            attachments:CFArrayRef = CMSampleBufferGetSampleAttachmentsArray(self, false),
            attachment:Dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), CFDictionaryRef.self) as Dictionary? else {
            return false
        }
        return attachment["DependsOnOthers"] as! Bool
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
            var length:Int = 0
            var bytes:UnsafeMutablePointer<Int8> = nil
            guard IsNoErr(CMBlockBufferGetDataPointer(buffer, 0, nil, &length, &bytes)) else {
                return []
            }
            return Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(bytes), count: length))

        }
        set {
            
        }
    }
}
