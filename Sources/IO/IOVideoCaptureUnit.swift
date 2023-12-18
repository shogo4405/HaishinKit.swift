#if os(iOS) || os(tvOS) || os(macOS)
import AVFoundation
import Foundation

/// Configuration calback block for IOVideoUnit.
@available(tvOS 17.0, *)
public typealias IOVideoCaptureConfigurationBlock = (IOVideoCaptureUnit?, IOVideoUnitError?) -> Void

/// An object that provides the interface to control the AVCaptureDevice's transport behavior.
@available(tvOS 17.0, *)
public final class IOVideoCaptureUnit: IOCaptureUnit {
    #if os(iOS) || os(macOS)
    /// The default color format.
    public static let colorFormat = kCVPixelFormatType_32BGRA
    #else
    /// The default color format.
    public static let colorFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    #endif

    typealias Output = AVCaptureVideoDataOutput

    /// The current video device object.
    public private(set) var device: AVCaptureDevice?

    /// Specifies the video capture color format.
    /// - Warning: If a format other than kCVPixelFormatType_32BGRA is set, the multi-camera feature will become unavailable. We intend to support this in the future.
    public var colorFormat = IOVideoCaptureUnit.colorFormat

    #if os(iOS) || os(macOS)
    /// Specifies the videoOrientation indicates whether to rotate the video flowing through the connection to a given orientation.
    public var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            output?.connections.filter { $0.isVideoOrientationSupported }.forEach {
                $0.videoOrientation = videoOrientation
            }
        }
    }
    #endif

    /// Spcifies the video mirroed indicates whether the video flowing through the connection should be mirrored about its vertical axis.
    public var isVideoMirrored = false {
        didSet {
            output?.connections.filter { $0.isVideoMirroringSupported }.forEach {
                $0.isVideoMirrored = isVideoMirrored
            }
        }
    }

    #if os(iOS)
    /// Specifies the preferredVideoStabilizationMode most appropriate for use with the connection.
    public var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode = .off {
        didSet {
            output?.connections.filter { $0.isVideoStabilizationSupported }.forEach {
                $0.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
        }
    }
    #endif

    let channel: UInt8
    var input: AVCaptureInput?
    var output: Output? {
        didSet {
            guard let output else {
                return
            }
            output.alwaysDiscardsLateVideoFrames = true
            if output.availableVideoPixelFormatTypes.contains(colorFormat) {
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: colorFormat)]
            } else {
                logger.warn("device doesn't support this color format ", colorFormat, ".")
            }
        }
    }
    var connection: AVCaptureConnection?
    private var dataOutput: IOVideoCaptureUnitVideoDataOutputSampleBuffer?

    init(_ channel: UInt8) {
        self.channel = channel
    }

    func attachDevice(_ device: AVCaptureDevice?, videoUnit: IOVideoUnit) throws {
        setSampleBufferDelegate(nil)
        videoUnit.mixer?.session.detachCapture(self)
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
        videoUnit.mixer?.session.attachCapture(self)
        output?.connections.forEach {
            if $0.isVideoMirroringSupported {
                $0.isVideoMirrored = isVideoMirrored
            }
            #if os(iOS) || os(macOS)
            if $0.isVideoOrientationSupported {
                $0.videoOrientation = videoOrientation
            }
            #endif
            #if os(iOS)
            if $0.isVideoStabilizationSupported {
                $0.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
            #endif
        }
        setSampleBufferDelegate(videoUnit)
    }

    #if os(macOS)
    func attachScreen(_ screen: AVCaptureScreenInput?, videoUnit: IOVideoUnit) {
        setSampleBufferDelegate(nil)
        videoUnit.mixer?.session.detachCapture(self)
        device = nil
        input = screen
        output = AVCaptureVideoDataOutput()
        connection = nil
        videoUnit.mixer?.session.attachCapture(self)
        setSampleBufferDelegate(videoUnit)
    }
    #endif

    func setFrameRate(_ frameRate: Float64) {
        guard let device else {
            return
        }
        do {
            try device.lockForConfiguration()
            if device.activeFormat.isFrameRateSupported(frameRate) {
                device.activeVideoMinFrameDuration = CMTime(value: 100, timescale: CMTimeScale(100 * frameRate))
                device.activeVideoMaxFrameDuration = CMTime(value: 100, timescale: CMTimeScale(100 * frameRate))
            } else {
                if let format = device.videoFormat(
                    width: device.activeFormat.formatDescription.dimensions.width,
                    height: device.activeFormat.formatDescription.dimensions.height,
                    frameRate: frameRate,
                    isMultiCamSupported: device.activeFormat.isMultiCamSupported
                ) {
                    device.activeFormat = format
                    device.activeVideoMinFrameDuration = CMTime(value: 100, timescale: CMTimeScale(100 * frameRate))
                    device.activeVideoMaxFrameDuration = CMTime(value: 100, timescale: CMTimeScale(100 * frameRate))
                }
            }
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
            #if os(iOS) || os(macOS)
            videoOrientation = videoUnit.videoOrientation
            #endif
            setFrameRate(videoUnit.frameRate)
        }
        dataOutput = videoUnit?.makeVideoDataOutputSampleBuffer(channel)
        output?.setSampleBufferDelegate(dataOutput, queue: videoUnit?.lockQueue)
    }
}

// swiftlint:disable:next type_name
@available(tvOS 17.0, *)
final class IOVideoCaptureUnitVideoDataOutputSampleBuffer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let channel: UInt8
    private let videoMixer: IOVideoMixer<IOVideoUnit>

    init(channel: UInt8, videoMixer: IOVideoMixer<IOVideoUnit>) {
        self.channel = channel
        self.videoMixer = videoMixer
    }

    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        videoMixer.append(sampleBuffer, channel: channel, isVideoMirrored: connection.isVideoMirrored)
    }
}

#endif
