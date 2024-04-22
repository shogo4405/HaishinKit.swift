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

    /// The track number.
    public let track: UInt8
    /// The input data to a cupture session.
    public private(set) var input: AVCaptureInput?
    /// The current audio device object.
    public private(set) var device: AVCaptureDevice?
    /// The output data to a sample buffers.
    public private(set) var output: Output? {
        didSet {
            oldValue?.setSampleBufferDelegate(nil, queue: nil)
        }
    }
    /// The connection from a capture input to a capture output.
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
        if let input, let output {
            connection = AVCaptureConnection(inputPorts: input.ports, output: output)
        }
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
        audioMixer.append(track, buffer: sampleBuffer)
    }
}
#endif
