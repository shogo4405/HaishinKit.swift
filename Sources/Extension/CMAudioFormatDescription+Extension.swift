import CoreMedia

extension CMAudioFormatDescription {
    var streamBasicDescription: UnsafePointer<AudioStreamBasicDescription>? {
        return CMAudioFormatDescriptionGetStreamBasicDescription(self)
    }
}
