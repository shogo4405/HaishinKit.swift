import CoreMedia

extension CMAudioFormatDescription {
    var streamBasicDescription: UnsafePointer<AudioStreamBasicDescription>? {
        CMAudioFormatDescriptionGetStreamBasicDescription(self)
    }
}
