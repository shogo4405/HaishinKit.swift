import CoreMedia
import Foundation

class TSWriter {
    static let defaultPATPID:UInt16 = 0
    static let defaultPMTPID:UInt16 = 4095
    static let defaultVideoPID:UInt16 = 256
    static let defaultAudioPID:UInt16 = 257
    static let defaultSegmentCount:Int = 3
    static let defaultSegmentMaxCount:Int = 12
    static let defaultSegmentDuration:Double = 2

    var playlist:String {
        var m3u8:M3U = M3U()
        m3u8.targetDuration = segmentDuration
        if (sequence <= TSWriter.defaultSegmentMaxCount) {
            m3u8.mediaSequence = 0
            m3u8.mediaList = files
            return m3u8.description
        }
        let startIndex = max(0, files.count - TSWriter.defaultSegmentCount)
        m3u8.mediaSequence = sequence - TSWriter.defaultSegmentMaxCount
        m3u8.mediaList = Array(files[startIndex..<files.count])
        return m3u8.description
    }
    var lockQueue:DispatchQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.TSWriter.lock")
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
    private var currentFileURL:URL?
    private var rotatedTimestamp:CMTime = kCMTimeZero
    private var currentFileHandle:FileHandle?
    private var continuityCounters:[UInt16:UInt8] = [:]

    func getFilePath(_ fileName:String) -> String? {
        for info in files {
            if (info.url.absoluteString.contains(fileName)) {
                return info.url.path
            }
        }
        return nil
    }

    func writeSampleBuffer(_ PID:UInt16, streamID:UInt8, sampleBuffer:CMSampleBuffer) {
        let presentationTimeStamp:CMTime = sampleBuffer.presentationTimeStamp
        if (timestamps[PID] == nil) {
            timestamps[PID] = presentationTimeStamp
            if (PCRPID == PID) {
                PCRTimestamp = presentationTimeStamp
            }
        }

        let config:Any? = streamID == 192 ? audioConfig : videoConfig
        guard var PES:PacketizedElementaryStream = PacketizedElementaryStream.create(
            sampleBuffer, timestamp:timestamps[PID]!, config:config
        ) else {
            return
        }

        PES.streamID = streamID

        var decodeTimeStamp:CMTime = sampleBuffer.decodeTimeStamp
        if (decodeTimeStamp == kCMTimeInvalid) {
            decodeTimeStamp = presentationTimeStamp
        }

        var packets:[TSPacket] = split(PID, PES: PES, timestamp: decodeTimeStamp)
        let _:Bool = rotateFileHandle(decodeTimeStamp)

        if (streamID == 192) {
            packets[0].adaptationField?.randomAccessIndicator = true
        } else {
            packets[0].adaptationField?.randomAccessIndicator = !sampleBuffer.dependsOnOthers
        }

        var bytes:Data = Data()
        for var packet in packets {
            packet.continuityCounter = continuityCounters[PID]!
            continuityCounters[PID] = (continuityCounters[PID]! + 1) & 0x0f
            bytes.append(packet.data)
        }

        nstry({
            self.currentFileHandle?.write(bytes)
        }){ exception in
            self.currentFileHandle?.write(bytes)
            logger.warn("\(exception)")
        }
    }

    func split(_ PID:UInt16, PES:PacketizedElementaryStream, timestamp:CMTime) -> [TSPacket] {
        var PCR:UInt64?
        let duration:Double = timestamp.seconds - PCRTimestamp.seconds
        if (PCRPID == PID && 0.02 <= duration) {
            PCR = UInt64((timestamp.seconds - timestamps[PID]!.seconds) * TSTimestamp.resolution)
            PCRTimestamp = timestamp
        }
        var packets:[TSPacket] = []
        for packet in PES.arrayOfPackets(PID, PCR: PCR) {
            packets.append(packet)
        }
        return packets
    }

