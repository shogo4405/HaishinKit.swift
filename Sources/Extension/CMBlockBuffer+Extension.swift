import CoreMedia

extension CMBlockBuffer {
    var data: Data? {
        var length = 0
        var buffer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(self, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &buffer) == noErr else {
            return nil
        }
        return Data(bytes: buffer!, count: length)
    }

    @discardableResult
    func copyDataBytes(to buffer: UnsafeMutableRawPointer) -> OSStatus {
        return CMBlockBufferCopyDataBytes(self, atOffset: 0, dataLength: dataLength, destination: buffer)
    }
}
