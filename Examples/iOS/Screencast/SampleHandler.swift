import HaishinKit
@preconcurrency import Logboard
import MediaPlayer
import ReplayKit
import VideoToolbox

nonisolated let logger = LBLogger.with(kHaishinKitIdentifier)

@available(iOS 10.0, *)
final class SampleHandler: RPBroadcastSampleHandler, @unchecked Sendable {
    private var slider: UISlider?

    private var _rotator: Any?
    @available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
    private var rotator: VideoRotator? {
        get {
            _rotator as? VideoRotator
        }
        set {
            _rotator = newValue
        }
    }

    private var isVideoRotationEnabled = false {
        didSet {
            if isVideoRotationEnabled, #available(iOS 16.0, tvOS 16.0, macOS 13.0, *) {
                _rotator = VideoRotator()
            } else {
                _rotator = nil
            }
        }
    }
    private var mixer = MediaMixer(multiCamSessionEnabled: false, multiTrackAudioMixingEnabled: true)
    private let netStreamSwitcher = HKStreamSwitcher()
    private var needVideoConfiguration = true

    override init() {
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        /*
         let socket = SocketAppender()
         socket.connect("192.168.1.9", port: 22222)
         logger.level = .debug
         logger.appender = socket
         logger.level = .debug
         */
        LBLogger.with(kHaishinKitIdentifier).level = .info
        // mixer.audioMixerSettings.tracks[1] = .default
        isVideoRotationEnabled = false
        Task {
            await netStreamSwitcher.setPreference(Preference.default)
            // ReplayKit is sensitive to memory, so we limit the queue to a maximum of five items.
            if let stream = await netStreamSwitcher.stream {
                var videoSetting = await mixer.videoMixerSettings
                videoSetting.mode = .passthrough
                await stream.setVideoInputBufferCounts(5)
                await mixer.setVideoMixerSettings(videoSetting)
                await mixer.addOutput(stream)
            }
            await netStreamSwitcher.open(.ingest)
        }
        // The volume of the audioApp can be obtained even when muted. A hack to synchronize with the volume.
        DispatchQueue.main.async {
            let volumeView = MPVolumeView(frame: CGRect.zero)
            if let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first {
                self.slider = slider
            }
        }
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            Task {
                if needVideoConfiguration, let dimensions = sampleBuffer.formatDescription?.dimensions {
                    var videoSettings = await netStreamSwitcher.stream?.videoSettings
                    videoSettings?.videoSize = .init(
                        width: CGFloat(dimensions.width),
                        height: CGFloat(dimensions.height)
                    )
                    videoSettings?.profileLevel = kVTProfileLevel_H264_Baseline_AutoLevel as String
                    if let videoSettings {
                        await netStreamSwitcher.stream?.setVideoSettings(videoSettings)
                    }
                    needVideoConfiguration = false
                }
            }
            if #available(iOS 16.0, tvOS 16.0, macOS 13.0, *), let rotator {
                switch rotator.rotate(buffer: sampleBuffer) {
                case .success(let rotatedBuffer):
                    Task { await mixer.append(rotatedBuffer) }
                case .failure(let error):
                    logger.error(error)
                }
            } else {
                Task { await mixer.append(sampleBuffer) }
            }
        case .audioMic:
            if sampleBuffer.dataReadiness == .ready {
                Task { await mixer.append(sampleBuffer, track: 0) }
            }
        case .audioApp:
            Task { @MainActor in
                if let volume = slider?.value {
                    var audioMixerSettings = await mixer.audioMixerSettings
                    audioMixerSettings.tracks[1] = .default
                    audioMixerSettings.tracks[1]?.volume = volume * 0.5
                    await mixer.setAudioMixerSettings(audioMixerSettings)
                }
            }
            if sampleBuffer.dataReadiness == .ready {
                Task { await mixer.append(sampleBuffer, track: 1) }
            }
        @unknown default:
            break
        }
    }
}
