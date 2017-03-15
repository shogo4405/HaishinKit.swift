import CoreMedia

extension CMBlockBuffer {
    var dataLength:Int {
        return CMBlockBufferGetDataLength(self)
    }
}
