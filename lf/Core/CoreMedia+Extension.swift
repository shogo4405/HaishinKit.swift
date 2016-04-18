import CoreMedia

extension CMSampleBuffer {
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
    var decodeTimeStamp:CMTime {
        return CMSampleBufferGetDecodeTimeStamp(self)
    }
    var presentationTimeStamp:CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self)
    }
}

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
            return NSData(bytes: bytes, length: length).arrayOfBytes()
        }
        set {
            
        }
    }
}
