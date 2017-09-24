import CoreMedia
import Foundation

typealias AVCaptureOutput = Any
typealias AVCaptureConnection = Any

protocol AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput:AVCaptureOutput, didOutput sampleBuffer:CMSampleBuffer, from connection:AVCaptureConnection)
}

protocol AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput:AVCaptureOutput, didOutput sampleBuffer:CMSampleBuffer, from connection:AVCaptureConnection)
}
