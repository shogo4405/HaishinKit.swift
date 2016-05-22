import CoreMedia
import Foundation
import CryptoSwift

class TSWriter {
    static let defaultPATPID:UInt16 = 0
    static let defaultPMTPID:UInt16 = 4096
    static let defaultVideoPID:UInt16 = 256
    static let defaultAudioPID:UInt16 = 257
    static let defaultSegmentCount:Int = 3
    static let defaultSegmentMaxCount:Int = 12
    static let defaultSegmentDuration:Double = 2

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
    var lockQueue:dispatch_queue_t = dispatch_queue_create(
        "com.github.shogo4405.lf.TSWriter.lock", DISPATCH_QUEUE_SERIAL
    )
    var segmentMaxCount:Int = TSWriter.defaultSegmentMaxCount
    var segmentDuration:Double = TSWriter.defaultSegmentDuration

    private(set) var PAT:ProgramAssociationSpecific = {
        let PAT:ProgramAssociationSpecific = ProgramAssociationSpecific()
        PAT.programs = [1: TSWriter.defaultPMTPID]
        return PAT
    }()
    private(set) var PMT:ProgramMapSpecific = ProgramMapSpecific()
    private(set) var files:[M3UMediaInfo] = []
    private(set) var running:Bool = false

    private var PCRPID:UInt16 = TSWriter.defaultVideoPID
    private var sequence:Int = 0
    private var timestamps:[UInt16:CMTime] = [:]
    private var audioConfig:AudioSpecificConfig?
    private var videoConfig:AVCConfigurationRecord?
    private var PCRTimestamp:CMTime = kCMTimeZero
    private var currentFileURL:NSURL?
    private var rotatedTimestamp:CMTime = kCMTimeZero
    private var currentFileHandle:NSFileHandle?
    private var continuityCounters:[UInt16:UInt8] = [:]

    func getFilePath(fileName:String) -> String? {
        for info in files {
            if (info.url.absoluteString.containsString(fileName)) {
                return info.url.path!
            }
        }
        return nil
    }

    func writeSampleBuffer(PID:UInt16, streamID:UInt8, sampleBuffer:CMSampleBuffer) {
        if (timestamps[PID] == nil) {
            timestamps[PID] = sampleBuffer.presentationTimeStamp
            if (PCRPID == PID) {
                PCRTimestamp = sampleBuffer.presentationTimeStamp
            }
        }
        let config:Any? = streamID == 192 ? audioConfig : videoConfig
        guard var PES:PacketizedElementaryStream = PacketizedElementaryStream.create(
            sampleBuffer, timestamp:timestamps[PID]!, config:config
        ) else {
            return
        }
        PES.streamID = streamID
        let decodeTimeStamp:CMTime = sampleBuffer.decodeTimeStamp
        var packets:[TSPacket] = split(PID, PES: PES, timestamp: decodeTimeStamp)
        if (PCRPID == PID && rorateFileHandle(decodeTimeStamp, next: sampleBuffer.decodeTimeStamp)) {
            packets[0].adaptationField?.randomAccessIndicator = true
            packets[0].adaptationField?.discontinuityIndicator = true
        }

        var bytes:[UInt8] = []
        for var packet in packets {
            packet.continuityCounter = continuityCounters[PID]!
            continuityCounters[PID] = (continuityCounters[PID]! + 1) & 0x0f
            bytes += packet.bytes
        }
        tryc({
            self.currentFileHandle?.writeData(NSData(bytes: bytes))
        }){ exception in
            self.currentFileHandle?.writeData(NSData(bytes: bytes))
            logger.warning("\(exception)")
        }
    }

    func split(PID:UInt16, PES:PacketizedElementaryStream, timestamp:CMTime) -> [TSPacket] {
        var PCR:UInt64?
        let duration:Double = timestamp.seconds - PCRTimestamp.seconds
        if (PCRPID == PID && 0.1 <= duration) {
            PCR = UInt64((timestamp.seconds - timestamps[PID]!.seconds) * TSTimestamp.resolution)
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

        let fileManager:NSFileManager = NSFileManager.defaultManager()

        #if os(OSX)
        let bundleIdentifier:String? = NSBundle.mainBundle().bundleIdentifier
        let temp:String = bundleIdentifier == nil ? NSTemporaryDirectory() : NSTemporaryDirectory() + bundleIdentifier! + "/"
        #else
        let temp:String = NSTemporaryDirectory()
        #endif

        if !fileManager.fileExistsAtPath(temp) {
            do {
                try fileManager.createDirectoryAtPath(temp, withIntermediateDirectories: false, attributes: nil)
            } catch let error as NSError {
                logger.warning("\(error)")
            }
        }

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
        for (pid, _) in continuityCounters {
            continuityCounters[pid] = 0
        }
        currentFileHandle?.synchronizeFile()
        currentFileHandle?.closeFile()
        currentFileHandle = try? NSFileHandle(forWritingToURL: url)
        var bytes:[UInt8] = []
        var packets:[TSPacket] = []
        packets += PAT.arrayOfPackets(TSWriter.defaultPATPID)
        packets += PMT.arrayOfPackets(TSWriter.defaultPMTPID)
        for packet in packets {
            bytes += packet.bytes
        }

        tryc({
            self.currentFileHandle?.writeData(NSData(bytes: bytes))
        }){ exception in
            logger.warning("\(exception)")
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

// MARK: AudioEncoderDelegate
extension TSWriter: AudioEncoderDelegate {
    func didSetFormatDescription(audio formatDescription: CMFormatDescriptionRef?) {
        guard let
            formatDescription:CMAudioFormatDescriptionRef = formatDescription else {
            return
        }
        audioConfig = AudioSpecificConfig(formatDescription: formatDescription)
        var data:ElementaryStreamSpecificData = ElementaryStreamSpecificData()
        data.streamType = ElementaryStreamType.ADTSAAC.rawValue
        data.elementaryPID = TSWriter.defaultAudioPID
        PMT.elementaryStreamSpecificData.append(data)
        continuityCounters[TSWriter.defaultAudioPID] = 0
    }

    func sampleOutput(audio sampleBuffer: CMSampleBuffer) {
        writeSampleBuffer(TSWriter.defaultAudioPID, streamID:192, sampleBuffer:sampleBuffer)
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
        videoConfig = AVCConfigurationRecord(data: avcC)
        var data:ElementaryStreamSpecificData = ElementaryStreamSpecificData()
        data.streamType = ElementaryStreamType.H264.rawValue
        data.elementaryPID = TSWriter.defaultVideoPID
        PMT.elementaryStreamSpecificData.append(data)
        continuityCounters[TSWriter.defaultVideoPID] = 0
    }

    func sampleOutput(video sampleBuffer: CMSampleBuffer) {
        writeSampleBuffer(TSWriter.defaultVideoPID, streamID:224, sampleBuffer:sampleBuffer)
    }
}
