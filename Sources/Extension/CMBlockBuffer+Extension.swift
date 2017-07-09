import CoreMedia

extension CMBlockBuffer {
    var dataLength:Int {
        return CMBlockBufferGetDataLength(self)
    }
}

extension CMBlockBuffer {
    var data:Data? {
        var length:Int = 0
        var buffer:UnsafeMutablePointer<Int8>? = nil
        guard CMBlockBufferGetDataPointer(self, 0, nil, &length, &buffer) == noErr else {
            return nil
        }
        return Data(bytes: buffer!, count: length)
    }
}
