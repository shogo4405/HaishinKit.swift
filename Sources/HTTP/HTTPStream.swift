import Foundation
import AVFoundation

open class HTTPStream: NetStream {
    private(set) var name:String?
    private var tsWriter:TSWriter = TSWriter()

    open func publish(_ name:String?) {
        lockQueue.async {
            if (name == nil) {
                self.name = name
                #if os(iOS)
                self.mixer.videoIO.screen?.stopRunning()
                #endif
                self.mixer.videoIO.encoder.delegate = nil
                self.mixer.videoIO.encoder.stopRunning()
                self.mixer.audioIO.encoder.delegate = nil
                self.mixer.audioIO.encoder.stopRunning()
                self.tsWriter.stopRunning()
                return
            }
            self.name = name
            #if os(iOS)
            self.mixer.videoIO.screen?.startRunning()
            #endif
            self.mixer.videoIO.encoder.delegate = self.tsWriter
            self.mixer.videoIO.encoder.startRunning()
            self.mixer.audioIO.encoder.delegate = self.tsWriter
            self.mixer.audioIO.encoder.startRunning()
            self.tsWriter.startRunning()
        }
    }

    func getResource(_ resourceName:String) -> (MIME, String)? {
        let url:URL = URL(fileURLWithPath: resourceName)
        guard let name:String = name, 2 <= url.pathComponents.count && url.pathComponents[1] == name else {
            return nil
        }
        let fileName:String = url.pathComponents.last!
        switch true {
        case fileName == "playlist.m3u8":
            return (.ApplicationXMpegURL, tsWriter.playlist)
        case fileName.contains(".ts"):
            if let mediaFile:String = tsWriter.getFilePath(fileName) {
                return (.VideoMP2T, mediaFile)
            }
            return nil
        default:
            return nil
        }
    }
}