    func rotateFileHandle(_ timestamp:CMTime) -> Bool {
        let duration:Double = timestamp.seconds - rotatedTimestamp.seconds
        if (duration <= segmentDuration) {
            return false
        }

        let fileManager:FileManager = FileManager.default

        #if os(OSX)
        let bundleIdentifier:String? = Bundle.main.bundleIdentifier
        let temp:String = bundleIdentifier == nil ? NSTemporaryDirectory() : NSTemporaryDirectory() + bundleIdentifier! + "/"
        #else
        let temp:String = NSTemporaryDirectory()
        #endif

        if !fileManager.fileExists(atPath: temp) {
            do {
                try fileManager.createDirectory(atPath: temp, withIntermediateDirectories: false, attributes: nil)
            } catch let error as NSError {
                logger.warn("\(error)")
            }
        }

        let filename:String = Int(timestamp.seconds).description + ".ts"
        let url:URL = URL(fileURLWithPath: temp + filename)

        if let currentFileURL:URL = currentFileURL {
            files.append(M3UMediaInfo(url: currentFileURL, duration: duration))
            sequence += 1
        }
    
        fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)
        if (TSWriter.defaultSegmentMaxCount <= files.count) {
            let info:M3UMediaInfo = files.removeFirst()
            do { try fileManager.removeItem(at: info.url as URL) }
            catch let e as NSError { logger.warn("\(e)") }
        }
        currentFileURL = url
        for (pid, _) in continuityCounters {
            continuityCounters[pid] = 0
        }
        
        nstry({
            self.currentFileHandle?.synchronizeFile()
        }) { exeption in
            logger.warn("\(exeption)")
        }
        
        currentFileHandle?.closeFile()
        currentFileHandle = try? FileHandle(forWritingTo: url)

        PMT.PCRPID = PCRPID
        var bytes:Data = Data()
        var packets:[TSPacket] = []
        packets.append(contentsOf: PAT.arrayOfPackets(TSWriter.defaultPATPID))
        packets.append(contentsOf: PMT.arrayOfPackets(TSWriter.defaultPMTPID))
        for packet in packets {
            bytes.append(packet.data)
        }

        nstry({
            self.currentFileHandle?.write(bytes)
        }){ exception in
            logger.warn("\(exception)")
        }
        rotatedTimestamp = timestamp

        return true
    }

    func removeFiles() {
        let fileManager:FileManager = FileManager.default
        for info in files {
            do { try fileManager.removeItem(at: info.url as URL) }
            catch let e as NSError { logger.warn("\(e)") }
        }
        files.removeAll()
    }
}

extension TSWriter: Runnable {
    // MARK: Runnable
    func startRunning() {
        lockQueue.async {
            guard self.running else {
                return
            }
            self.running = true
        }
    }
    func stopRunning() {
        lockQueue.async {
            guard !self.running else {
                return
            }
            self.currentFileURL = nil
            self.currentFileHandle = nil
            self.removeFiles()
            self.running = false
        }
    }
}

extension TSWriter: AudioEncoderDelegate {
    // MARK: AudioEncoderDelegate
    func didSetFormatDescription(audio formatDescription: CMFormatDescription?) {
        guard let formatDescription:CMAudioFormatDescription = formatDescription else {
            return
        }
        audioConfig = AudioSpecificConfig(formatDescription: formatDescription)
        var data:ElementaryStreamSpecificData = ElementaryStreamSpecificData()
        data.streamType = ElementaryStreamType.adtsaac.rawValue
        data.elementaryPID = TSWriter.defaultAudioPID
        PMT.elementaryStreamSpecificData.append(data)
        continuityCounters[TSWriter.defaultAudioPID] = 0
    }

    func sampleOutput(audio sampleBuffer: CMSampleBuffer) {
        writeSampleBuffer(TSWriter.defaultAudioPID, streamID:192, sampleBuffer:sampleBuffer)
    }
}

extension TSWriter: VideoEncoderDelegate {
    // MARK: VideoEncoderDelegate
    func didSetFormatDescription(video formatDescription: CMFormatDescription?) {
        guard
            let formatDescription:CMFormatDescription = formatDescription,
            let avcC:Data = AVCConfigurationRecord.getData(formatDescription) else {
            return
        }
        videoConfig = AVCConfigurationRecord(data: avcC)
        var data:ElementaryStreamSpecificData = ElementaryStreamSpecificData()
        data.streamType = ElementaryStreamType.h264.rawValue
        data.elementaryPID = TSWriter.defaultVideoPID
        PMT.elementaryStreamSpecificData.append(data)
        continuityCounters[TSWriter.defaultVideoPID] = 0
    }

    func sampleOutput(video sampleBuffer: CMSampleBuffer) {
        writeSampleBuffer(TSWriter.defaultVideoPID, streamID:224, sampleBuffer:sampleBuffer)
    }
}
