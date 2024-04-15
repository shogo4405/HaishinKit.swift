#if os(iOS) || os(tvOS) || os(macOS)
import AVFoundation
import Foundation

/// Configuration calback block for IOAudioCaptureUnit.
@available(tvOS 17.0, *)
public typealias IOAudioCaptureConfigurationBlock = (IOAudioCaptureUnit?, IOAudioUnitError?) -> Void

/// An object that provides the interface to control the AVCaptureDevice's transport behavior.
@available(tvOS 17.0, *)
public final class IOAudioCaptureUnit: IOCaptureUnit {
    public typealias Output = AVCaptureAudioDataOutput

    public let track: UInt8
    public private(set) var input: AVCaptureInput?
    public private(set) var device: AVCaptureDevice?
    public private(set) var output: Output? {
        didSet {
            oldValue?.setSampleBufferDelegate(nil, queue: nil)
        }
    }
    public private(set) var connection: AVCaptureConnection?
    private var dataOutput: IOAudioCaptureUnitDataOutput?

    init(_ track: UInt8) {
        self.track = track
    }

    func attachDevice(_ device: AVCaptureDevice?) throws {
        guard let device else {
            self.device = nil
            input = nil
            output = nil
            return
        }
        self.device = device
        input = try AVCaptureDeviceInput(device: device)
        output = AVCaptureAudioDataOutput()
    }

    func setSampleBufferDelegate(_ audioUnit: IOAudioUnit?) {
        dataOutput = audioUnit?.makeDataOutput(track)
        output?.setSampleBufferDelegate(dataOutput, queue: audioUnit?.lockQueue)
    }
}

@available(tvOS 17.0, *)
final class IOAudioCaptureUnitDataOutput: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let track: UInt8
    private let audioMixer: any IOAudioMixerConvertible

    init(track: UInt8, audioMixer: any IOAudioMixerConvertible) {
        self.track = track
        self.audioMixer = audioMixer
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        audioMixer.append(sampleBuffer, track: track)
    }
}
#endif
