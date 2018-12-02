import CoreMedia
import Foundation
import AVFoundation

/// MPEG-2 TS (Transport Stream) Writer delegate
public protocol TSWriterDelegate: class {
    func didOutput(_ data: Data)
}

/// MPEG-2 TS (Transport Stream) Writer Foundation class
public class TSWriter: Running {
    static public let defaultPATPID: UInt16 = 0
    static public let defaultPMTPID: UInt16 = 4095
    static public let defaultVideoPID: UInt16 = 256
    static public let defaultAudioPID: UInt16 = 257
    static let defaultSegmentDuration: Double = 2

    /// The delegate instance.
    public weak var delegate: TSWriterDelegate?
    /// This instance is running to process(true) or not(false).
    public internal(set) var isRunning: Bool = false
    /// The exptected medias = [.video, .audio].
    public var expectedMedias: Set<AVMediaType> = []

    var audioContinuityCounter: UInt8 = 0
    var videoContinuityCounter: UInt8 = 0
    var PCRPID: UInt16 = TSWriter.defaultVideoPID
    var rotatedTimestamp: CMTime = CMTime.zero
    var segmentDuration: Double = TSWriter.defaultSegmentDuration
    private(set) var PAT: ProgramAssociationSpecific = {
        let PAT: ProgramAssociationSpecific = .init()
        PAT.programs = [1: TSWriter.defaultPMTPID]
        return PAT
    }()
    private(set) var PMT: ProgramMapSpecific = .init()
    private var audioConfig: AudioSpecificConfig? {
        didSet {
            writeProgram()
        }
    }
    private var audioTimestamp: CMTime = .invalid
    private var videoConfig: AVCConfigurationRecord? {
        didSet {
            writeProgram()
        }
    }
    private var videoTimestamp: CMTime = .invalid
    private var PCRTimestamp: CMTime = .invalid
    private var canWriteFor: Bool {
        guard expectedMedias.isEmpty else { return true }
        if expectedMedias.contains(.audio) && expectedMedias.contains(.video) {
            return audioConfig != nil && videoConfig != nil
        }
        if expectedMedias.contains(.video) {
            return videoConfig != nil
        }
        if expectedMedias.contains(.audio) {
            return audioConfig != nil
        }
        return false
    }

    public init() {
    }

    // swiftlint:disable function_parameter_count
    final func writeSampleBuffer(_ PID: UInt16, streamID: UInt8, bytes: UnsafePointer<UInt8>?, count: UInt32, presentationTimeStamp: CMTime, decodeTimeStamp: CMTime, randomAccessIndicator: Bool) {
        guard canWriteFor else { return }

        switch PID {
        case TSWriter.defaultAudioPID:
            guard audioTimestamp == .invalid else { break }
            audioTimestamp = presentationTimeStamp
        case TSWriter.defaultVideoPID:
            guard videoTimestamp == .invalid else { break }
            videoTimestamp = presentationTimeStamp
        default:
            break
        }

        if PCRPID == PID {
            PCRTimestamp = presentationTimeStamp
        }

        guard var PES = PacketizedElementaryStream.create(
            bytes,
            count: count,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: decodeTimeStamp,
            timestamp: PID == TSWriter.defaultVideoPID ? videoTimestamp : audioTimestamp,
            config: streamID == 192 ? audioConfig : videoConfig,
            randomAccessIndicator: randomAccessIndicator) else {
            return
        }

        PES.streamID = streamID
        var packets: [TSPacket] = split(PID, PES: PES, timestamp: decodeTimeStamp)
        packets[0].adaptationField?.randomAccessIndicator = randomAccessIndicator
        rotateFileHandle(decodeTimeStamp == CMTime.invalid ? presentationTimeStamp : decodeTimeStamp)

        var bytes: Data = Data()
        for var packet in packets {
            switch PID {
            case TSWriter.defaultAudioPID:
                packet.continuityCounter = audioContinuityCounter
                audioContinuityCounter = (audioContinuityCounter + 1) & 0x0f
            case TSWriter.defaultVideoPID:
                packet.continuityCounter = videoContinuityCounter
                videoContinuityCounter = (videoContinuityCounter + 1) & 0x0f
            default:
                break
            }
            bytes.append(packet.data)
        }

        write(bytes)
    }

