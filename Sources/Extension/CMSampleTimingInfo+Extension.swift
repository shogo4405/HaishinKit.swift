import CoreMedia

extension CMSampleTimingInfo {
    init(sampleBuffer:CMSampleBuffer) {
        duration = sampleBuffer.duration
        decodeTimeStamp = sampleBuffer.decodeTimeStamp
        presentationTimeStamp = sampleBuffer.presentationTimeStamp
    }
}
