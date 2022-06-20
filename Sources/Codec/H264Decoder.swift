import AVFoundation
import CoreFoundation
import CoreVideo
import VideoToolbox

#if os(iOS)
import UIKit
#endif

protocol VideoDecoderDelegate: AnyObject {
    func sampleOutput(video sampleBuffer: CMSampleBuffer)
}

// MARK: -
final class H264Decoder {
    static let defaultDecodeFlags: VTDecodeFrameFlags = [
        ._EnableAsynchronousDecompression,
        ._EnableTemporalProcessing
    ]
    static let defaultMinimumGroupOfPictures: Int = 12
    static let defaultAttributes: [NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA),
        kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject,
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue
    ]

    var formatDescription: CMFormatDescription? {
        didSet {
            if let atoms: [String: AnyObject] = formatDescription?.`extension`(by: "SampleDescriptionExtensionAtoms"), let avcC: Data = atoms["avcC"] as? Data {
                let config = AVCConfigurationRecord(data: avcC)
                isBaseline = config.AVCProfileIndication == 66
            }
            invalidateSession = true
        }
    }
    var isRunning: Atomic<Bool> = .init(false)
    weak var delegate: VideoDecoderDelegate?
    var lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.H264Decoder.lock")

    var needsSync: Atomic<Bool> = .init(true)
    var isBaseline = true
    private var buffers: [CMSampleBuffer] = []
    private var attributes: [NSString: AnyObject] {
        H264Decoder.defaultAttributes
    }
    private var minimumGroupOfPictures: Int = H264Decoder.defaultMinimumGroupOfPictures
    private(set) var status: OSStatus = noErr {
        didSet {
            if status != noErr {
                logger.warn("\(self.status)")
            }
        }
    }
    private var invalidateSession = true

    private var _session: VTDecompressionSession?
    private var session: VTDecompressionSession! {
        get {
            if _session == nil {
                guard let formatDescription = formatDescription else {
                    return nil
                }
                guard VTDecompressionSessionCreate(
                        allocator: kCFAllocatorDefault,
                        formatDescription: formatDescription,
                        decoderSpecification: nil,
                        imageBufferAttributes: attributes as CFDictionary?,
                        outputCallback: nil,
                        decompressionSessionOut: &_session) == noErr else {
                    return nil
                }
                invalidateSession = false
            }
            return _session!
        }
        set {
            if let session: VTDecompressionSession = _session {
                VTDecompressionSessionInvalidate(session)
            }
            _session = newValue
        }
    }

    func decodeSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> OSStatus {
        if invalidateSession {
            session = nil
            needsSync.mutate { $0 = true }
        }
        if !sampleBuffer.isNotSync {
            needsSync.mutate { $0 = false }
        }
        guard let session: VTDecompressionSession = session, !needsSync.value else {
            return kVTInvalidSessionErr
        }
        var flagsOut: VTDecodeInfoFlags = []
        return VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: H264Decoder.defaultDecodeFlags,
            infoFlagsOut: &flagsOut
        ) { [unowned self]
            (status, infoFlags, imageBuffer, presentationTimeStamp, duration) in
            guard let imageBuffer = imageBuffer, status == noErr else {
                return
            }

            var timingInfo = CMSampleTimingInfo(
                duration: duration,
                presentationTimeStamp: presentationTimeStamp,
                decodeTimeStamp: .invalid
            )

            var videoFormatDescription: CMVideoFormatDescription?
            self.status = CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: imageBuffer,
                formatDescriptionOut: &videoFormatDescription
            )

            var sampleBuffer: CMSampleBuffer?
            self.status = CMSampleBufferCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: imageBuffer,
                dataReady: true,
                makeDataReadyCallback: nil,
                refcon: nil,
                formatDescription: videoFormatDescription!,
                sampleTiming: &timingInfo,
                sampleBufferOut: &sampleBuffer
            )

            guard let buffer = sampleBuffer else {
                return
            }

            if self.isBaseline {
                self.delegate?.sampleOutput(video: buffer)
            } else {
                self.buffers.append(buffer)
                self.buffers.sort {
                    $0.presentationTimeStamp < $1.presentationTimeStamp
                }
                if self.minimumGroupOfPictures <= buffers.count {
                    self.delegate?.sampleOutput(video: buffers.removeFirst())
                }
            }
        }
    }

    #if os(iOS)
    @objc
    private func applicationWillEnterForeground(_ notification: Notification) {
        invalidateSession = true
    }

    @objc
    private func didAudioSessionInterruption(_ notification: Notification) {
        guard
            let userInfo: [AnyHashable: Any] = notification.userInfo,
            let value: NSNumber = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber,
            let type: AVAudioSession.InterruptionType = AVAudioSession.InterruptionType(rawValue: value.uintValue) else {
            return
        }
        switch type {
        case .ended:
            invalidateSession = true
        default:
            break
        }
    }
    #endif
}

extension H264Decoder: Running {
    // MARK: Running
    func startRunning() {
        lockQueue.async {
            self.isRunning.mutate { $0 = true }
            #if os(iOS)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.didAudioSessionInterruption),
                name: AVAudioSession.interruptionNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.applicationWillEnterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
            #endif
        }
    }

    func stopRunning() {
        lockQueue.async {
            self.session = nil
            self.needsSync.mutate { $0 = true }
            self.invalidateSession = true
            self.buffers.removeAll()
            self.formatDescription = nil
            #if os(iOS)
            NotificationCenter.default.removeObserver(self)
            #endif
            self.isRunning.mutate { $0 = false }
        }
    }
}
