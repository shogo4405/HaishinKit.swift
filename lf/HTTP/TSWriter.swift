import CoreMedia
import Foundation
import CryptoSwift

// MARK: - TSWriter
class TSWriter {
    static let defaultPMTPID:UInt16 = 4096
    static let defaultVideoPID:UInt16 = 256
    static let defaultAudioPID:UInt16 = 257
    static let defaultSegmentCount:Int = 3
    static let defaultSegmentMaxCount:Int = 12
    static let defaultSegmentDuration:Double = 5

    var playlist:String {
        var m3u8:M3U = M3U()
        if (sequence <= TSWriter.defaultSegmentMaxCount) {
            m3u8.mediaSequence = 0
            m3u8.mediaList = files
            return m3u8.description
        }
        m3u8.mediaSequence = sequence - TSWriter.defaultSegmentMaxCount
        m3u8.targetDuration = segmentDuration
        m3u8.mediaList = Array(files[files.count - TSWriter.defaultSegmentCount..<files.count])
        return m3u8.description
    }
    let lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.TSWriter.lock", DISPATCH_QUEUE_SERIAL
    )

    var segmentMaxCount:Int = TSWriter.defaultSegmentMaxCount
    var segmentDuration:Double = TSWriter.defaultSegmentDuration

    private(set) var PAT:ProgramAssociationSpecific = {
        let PAT:ProgramAssociationSpecific = ProgramAssociationSpecific()
        PAT.programs = [1: TSWriter.defaultPMTPID]
        return PAT
    }()
    private(set) var PMT:ProgramMapSpecific = {
        let PMT:ProgramMapSpecific = ProgramMapSpecific()
        var data:ElementaryStreamSpecificData = ElementaryStreamSpecificData()
        data.elementaryPID = TSWriter.defaultVideoPID
        data.streamType = 27
        PMT.PCRPID = TSWriter.defaultVideoPID
        PMT.elementaryStreamSpecificData.append(data)
        return PMT
    }()
    private(set) var files:[M3UMediaInfo] = []
    private(set) var running:Bool = false

    private var sequence:Int = 0
    private var config:AVCConfigurationRecord?
    private var timestamp:CMTime = kCMTimeZero
    private var PCRTimestamp:CMTime = kCMTimeZero
    private var currentFileURL:NSURL?
    private var rotatedTimestamp:CMTime = kCMTimeZero
    private var continuityCounter:UInt8 = 8
    private var currentFileHandle:NSFileHandle? {
        didSet {
            oldValue?.closeFile()
        }
    }
    private var currentSampleBuffer:CMSampleBuffer?

    func getFilePath(fileName:String) -> String? {
        for info in files {
            if (info.url.absoluteString.containsString(fileName)) {
                return info.url.path!
            }
        }
        return nil
    }

    func writeSampleBuffer(sampleBuffer:CMSampleBuffer) {
        if (timestamp == kCMTimeZero) {
            timestamp = sampleBuffer.presentationTimeStamp
            PCRTimestamp = sampleBuffer.presentationTimeStamp
            currentSampleBuffer = sampleBuffer
            return
        }
        guard
            let config:AVCConfigurationRecord = config,
                currentSampleBuffer:CMSampleBuffer = currentSampleBuffer,
            var PES:PacketizedElementaryStream = PacketizedElementaryStream(
                sampleBuffer: sampleBuffer,
                timestamp: timestamp,
                config: sampleBuffer.dependsOnOthers ? nil : config
            ) else {
            return
        }
        PES.streamID = 224
        let decodeTimeStamp:CMTime = currentSampleBuffer.decodeTimeStamp
        var packets:[TSPacket] = split(TSWriter.defaultVideoPID, PES: PES, timestamp: decodeTimeStamp)
        if (rorateFileHandle(decodeTimeStamp, next: sampleBuffer.decodeTimeStamp)) {
            packets[0].adaptationField?.randomAccessIndicator = true
            packets[0].adaptationField?.discontinuityIndicator = true
        }
        for var packet in packets {
            packet.continuityCounter = continuityCounter
            continuityCounter = (continuityCounter + 1) & 0xf
            currentFileHandle?.writeData(NSData(bytes: packet.bytes))
        }
        self.currentSampleBuffer = sampleBuffer
    }

    func split(PID:UInt16, PES:PacketizedElementaryStream, timestamp:CMTime) -> [TSPacket] {
        var PCR:UInt64?
        let duration:Double = timestamp.seconds - PCRTimestamp.seconds
        if (0.1 <= duration) {
            PCR = UInt64((timestamp.seconds - self.timestamp.seconds) * TSTimestamp.resolution)
            PCRTimestamp = timestamp
        }
        var packets:[TSPacket] = []
        for packet in PES.arrayOfPackets(PID, PCR: PCR) {
            packets.append(packet)
        }
        return packets
    }

    func rorateFileHandle(timestamp:CMTime, next:CMTime) -> Bool {
        let duration:Double = timestamp.seconds - rotatedTimestamp.seconds
        if (duration <= segmentDuration) {
            return false
        }
        let temp:String = NSTemporaryDirectory()
        let fileManager:NSFileManager = NSFileManager.defaultManager()
        let filename:String = Int(timestamp.seconds).description + ".ts"
        let url:NSURL = NSURL(fileURLWithPath: temp + filename)

        if let currentFileURL:NSURL = currentFileURL {
            files.append(M3UMediaInfo(url: currentFileURL, duration: duration))
            sequence += 1
        }
    
        fileManager.createFileAtPath(url.path!, contents: nil, attributes: nil)
        if (TSWriter.defaultSegmentMaxCount <= files.count) {
            let info:M3UMediaInfo = files.removeFirst()
            do { try fileManager.removeItemAtURL(info.url) }
            catch let e as NSError { logger.warning("\(e)") }
        }

        currentFileURL = url
        continuityCounter = 0
        currentFileHandle = try? NSFileHandle(forWritingToURL: url)
        var packets:[TSPacket] = []
        packets += PAT.arrayOfPackets(0)
        packets += PMT.arrayOfPackets(4096)
        for packet in packets {
            currentFileHandle?.writeData(NSData(bytes: packet.bytes))
        }

        rotatedTimestamp = timestamp
        return true
    }

    func removeFiles() {
        let fileManager:NSFileManager = NSFileManager.defaultManager()
        for info in files {
            do { try fileManager.removeItemAtURL(info.url) }
            catch let e as NSError { logger.warning("\(e)") }
        }
        files.removeAll()
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
            self.removeFiles()
            self.running = false
        }
    }
}

// MARK: VideoEncoderDelegate
extension TSWriter: VideoEncoderDelegate {
    func didSetFormatDescription(video formatDescription: CMFormatDescriptionRef?) {
        dispatch_async(lockQueue) {
            guard let
                formatDescription:CMFormatDescriptionRef = formatDescription,
                avcC:NSData = AVCConfigurationRecord.getData(formatDescription) else {
                return
            }
            self.config = AVCConfigurationRecord(data: avcC)
        }
    }

    func sampleOutput(video sampleBuffer: CMSampleBuffer) {
        dispatch_async(lockQueue) {
            self.writeSampleBuffer(sampleBuffer)
        }
    }
}
