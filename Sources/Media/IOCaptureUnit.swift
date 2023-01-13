#if os(iOS) || os(macOS)
import AVFoundation
import Foundation

enum IOCaptureUnitError: Error {
    case noDeviceAvailable
}

protocol IOCaptureUnit {
    associatedtype Output: AVCaptureOutput

    var input: AVCaptureInput { get }
    var output: Output { get }
    var connection: AVCaptureConnection? { get }
}

extension IOCaptureUnit {
    func attachSession(_ session: AVCaptureSession?) {
        guard let session else {
            return
        }
        if let connection {
            if session.canAddInput(input) {
                session.addInputWithNoConnections(input)
            }
            if session.canAddOutput(output) {
                session.addOutputWithNoConnections(output)
            }
            if session.canAddConnection(connection) {
                session.addConnection(connection)
            }
        } else {
            if session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
        }
    }

    func detachSession(_ session: AVCaptureSession?) {
        guard let session else {
            return
        }
        if let connection {
            if output.connections.contains(connection) {
                session.removeConnection(connection)
            }
        }
        if session.inputs.contains(input) {
            session.removeInput(input)
        }
        if session.outputs.contains(output) {
            session.removeOutput(output)
        }
    }
}

/// An object that provides the interface to control the AVCaptureDevice's transport behavior.
public class IOVideoCaptureUnit: IOCaptureUnit {
    /// The default videoSettings for a device.
    public static let defaultVideoSettings: [NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA)
    ]

    typealias Output = AVCaptureVideoDataOutput

    /// The current video device object.
    public let device: AVCaptureDevice?
    let input: AVCaptureInput
    let output: Output
    let connection: AVCaptureConnection?

    /// Specifies the videoOrientation indicates whether to rotate the video flowing through the connection to a given orientation.
    public var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            output.connections.filter { $0.isVideoOrientationSupported }.forEach {
                $0.videoOrientation = videoOrientation
            }
        }
    }

    /// Spcifies the video mirroed indicates whether the video flowing through the connection should be mirrored about its vertical axis.
    public var isVideoMirrored = false {
        didSet {
            output.connections.filter { $0.isVideoMirroringSupported }.forEach {
                $0.isVideoMirrored = isVideoMirrored
            }
        }
    }

    /// Specifies the preferredVideoStabilizationMode most appropriate for use with the connection.
    @available(macOS, unavailable)
    public var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode = .off {
        didSet {
            output.connections.filter { $0.isVideoStabilizationSupported }.forEach {
                $0.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
        }
    }

    init(_ device: AVCaptureDevice?, videoSettings: [NSObject: AnyObject] = IOVideoCaptureUnit.defaultVideoSettings) throws {
        guard let device else {
            throw IOCaptureUnitError.noDeviceAvailable
        }
        self.device = device
        input = try AVCaptureDeviceInput(device: device)
        output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = videoSettings as? [String: Any]
        #if os(iOS)
        if #available(iOS 13, *), let port = input.ports.first(where: { $0.mediaType == .video && $0.sourceDeviceType == device.deviceType && $0.sourceDevicePosition == device.position }) {
            connection = AVCaptureConnection(inputPorts: [port], output: output)
        } else {
            connection = nil
        }
        #else
        if let port = input.ports.first(where: { $0.mediaType == .video }) {
            connection = AVCaptureConnection(inputPorts: [port], output: output)
        } else {
            connection = nil
        }
        #endif
    }

    @available(iOS, unavailable)
    init(_ screen: AVCaptureScreenInput, videoSettings: [NSObject: AnyObject] = IOVideoCaptureUnit.defaultVideoSettings) {
        device = nil
        input = screen
        output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = videoSettings as? [String: Any]
        connection = nil
    }

    func setFrameRate(_ frameRate: Float64) {
        guard let device, let data = device.actualFPS(frameRate) else {
            return
        }
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = data.duration
            device.activeVideoMaxFrameDuration = data.duration
            device.unlockForConfiguration()
        } catch {
            logger.error("while locking device for fps:", error)
        }
    }

    func setTorchMode(_ torchMode: AVCaptureDevice.TorchMode) {
        guard let device, device.isTorchModeSupported(torchMode) else {
            return
        }
        do {
            try device.lockForConfiguration()
            device.torchMode = torchMode
            device.unlockForConfiguration()
        } catch {
            logger.error("while setting torch:", error)
        }
    }

    func setSampleBufferDelegate(_ videoUnit: IOVideoUnit?) {
        if let videoUnit {
            videoOrientation = videoUnit.videoOrientation
            setFrameRate(videoUnit.frameRate)
        }
        output.setSampleBufferDelegate(videoUnit, queue: videoUnit?.lockQueue)
    }
}

class IOAudioCaptureUnit: IOCaptureUnit {
    typealias Output = AVCaptureAudioDataOutput

    let input: AVCaptureInput
    let output: Output
    let connection: AVCaptureConnection?

    public init(_ device: AVCaptureDevice?) throws {
        guard let device else {
            throw IOCaptureUnitError.noDeviceAvailable
        }
        input = try AVCaptureDeviceInput(device: device)
        output = AVCaptureAudioDataOutput()
        connection = nil
    }

    func setSampleBufferDelegate(_ audioUnit: IOAudioUnit?) {
        output.setSampleBufferDelegate(audioUnit, queue: audioUnit?.lockQueue)
    }
}
#endif