    func rotateFileHandle(_ timestamp: CMTime) {
        let duration: Double = timestamp.seconds - rotatedTimestamp.seconds
        if duration <= segmentDuration {
            return
        }
        writeProgram()
        rotatedTimestamp = timestamp
    }

    func write(_ data: Data) {
        delegate?.didOutput(data)
    }

    func writeProgram() {
        PMT.PCRPID = PCRPID
        var bytes: Data = Data()
        var packets: [TSPacket] = []
        packets.append(contentsOf: PAT.arrayOfPackets(TSWriter.defaultPATPID))
        packets.append(contentsOf: PMT.arrayOfPackets(TSWriter.defaultPMTPID))
        for packet in packets {
            bytes.append(packet.data)
        }
        write(bytes)
    }

    func writeProgramIfNeeded() {
        guard !expectedMedias.isEmpty else { return }
        guard canWriteFor else { return }
        writeProgram()
    }

    public func startRunning() {
        guard isRunning else {
            return
        }
        isRunning = true
    }

    public func stopRunning() {
        guard !isRunning else {
            return
        }
        audioContinuityCounter = 0
        videoContinuityCounter = 0
        PCRPID = TSWriter.defaultVideoPID
        PAT.programs.removeAll()
        PAT.programs = [1: TSWriter.defaultPMTPID]
        PMT = ProgramMapSpecific()
        audioConfig = nil
        videoConfig = nil
        videoTimestamp = .invalid
        audioTimestamp = .invalid
        PCRTimestamp = .invalid
        isRunning = false
    }

    private func split(_ PID: UInt16, PES: PacketizedElementaryStream, timestamp: CMTime) -> [TSPacket] {
        let timestamp = PID == TSWriter.defaultVideoPID ? videoTimestamp : audioTimestamp
        var PCR: UInt64?
        let duration: Double = timestamp.seconds - PCRTimestamp.seconds
        if PCRPID == PID && 0.02 <= duration {
            PCR = UInt64((timestamp.seconds - timestamp.seconds) * TSTimestamp.resolution)
            PCRTimestamp = timestamp
        }
        var packets: [TSPacket] = []
        for packet in PES.arrayOfPackets(PID, PCR: PCR) {
            packets.append(packet)
        }
        return packets
    }
}

extension TSWriter: AudioEncoderDelegate {
    // MARK: AudioEncoderDelegate
    func didSetFormatDescription(audio formatDescription: CMFormatDescription?) {
        guard let formatDescription: CMAudioFormatDescription = formatDescription else {
            return
        }
        var data: ElementaryStreamSpecificData = ElementaryStreamSpecificData()
        data.streamType = ElementaryStreamType.adtsaac.rawValue
        data.elementaryPID = TSWriter.defaultAudioPID
        PMT.elementaryStreamSpecificData.append(data)
        audioContinuityCounter = 0
        audioConfig = AudioSpecificConfig(formatDescription: formatDescription)
    }

    func sampleOutput(audio bytes: UnsafePointer<UInt8>?, count: UInt32, presentationTimeStamp: CMTime) {
        writeSampleBuffer(
            TSWriter.defaultAudioPID,
            streamID: 192,
            bytes: bytes,
            count: count,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: CMTime.invalid,
            randomAccessIndicator: true
        )
    }
}

extension TSWriter: VideoEncoderDelegate {
    // MARK: VideoEncoderDelegate
    func didSetFormatDescription(video formatDescription: CMFormatDescription?) {
        guard
            let formatDescription: CMFormatDescription = formatDescription,
            let avcC: Data = AVCConfigurationRecord.getData(formatDescription) else {
            return
        }
        var data: ElementaryStreamSpecificData = ElementaryStreamSpecificData()
        data.streamType = ElementaryStreamType.h264.rawValue
        data.elementaryPID = TSWriter.defaultVideoPID
        PMT.elementaryStreamSpecificData.append(data)
        videoContinuityCounter = 0
        videoConfig = AVCConfigurationRecord(data: avcC)
    }

