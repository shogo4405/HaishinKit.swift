import CoreMedia
import Foundation

// MARK: - TSWriter
class TSWriter {
    static let version:UInt8 = 3
    static let defaultPMTPID:UInt16 = 4096
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
    var segmentTimeInterval:NSTimeInterval = TSWriter.defaultSegmentTimeInterval
    private(set) var PAT:ProgramAssociationSpecific = {
        let PAT:ProgramAssociationSpecific = ProgramAssociationSpecific()
        PAT.programs = [1: TSWriter.defaultPMTPID]
        return PAT
    }()
    private(set) var PMT:ProgramMapSpecific = {
        let PMT:ProgramMapSpecific = ProgramMapSpecific()
        var essd:ElementaryStreamSpecificData = ElementaryStreamSpecificData()
        essd.elementaryPID = TSWriter.defaultVideoPID
        essd.streamType = 27
        PMT.PCRPID = TSWriter.defaultVideoPID
        PMT.elementaryStreamSpecificData.append(essd)
        return PMT
    }()
    private(set) var running:Bool = false
    private(set) var files:[NSURL] = []
    private(set) var durations:[Double] = []

    private var clock:NSDate = NSDate()
    private var config:AVCConfigurationRecord?
    private var timestamp:NSDate = NSDate()
    private var currentFileURL:NSURL?
    private var videoTimestamp:CMTime = kCMTimeZero
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
            var PCR:UInt64?
            if (self.timestamp.timeIntervalSinceNow < -0.1) {
                PCR = UInt64(abs(self.clock.timeIntervalSinceNow) * TSProgramClockReference.resolutionForExtension)
                self.timestamp = NSDate()
            }
            for packet in PES.arrayOfPackets(PID, PCR: PCR) {
                self.currentFileHandle?.writeData(NSData(bytes: packet.bytes))
            }
        }
    }

    private func rorateFileHandle(timestamp:CMTime) {
        let duration:Double = CMTimeGetSeconds(timestamp) - CMTimeGetSeconds(videoTimestamp)
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
            var packets:[TSPacket] = []
            packets += PAT.arrayOfPackets(0)
            packets += PMT.arrayOfPackets(4096)
            for packet in packets {
                self.currentFileHandle?.writeData(NSData(bytes: packet.bytes))
            }
        } catch let error as NSError {
            logger.error("\(error)")
        }
        videoTimestamp = timestamp
    }
}

// MARK: Runnable
extension TSWriter: Runnable {
    func startRunning() {
        dispatch_async(lockQueue) {
            if (!self.running) {
                return
            }
            self.clock = NSDate()
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
        guard let
            formatDescription:CMFormatDescriptionRef = formatDescription,
            avcC:NSData = AVCConfigurationRecord.getData(formatDescription) else {
            return
        }
        config = AVCConfigurationRecord(data: avcC)
    }
    func sampleOutput(video sampleBuffer: CMSampleBuffer) {
        guard let config:AVCConfigurationRecord = config,
            var pes:PacketizedElementaryStream = PacketizedElementaryStream(sampleBuffer: sampleBuffer, config: config) else {
            return
        }
        var timestamp:CMTime = sampleBuffer.decodeTimeStamp
        if (timestamp == kCMTimeInvalid) {
            timestamp = sampleBuffer.presentationTimeStamp
        }
        rorateFileHandle(timestamp)
        pes.streamID = 224
        writePacketizedElementaryStream(TSWriter.defaultVideoPID, PES: pes)
    }
}
