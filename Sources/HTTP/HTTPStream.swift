import Foundation
import AVFoundation

public class HTTPStream: Stream {
    private(set) var name:String?
    private var tsWriter:TSWriter = TSWriter()

    public func publish(name:String?) {
        dispatch_async(lockQueue) {
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
