import Foundation
import AVFoundation

public class HTTPStream: NSObject {

    #if os(iOS)
    public var syncOrientation:Bool {
        get { return mixer.syncOrientation }
        set { mixer.syncOrientation = newValue }
    }
    #endif

    public var view:VideoIOView {
        return mixer.videoIO.view
    }

    public var audioSettings:[String: AnyObject] {
        get { return mixer.audioIO.encoder.dictionaryWithValuesForKeys(AACEncoder.supportedSettingsKeys)}
        set { mixer.audioIO.encoder.setValuesForKeysWithDictionary(newValue) }
    }

    public var videoSettings:[String: AnyObject] {
        get { return mixer.videoIO.encoder.dictionaryWithValuesForKeys(AVCEncoder.supportedSettingsKeys)}
        set { mixer.videoIO.encoder.setValuesForKeysWithDictionary(newValue)}
    }

    public var captureSettings:[String: AnyObject] {
        get { return mixer.dictionaryWithValuesForKeys(AVMixer.supportedSettingsKeys)}
        set { dispatch_async(lockQueue) { self.mixer.setValuesForKeysWithDictionary(newValue)}}
    }

    private(set) var name:String?
    private var mixer:AVMixer = AVMixer()
    private var tsWriter:TSWriter = TSWriter()
    private let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.HTTPStream.lock", DISPATCH_QUEUE_SERIAL
    )

    public func attachCamera(camera:AVCaptureDevice?) {
        dispatch_async(lockQueue) {
            self.mixer.videoIO.attachCamera(camera)
            self.mixer.startRunning()
        }
    }

    public func attachAudio(audio:AVCaptureDevice?, _ automaticallyConfiguresApplicationAudioSession:Bool = true) {
        dispatch_async(lockQueue) {
            self.mixer.audioIO.attachAudio(audio,
                automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession
            )
        }
    }

    public func attachScreen(screen:ScreenCaptureSession?) {
        dispatch_async(lockQueue) {
            self.mixer.videoIO.attachScreen(screen)
        }
    }

    public func publish(name:String?) {
        dispatch_async(lockQueue) {
            if (name == nil) {
                self.name = name
                self.mixer.videoIO.encoder.delegate = nil
                self.mixer.videoIO.encoder.stopRunning()
                self.mixer.audioIO.encoder.delegate = nil
                self.mixer.audioIO.encoder.stopRunning()
                self.tsWriter.stopRunning()
                return
            }
            self.name = name
            self.mixer.videoIO.encoder.delegate = self.tsWriter
            self.mixer.videoIO.encoder.startRunning()
            self.mixer.audioIO.encoder.delegate = self.tsWriter
            self.mixer.audioIO.encoder.startRunning()
            self.tsWriter.startRunning()
        }
    }

    func getResource(resourceName:String) -> (MIME, String)? {
        guard let
            name:String = name,
            url:NSURL = NSURL(fileURLWithPath: resourceName),
            pathComponents:[String] = url.pathComponents
            where 2 <= pathComponents.count && pathComponents[1] == name else {
            return nil
        }
        let fileName:String = pathComponents.last!
        switch true {
        case fileName == "playlist.m3u8":
            return (.ApplicationXMpegURL, tsWriter.playlist)
        case fileName.containsString(".ts"):
            if let mediaFile:String = tsWriter.getFilePath(fileName) {
                return (.VideoMP2T, mediaFile)
            }
            return nil
        default:
            return nil
        }
    }
}
