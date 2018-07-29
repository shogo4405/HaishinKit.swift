import CoreMedia

extension CMSampleTimingInfo {
    init(sampleBuffer: CMSampleBuffer) {
        self.init()
        duration = sampleBuffer.duration
        decodeTimeStamp = sampleBuffer.decodeTimeStamp
        presentationTimeStamp = sampleBuffer.presentationTimeStamp
    }
}
