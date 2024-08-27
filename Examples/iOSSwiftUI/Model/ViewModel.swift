import AVFoundation
import Combine
import HaishinKit
import Logboard
import PhotosUI
import SwiftUI
import VideoToolbox

final class ViewModel: ObservableObject {
    let maxRetryCount: Int = 5

    private var mixer = MediaMixer()
    private var rtmpConnection = RTMPConnection()
    @Published var rtmpStream: RTMPStream!
    private var sharedObject: RTMPSharedObject!
    private var currentEffect: (any VideoEffect)?
    @Published var currentPosition: AVCaptureDevice.Position = .back
    private var retryCount: Int = 0
    @Published var published = false
    @Published var zoomLevel: CGFloat = 1.0
    @Published var videoRate = CGFloat(VideoCodecSettings.default.bitRate / 1000)
    @Published var audioRate = CGFloat(AudioCodecSettings.default.bitRate / 1000)
    @Published var fps: String = "FPS"
    private var nc = NotificationCenter.default

    var subscriptions = Set<AnyCancellable>()

    var frameRate: String = "30.0" {
        willSet {
            Task {
                await mixer.setFrameRate(Float64(newValue) ?? 30.0)
            }
            objectWillChange.send()
        }
    }

    var videoEffect: String = "None" {
        willSet {
            Task {
                if let currentEffect {
                    _ = await mixer.screen.unregisterVideoEffect(currentEffect)
                }

                switch newValue {
                case "Monochrome":
                    currentEffect = MonochromeEffect()
                    _ = await mixer.screen.registerVideoEffect(currentEffect!)

                case "Pronoma":
                    print("case Pronoma")
                    currentEffect = PronamaEffect()
                    _ = await mixer.screen.registerVideoEffect(currentEffect!)

                default:
                    break
                }
            }

            objectWillChange.send()
        }
    }

    var videoEffectData = ["None", "Monochrome", "Pronoma"]

    var frameRateData = ["15.0", "30.0", "60.0"]

    func config() {
        rtmpStream = RTMPStream(connection: rtmpConnection)
        Task {
            // rtmpStream = RTMPStream(connection: rtmpConnection)
            if let orientation = await DeviceUtil.videoOrientation(by: UIDevice.current.orientation) {
                await mixer.setVideoOrientation(orientation)
            }

            await mixer.addOutput(rtmpStream)

            await mixer.setSessionPreset(.hd1280x720)
            checkDeviceAuthorization()
        }
    }

    func checkDeviceAuthorization() {
        let requiredAccessLevel: PHAccessLevel = .readWrite
        PHPhotoLibrary.requestAuthorization(for: requiredAccessLevel) { authorizationStatus in
            switch authorizationStatus {
            case .limited:
                logger.info("limited authorization granted")
            case .authorized:
                logger.info("authorization granted")
            default:
                logger.info("Unimplemented")
            }
        }
    }

    func registerForPublishEvent() {
        Task {
            try? await mixer.attachAudio(AVCaptureDevice.default(for: .audio))
            try? await mixer.attachVideo(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition))
        }
    }

    func unregisterForPublishEvent() {
        Task {
            try? await rtmpStream.close()
        }
    }

    func startPublish() {
        Task { @MainActor in
            UIApplication.shared.isIdleTimerDisabled = true
            logger.info(Preference.default.uri!)
            try? await rtmpConnection.connect(Preference.default.uri!)
        }
    }

    func stopPublish() {
        Task { @MainActor in
            UIApplication.shared.isIdleTimerDisabled = false
            try? await rtmpConnection.close()
        }
    }

    func toggleTorch() {
        Task {
            await mixer.setTorchEnabled(await !mixer.isTorchEnabled)
        }
    }

    func pausePublish() {
    }

    func tapScreen(touchPoint: CGPoint) {
        Task {
            let pointOfInterest = await CGPoint(x: touchPoint.x / UIScreen.main.bounds.size.width, y: touchPoint.y / UIScreen.main.bounds.size.height)
            logger.info("pointOfInterest: \(pointOfInterest)")
            try? await mixer.configuration(video: 0) { unit in
                guard let device = unit.device, device.isFocusPointOfInterestSupported else {
                    return
                }
                try device.lockForConfiguration()
                device.focusPointOfInterest = pointOfInterest
                device.focusMode = .continuousAutoFocus
                device.unlockForConfiguration()
            }
        }
    }

    func rotateCamera() {
        Task {
            let position: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
            try? await mixer.attachVideo(AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position))
            currentPosition = position
        }
    }

    func changeZoomLevel(level: CGFloat) {
        Task {
            try? await mixer.configuration(video: 0) { unit in
                guard let device = unit.device, 1 <= level && level < device.activeFormat.videoMaxZoomFactor else {
                    return
                }
                try device.lockForConfiguration()
                device.ramp(toVideoZoomFactor: level, withRate: 5.0)
                device.unlockForConfiguration()
            }
        }
    }

    func changeVideoRate(level: CGFloat) {
        Task {
            var videoSettings = await rtmpStream.videoSettings
            videoSettings.bitRate = Int(level * 1000)
            await rtmpStream.setVideoSettings(videoSettings)
        }
    }

    func changeAudioRate(level: CGFloat) {
        Task {
            var audioSettings = await rtmpStream.audioSettings
            audioSettings.bitRate = Int(level * 1000)
            await rtmpStream.setAudioSettings(audioSettings)
        }
    }
}
