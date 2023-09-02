import AVFoundation
import Foundation
import HaishinKit
import libsrt

/// An object that provides the interface to control a one-way channel over a SRTConnection.
public class SRTStream: NetStream {
    private enum ReadyState: UInt8 {
        case initialized = 0
        case open        = 1
        case play        = 2
        case playing     = 3
        case publish     = 4
        case publishing  = 5
        case closed      = 6
    }

    private var name: String?
    private var action: (() -> Void)?
    private var keyValueObservations: [NSKeyValueObservation] = []
    private weak var connection: SRTConnection?
    private lazy var audioEngine: AVAudioEngine = .init()

    private lazy var writer: TSWriter = {
        var writer = TSWriter()
        writer.delegate = self
        return writer
    }()

    private lazy var reader: TSReader = {
        var reader = TSReader()
        reader.delegate = self
        return reader
    }()

    private var readyState: ReadyState = .initialized {
        didSet {
            guard oldValue != readyState else {
                return
            }

            switch oldValue {
            case .publishing:
                writer.stopRunning()
                mixer.stopEncoding()
            case .playing:
                mixer.stopDecoding()
            default:
                break
            }

            switch readyState {
            case .play:
                connection?.socket?.doInput()
                mixer.isPaused = false
                mixer.startDecoding()
                readyState = .playing
            case .publish:
                mixer.startEncoding(writer)
                mixer.startRunning()
                writer.startRunning()
                readyState = .publishing
            default:
                break
            }
        }
    }

    /// Creates a new SRTStream object.
    public init(_ connection: SRTConnection) {
        super.init()
        self.connection = connection
        self.connection?.streams.append(self)
        let keyValueObservation = connection.observe(\.connected, options: [.new, .old]) { [weak self] _, _ in
            guard let self = self else {
                return
            }
            if connection.connected {
                self.action?()
                self.action = nil
            } else {
                self.readyState = .open
            }
        }
        keyValueObservations.append(keyValueObservation)
    }

    deinit {
        connection = nil
        keyValueObservations.removeAll()
    }

    /**
     Prepare the stream to process media of the given type

     - parameters:
     - type: An AVMediaType you will be sending via an appendSampleBuffer call

     As with appendSampleBuffer only video and audio types are supported
     */
    public func attachRawMedia(_ type: AVMediaType) {
        writer.expectedMedias.insert(type)
    }

    /**
     Remove a media type that was added via attachRawMedia

     - parameters:
     - type: An AVMediaType that was added via an attachRawMedia call
     */
    public func detachRawMedia(_ type: AVMediaType) {
        writer.expectedMedias.remove(type)
    }

    override public func attachCamera(_ camera: AVCaptureDevice?, onError: ((Error) -> Void)? = nil) {
        if camera == nil {
            writer.expectedMedias.remove(.video)
        } else {
            writer.expectedMedias.insert(.video)
        }
        super.attachCamera(camera, onError: onError)
    }

    override public func attachAudio(_ audio: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool = true, onError: ((Error) -> Void)? = nil) {
        if audio == nil {
            writer.expectedMedias.remove(.audio)
        } else {
            writer.expectedMedias.insert(.audio)
        }
        super.attachAudio(audio, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession, onError: onError)
    }

    /// Sends streaming audio, vidoe and data message from client.
    public func publish(_ name: String? = "") {
        lockQueue.async {
            guard let name else {
                switch self.readyState {
                case .publish, .publishing:
                    self.readyState = .open
                default:
                    break
                }
                return
            }
            if self.connection?.connected == true {
                self.readyState = .publish
            } else {
                self.action = { [weak self] in self?.publish(name) }
            }
        }
    }

    /// Playback streaming audio and video message from server.
    public func play(_ name: String? = "") {
        lockQueue.async {
            guard let name else {
                switch self.readyState {
                case .play, .playing:
                    self.readyState = .open
                default:
                    break
                }
                return
            }
            if self.connection?.connected == true {
                self.readyState = .play
            } else {
                self.action = { [weak self] in self?.play(name) }
            }
        }
    }

    /// Stops playing or publishing and makes available other uses.
    public func close() {
        lockQueue.async {
            if self.readyState == .closed || self.readyState == .initialized {
                return
            }
            self.readyState = .closed
        }
    }

    func doInput(_ data: Data) {
        _ = reader.read(data)
    }
}

extension SRTStream: TSWriterDelegate {
    // MARK: TSWriterDelegate
    public func writer(_ writer: TSWriter, didOutput data: Data) {
        guard readyState == .publishing else {
            return
        }
        connection?.socket?.doOutput(data: data)
    }
}

extension SRTStream: TSReaderDelegate {
    // MARK: TSReaderDelegate
    public func reader(_ reader: TSReader, id: UInt16, didRead formatDescription: CMFormatDescription) {
        guard readyState == .playing else {
            return
        }
        switch CMFormatDescriptionGetMediaType(formatDescription) {
        case kCMMediaType_Video:
            mixer.hasVideo = true
        default:
            break
        }
    }

    public func reader(_ reader: TSReader, id: UInt16, didRead sampleBuffer: CMSampleBuffer) {
        guard readyState == .playing else {
            return
        }
        mixer.appendSampleBuffer(sampleBuffer)
    }
}
