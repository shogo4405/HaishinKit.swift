import CoreMedia
import Foundation

// MARK: - TSWriter
class TSWriter {
    static let version:UInt8 = 3
    static let defaultVideoPID:UInt16 = 256
    static let defaultAudioPID:UInt16 = 257
    static let defaultSegmentTimeInterval:NSTimeInterval = 5

    var playlist:String {
        var lines:[String] = [
            "#EXTM3U",
            "#EXT-X-VERSION:\(TSWriter.version)",
            "#EXT-X-MEDIA-SEQUENCE:0",
            "#EXT-X-ALLOW-CACHE:" + (allowCache ? "YES" : "NO"),
            "#EXT-X-TARGETDURATION:\(Int(segmentTimeInterval))"
        ]
        for i in 0..<files.count {
            guard let pathComponents:[String] = files[i].pathComponents else {
                continue
            }
            lines.append("#EXTINF:\(durations[i]),")
            lines.append(pathComponents.last!)
        }
        return lines.joinWithSeparator("\r\n")
    }

    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.TSWriter.lock", DISPATCH_QUEUE_SERIAL
    )
    var allowCache:Bool = true
    var mediaSequence:Int = 0
    var segmentTimeInterval:NSTimeInterval = TSWriter.defaultSegmentTimeInterval
    private(set) var running:Bool = false
    private(set) var files:[NSURL] = []
    private(set) var durations:[Double] = []

    private var timestamp:CMTime = kCMTimeZero
    private var currentFileURL:NSURL?
    private var currentFileHandle:NSFileHandle? {
        didSet {
            oldValue?.closeFile()
        }
    }

    func getFilePath(fileName:String) -> String? {
        for file in files {
            if (file.absoluteString.containsString(fileName)) {
                return file.path!
            }
        }
        return nil
    }

    func writePacketizedElementaryStream(PID:UInt16, PES: PacketizedElementaryStream) {
        dispatch_async(lockQueue) {
            for packet in PES.arrayOfPackets(PID) {
                self.currentFileHandle?.writeData(NSData(bytes: packet.bytes))
            }
        }
    }

    private func rorateFileHandle(timestamp:CMTime) {
        let duration:Double = CMTimeGetSeconds(timestamp) - CMTimeGetSeconds(self.timestamp)
        if (duration < segmentTimeInterval) {
            return
        }
        let temp:String = NSTemporaryDirectory()
        let fileManager:NSFileManager = NSFileManager.defaultManager()
        let filename:String = Int(CMTimeGetSeconds(timestamp)).description + ".ts"
        let url:NSURL = NSURL(fileURLWithPath: temp + filename)
        do {
            if let currentFileURL:NSURL = currentFileURL {
                files.append(currentFileURL)
                durations.append(duration)
            }
            fileManager.createFileAtPath(url.path!, contents: nil, attributes: nil)
            currentFileURL = url
            currentFileHandle = try NSFileHandle(forWritingToURL: url)
        } catch let error as NSError {
            logger.error("\(error)")
        }
        self.timestamp = timestamp
    }
}

// MARK: Runnable
extension TSWriter: Runnable {
    func startRunning() {
        dispatch_async(lockQueue) {
            if (!self.running) {
                return
            }
            self.running = true
        }
    }

    func stopRunning() {
        dispatch_async(lockQueue) {
            if (self.running) {
                return
            }
            self.currentFileURL = nil
            self.currentFileHandle = nil
            self.files.removeAll()
            self.running = false
        }
    }
}

// MARK: VideoEncoderDelegate
extension TSWriter: VideoEncoderDelegate {
    func didSetFormatDescription(video formatDescription: CMFormatDescriptionRef?) {
    }
    func sampleOutput(video sampleBuffer: CMSampleBuffer) {
        guard let pes:PacketizedElementaryStream = PacketizedElementaryStream(sampleBuffer: sampleBuffer) else {
            return
        }
        var timestamp:CMTime = sampleBuffer.decodeTimeStamp
        if (timestamp == kCMTimeInvalid) {
            timestamp = sampleBuffer.presentationTimeStamp
        }
        rorateFileHandle(timestamp)
        writePacketizedElementaryStream(TSWriter.defaultVideoPID, PES: pes)
    }
}
