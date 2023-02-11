#if os(iOS) || os(macOS)
import AVFoundation
import Foundation

enum IOCaptureUnitError: Error {
    case noDeviceAvailable
}

protocol IOCaptureUnit {
    associatedtype Output: AVCaptureOutput

    var input: AVCaptureInput? { get set }
    var output: Output? { get set }
    var connection: AVCaptureConnection? { get set }
}

extension IOCaptureUnit {
    func attachSession(_ session: AVCaptureSession?) {
        guard let session else {
            return
        }
        if let connection {
            if let input, session.canAddInput(input) {
                session.addInputWithNoConnections(input)
            }
            if let output, session.canAddOutput(output) {
                session.addOutputWithNoConnections(output)
            }
            if session.canAddConnection(connection) {
                session.addConnection(connection)
            }
        } else {
            if let input, session.canAddInput(input) {
                session.addInput(input)
            }
            if let output, session.canAddOutput(output) {
                session.addOutput(output)
            }
        }
    }

    func detachSession(_ session: AVCaptureSession?) {
        guard let session else {
            return
        }
        if let connection {
            if output?.connections.contains(connection) == true {
                session.removeConnection(connection)
            }
        }
        if let input, session.inputs.contains(input) {
            session.removeInput(input)
        }
        if let output, session.outputs.contains(output) {
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
    public private(set) var device: AVCaptureDevice?
    var input: AVCaptureInput?
    var output: Output? {
        didSet {
            output?.alwaysDiscardsLateVideoFrames = true
            output?.videoSettings = IOVideoCaptureUnit.defaultVideoSettings as [String: Any]
        }
    }
    var connection: AVCaptureConnection?

    /// Specifies the videoOrientation indicates whether to rotate the video flowing through the connection to a given orientation.
    public var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            output?.connections.filter { $0.isVideoOrientationSupported }.forEach {
                $0.videoOrientation = videoOrientation
            }
        }
    }

    /// Spcifies the video mirroed indicates whether the video flowing through the connection should be mirrored about its vertical axis.
    public var isVideoMirrored = false {
        didSet {
            output?.connections.filter { $0.isVideoMirroringSupported }.forEach {
                $0.isVideoMirrored = isVideoMirrored
            }
        }
    }

    /// Specifies the preferredVideoStabilizationMode most appropriate for use with the connection.
    @available(macOS, unavailable)
    public var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode = .off {
        didSet {
            output?.connections.filter { $0.isVideoStabilizationSupported }.forEach {
                $0.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
        }
    }

    func attachDevice(_ device: AVCaptureDevice?, videoUnit: IOVideoUnit) throws {
        setSampleBufferDelegate(nil)
        detachSession(videoUnit.mixer?.session)
        guard let device else {
            self.device = nil
            input = nil
            output = nil
            connection = nil
            return
        }
        self.device = device
        input = try AVCaptureDeviceInput(device: device)
        output = AVCaptureVideoDataOutput()
        #if os(iOS)
        if let output, #available(iOS 13, *), let port = input?.ports.first(where: { $0.mediaType == .video && $0.sourceDeviceType == device.deviceType && $0.sourceDevicePosition == device.position }) {
            connection = AVCaptureConnection(inputPorts: [port], output: output)
        } else {
            connection = nil
        }
        #else
        if let output, let port = input?.ports.first(where: { $0.mediaType == .video }) {
            connection = AVCaptureConnection(inputPorts: [port], output: output)
        } else {
            connection = nil
        }
        #endif
        attachSession(videoUnit.mixer?.session)
        output?.connections.forEach {
            if $0.isVideoMirroringSupported {
                $0.isVideoMirrored = isVideoMirrored
            }
            if $0.isVideoOrientationSupported {
                $0.videoOrientation = videoOrientation
            }
            #if os(iOS)
            if $0.isVideoStabilizationSupported {
                $0.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
            #endif
        }
        setSampleBufferDelegate(videoUnit)
    }

    @available(iOS, unavailable)
    func attachScreen(_ screen: AVCaptureScreenInput?, videoUnit: IOVideoUnit) {
        setSampleBufferDelegate(nil)
        detachSession(videoUnit.mixer?.session)
        device = nil
        input = screen
        output = AVCaptureVideoDataOutput()
        connection = nil
        attachSession(videoUnit.mixer?.session)
        setSampleBufferDelegate(videoUnit)
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
        output?.setSampleBufferDelegate(videoUnit, queue: videoUnit?.lockQueue)
    }
}

class IOAudioCaptureUnit: IOCaptureUnit {
    typealias Output = AVCaptureAudioDataOutput

    var input: AVCaptureInput?
    var output: Output?
    var connection: AVCaptureConnection?

    func attachDevice(_ device: AVCaptureDevice?, audioUnit: IOAudioUnit) throws {
        setSampleBufferDelegate(nil)
        detachSession(audioUnit.mixer?.session)
        guard let device else {
            input = nil
            output = nil
            return
        }
        input = try AVCaptureDeviceInput(device: device)
        output = AVCaptureAudioDataOutput()
        attachSession(audioUnit.mixer?.session)
        setSampleBufferDelegate(audioUnit)
    }

    func setSampleBufferDelegate(_ audioUnit: IOAudioUnit?) {
        output?.setSampleBufferDelegate(audioUnit, queue: audioUnit?.lockQueue)
    }
}
#endif
