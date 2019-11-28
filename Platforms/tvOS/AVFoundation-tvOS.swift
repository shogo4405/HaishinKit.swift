#if os(tvOS)

import CoreMedia
import Foundation

typealias AVCaptureOutput = Any
typealias AVCaptureConnection = Any

protocol AVCaptureVideoDataOutputSampleBufferDelegate: class {
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
}

protocol AVCaptureAudioDataOutputSampleBufferDelegate: class {
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
}

#endif
