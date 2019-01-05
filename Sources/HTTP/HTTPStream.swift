import AVFoundation

open class HTTPStream: NetStream {
    private(set) var name: String?
    private lazy var tsWriter = TSFileWriter()

    open func publish(_ name: String?) {
        lockQueue.async {
            if name == nil {
                self.name = name
                #if os(iOS)
                self.mixer.videoIO.screen?.stopRunning()
                #endif
                self.mixer.stopEncoding()
                self.tsWriter.stopRunning()
                return
            }
            self.name = name
            #if os(iOS)
            self.mixer.videoIO.screen?.startRunning()
            #endif
            self.mixer.startEncoding(delegate: self.tsWriter)
            self.mixer.startRunning()
            self.tsWriter.startRunning()
        }
    }

    #if os(iOS) || os(macOS)
    override open func attachCamera(_ camera: AVCaptureDevice?, onError: ((NSError) -> Void)? = nil) {
        if camera == nil {
            tsWriter.expectedMedias.remove(.video)
        } else {
            tsWriter.expectedMedias.insert(.video)
        }
        super.attachCamera(camera, onError: onError)
    }

    override open func attachAudio(_ audio: AVCaptureDevice?, automaticallyConfiguresApplicationAudioSession: Bool = true, onError: ((NSError) -> Void)? = nil) {
        if audio == nil {
            tsWriter.expectedMedias.remove(.audio)
        } else {
            tsWriter.expectedMedias.insert(.audio)
        }
        super.attachAudio(audio, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession, onError: onError)
    }
    #endif

    func getResource(_ resourceName: String) -> (MIME, String)? {
        let url = URL(fileURLWithPath: resourceName)
        guard let name: String = name, 2 <= url.pathComponents.count && url.pathComponents[1] == name else {
            return nil
        }
        let fileName: String = url.pathComponents.last!
        switch true {
        case fileName == "playlist.m3u8":
            return (.applicationXMpegURL, tsWriter.playlist)
        case fileName.contains(".ts"):
            if let mediaFile: String = tsWriter.getFilePath(fileName) {
                return (.videoMP2T, mediaFile)
            }
            return nil
        default:
            return nil
        }
    }
}