    func sampleOutput(video sampleBuffer: CMSampleBuffer) {
        guard let dataBuffer = sampleBuffer.dataBuffer else {
            return
        }
        var length: Int = 0
        var buffer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &buffer) == noErr else {
            return
        }
        guard let bytes = buffer else {
            return
        }
        writeSampleBuffer(
            TSWriter.defaultVideoPID,
            streamID: 224,
            bytes: UnsafeRawPointer(bytes).bindMemory(to: UInt8.self, capacity: length),
            count: UInt32(length),
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            decodeTimeStamp: sampleBuffer.decodeTimeStamp,
            randomAccessIndicator: !sampleBuffer.dependsOnOthers
        )
    }
}

class TSFileWriter: TSWriter {
    static let defaultSegmentCount: Int = 3
    static let defaultSegmentMaxCount: Int = 12

    var segmentMaxCount: Int = TSFileWriter.defaultSegmentMaxCount
    private(set) var files: [M3UMediaInfo] = []
    private var currentFileHandle: FileHandle?
    private var currentFileURL: URL?
    private var sequence: Int = 0

    var playlist: String {
        var m3u8: M3U = M3U()
        m3u8.targetDuration = segmentDuration
        if sequence <= TSFileWriter.defaultSegmentMaxCount {
            m3u8.mediaSequence = 0
            m3u8.mediaList = files
            for mediaItem in m3u8.mediaList where mediaItem.duration > m3u8.targetDuration {
                m3u8.targetDuration = mediaItem.duration + 1
            }
            return m3u8.description
        }
        let startIndex = max(0, files.count - TSFileWriter.defaultSegmentCount)
        m3u8.mediaSequence = sequence - TSFileWriter.defaultSegmentMaxCount
        m3u8.mediaList = Array(files[startIndex..<files.count])
        for mediaItem in m3u8.mediaList where mediaItem.duration > m3u8.targetDuration {
            m3u8.targetDuration = mediaItem.duration + 1
        }
        return m3u8.description
    }

    override func rotateFileHandle(_ timestamp: CMTime) {
        let duration: Double = timestamp.seconds - rotatedTimestamp.seconds
        if duration <= segmentDuration {
            return
        }

        let fileManager: FileManager = FileManager.default

        #if os(OSX)
        let bundleIdentifier: String? = Bundle.main.bundleIdentifier
        let temp: String = bundleIdentifier == nil ? NSTemporaryDirectory() : NSTemporaryDirectory() + bundleIdentifier! + "/"
        #else
        let temp: String = NSTemporaryDirectory()
        #endif

        if !fileManager.fileExists(atPath: temp) {
            do {
                try fileManager.createDirectory(atPath: temp, withIntermediateDirectories: false, attributes: nil)
            } catch let error as NSError {
                logger.warn("\(error)")
            }
        }

        let filename: String = Int(timestamp.seconds).description + ".ts"
        let url: URL = URL(fileURLWithPath: temp + filename)

        if let currentFileURL: URL = currentFileURL {
            files.append(M3UMediaInfo(url: currentFileURL, duration: duration))
            sequence += 1
        }

        fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)
        if TSFileWriter.defaultSegmentMaxCount <= files.count {
            let info: M3UMediaInfo = files.removeFirst()
            do {
                try fileManager.removeItem(at: info.url as URL)
            } catch let e as NSError {
                logger.warn("\(e)")
            }
        }
        currentFileURL = url
        audioContinuityCounter = 0
        videoContinuityCounter = 0

        nstry({
            self.currentFileHandle?.synchronizeFile()
        }, { exeption in
            logger.warn("\(exeption)")
        })

        currentFileHandle?.closeFile()
        currentFileHandle = try? FileHandle(forWritingTo: url)

        writeProgram()

        rotatedTimestamp = timestamp
    }

    override func write(_ data: Data) {
        nstry({
            self.currentFileHandle?.write(data)
        }, { exception in
            logger.warn("\(exception)")
        })
        super.write(data)
    }

    override func stopRunning() {
        guard !isRunning else {
            return
        }
        currentFileURL = nil
        currentFileHandle = nil
        removeFiles()
        super.stopRunning()
    }

    func getFilePath(_ fileName: String) -> String? {
        return files.first { $0.url.absoluteString.contains(fileName) }?.url.path
    }

    private func removeFiles() {
        let fileManager: FileManager = FileManager.default
        for info in files {
            do {
                try fileManager.removeItem(at: info.url as URL)
            } catch let e as NSError {
                logger.warn("\(e)")
            }
        }
        files.removeAll()
    }
}
