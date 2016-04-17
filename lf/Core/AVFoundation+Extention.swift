import AVFoundation

extension CMSampleBuffer: BytesConvertible {
    var bytes:[UInt8] {
        get {
            guard let buffer:CMBlockBuffer = CMSampleBufferGetDataBuffer(self) else {
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
