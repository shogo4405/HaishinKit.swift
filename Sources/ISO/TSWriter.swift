import AVFoundation
import CoreMedia
import Foundation

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif

/// The interface an MPEG-2 TS (Transport Stream) writer uses to inform its delegates.
public protocol TSWriterDelegate: AnyObject {
    func writer(_ writer: TSWriter<Self>, didRotateFileHandle timestamp: CMTime)
    func writer(_ writer: TSWriter<Self>, didOutput data: Data)
}

private let kTSWriter_defaultPATPID: UInt16 = 0
private let kTSWriter_defaultPMTPID: UInt16 = 4095
private let kTSWriter_defaultVideoPID: UInt16 = 256
private let kTSWriter_defaultAudioPID: UInt16 = 257
private let kTSWriter_defaultSegmentDuration: Double = 2

/// The TSWriter class represents writes MPEG-2 transport stream data.
public final class TSWriter<T: TSWriterDelegate> {
    /// The delegate instance.
    public weak var delegate: T?
    /// This instance is running to process(true) or not(false).
    public internal(set) var isRunning: Atomic<Bool> = .init(false)
    /// The exptected medias = [.video, .audio].
    public var expectedMedias: Set<AVMediaType> = []

    public var audioFormat: AVAudioFormat? {
        didSet {
            guard let audioFormat else {
                return
            }
            var data = ESSpecificData()
            data.streamType = .adtsAac
            data.elementaryPID = kTSWriter_defaultAudioPID
            PMT.elementaryStreamSpecificData.append(data)
            audioContinuityCounter = 0
            audioConfig = AudioSpecificConfig(formatDescription: audioFormat.formatDescription)
        }
    }

    public var videoFormat: CMFormatDescription? {
        didSet {
            guard
                let videoFormat,
                let avcC = AVCDecoderConfigurationRecord.getData(videoFormat) else {
                return
            }
            var data = ESSpecificData()
            data.streamType = .h264
            data.elementaryPID = kTSWriter_defaultVideoPID
            PMT.elementaryStreamSpecificData.append(data)
            videoContinuityCounter = 0
            videoConfig = AVCDecoderConfigurationRecord(data: avcC)
        }
    }

    var audioContinuityCounter: UInt8 = 0
    var videoContinuityCounter: UInt8 = 0
    var PCRPID: UInt16 = kTSWriter_defaultVideoPID
    var rotatedTimestamp = CMTime.zero
    var segmentDuration: Double = kTSWriter_defaultSegmentDuration
    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.TSWriter.lock")

    private(set) var PAT: TSProgramAssociation = {
        let PAT: TSProgramAssociation = .init()
        PAT.programs = [1: kTSWriter_defaultPMTPID]
        return PAT
    }()
    private(set) var PMT: TSProgramMap = .init()
    private var audioConfig: AudioSpecificConfig? {
        didSet {
            writeProgramIfNeeded()
        }
    }
    private var videoConfig: AVCDecoderConfigurationRecord? {
        didSet {
            writeProgramIfNeeded()
        }
    }
    private var videoTimestamp: CMTime = .invalid
    private var audioTimestamp: CMTime = .invalid
    private var PCRTimestamp = CMTime.zero
    private var canWriteFor: Bool {
        guard !expectedMedias.isEmpty else {
            return true
        }
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

    public init(segmentDuration: Double = 2.0) {
        self.segmentDuration = segmentDuration
    }

    // swiftlint:disable:next function_parameter_count
    final func writeSampleBuffer(_ PID: UInt16, streamID: UInt8, bytes: UnsafePointer<UInt8>?, count: UInt32, presentationTimeStamp: CMTime, decodeTimeStamp: CMTime, randomAccessIndicator: Bool) {
        guard canWriteFor else {
            return
        }

        switch PID {
        case kTSWriter_defaultAudioPID:
            guard audioTimestamp == .invalid else { break }
            audioTimestamp = presentationTimeStamp
            if PCRPID == PID {
                PCRTimestamp = presentationTimeStamp
            }
        case kTSWriter_defaultVideoPID:
            guard videoTimestamp == .invalid else { break }
            videoTimestamp = presentationTimeStamp
            if PCRPID == PID {
                PCRTimestamp = presentationTimeStamp
            }
        default:
            break
        }

        guard var PES = PacketizedElementaryStream.create(
                bytes,
                count: count,
                presentationTimeStamp: presentationTimeStamp,
                decodeTimeStamp: decodeTimeStamp,
                timestamp: PID == kTSWriter_defaultVideoPID ? videoTimestamp : audioTimestamp,
                config: streamID == 192 ? audioConfig : videoConfig,
                randomAccessIndicator: randomAccessIndicator) else {
            return
        }

        PES.streamID = streamID

        let timestamp = decodeTimeStamp == .invalid ? presentationTimeStamp : decodeTimeStamp
        let packets: [TSPacket] = split(PID, PES: PES, timestamp: timestamp)
        rotateFileHandle(timestamp)

        packets[0].adaptationField?.randomAccessIndicator = randomAccessIndicator

        var bytes = Data()
        for var packet in packets {
            switch PID {
            case kTSWriter_defaultAudioPID:
                packet.continuityCounter = audioContinuityCounter
                audioContinuityCounter = (audioContinuityCounter + 1) & 0x0f
            case kTSWriter_defaultVideoPID:
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
        writeProgramIfNeeded()
        rotatedTimestamp = timestamp
        delegate?.writer(self, didRotateFileHandle: timestamp)
    }

    func write(_ data: Data) {
        delegate?.writer(self, didOutput: data)
    }

    final func writeProgram() {
        PMT.PCRPID = PCRPID
        var bytes = Data()
        var packets: [TSPacket] = []
        packets.append(contentsOf: PAT.arrayOfPackets(kTSWriter_defaultPATPID))
        packets.append(contentsOf: PMT.arrayOfPackets(kTSWriter_defaultPMTPID))
        for packet in packets {
            bytes.append(packet.data)
        }
        write(bytes)
    }

    final func writeProgramIfNeeded() {
        guard !expectedMedias.isEmpty else {
            return
        }
        guard canWriteFor else {
            return
        }
        writeProgram()
    }

    private func split(_ PID: UInt16, PES: PacketizedElementaryStream, timestamp: CMTime) -> [TSPacket] {
        var PCR: UInt64?
        let duration: Double = timestamp.seconds - PCRTimestamp.seconds
        if PCRPID == PID && 0.02 <= duration {
            PCR = UInt64((timestamp.seconds - (PID == kTSWriter_defaultVideoPID ? videoTimestamp : audioTimestamp).seconds) * TSTimestamp.resolution)
            PCRTimestamp = timestamp
        }
        var packets: [TSPacket] = []
        for packet in PES.arrayOfPackets(PID, PCR: PCR) {
            packets.append(packet)
        }
        return packets
    }
}

extension TSWriter: IOMuxer {
    // IOMuxer
    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        guard let audioBuffer = audioBuffer as? AVAudioCompressedBuffer else {
            return
        }
        writeSampleBuffer(
            kTSWriter_defaultAudioPID,
            streamID: 192,
            bytes: audioBuffer.data.assumingMemoryBound(to: UInt8.self),
            count: audioBuffer.byteLength,
            presentationTimeStamp: when.makeTime(),
            decodeTimeStamp: .invalid,
            randomAccessIndicator: true
        )
    }

    public func append(_ sampleBuffer: CMSampleBuffer) {
        guard let dataBuffer = sampleBuffer.dataBuffer else {
            return
        }
        var length = 0
        var buffer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &buffer) == noErr else {
            return
        }
        guard let bytes = buffer else {
            return
        }
        writeSampleBuffer(
            kTSWriter_defaultVideoPID,
            streamID: 224,
            bytes: UnsafeRawPointer(bytes).bindMemory(to: UInt8.self, capacity: length),
            count: UInt32(length),
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            decodeTimeStamp: sampleBuffer.decodeTimeStamp,
            randomAccessIndicator: !sampleBuffer.isNotSync
        )
    }
}

extension TSWriter: Running {
    public func startRunning() {
        guard isRunning.value else {
            return
        }
        isRunning.mutate { $0 = true }
    }

    public func stopRunning() {
        guard !isRunning.value else {
            return
        }
        audioContinuityCounter = 0
        videoContinuityCounter = 0
        PCRPID = kTSWriter_defaultVideoPID
        PAT.programs.removeAll()
        PAT.programs = [1: kTSWriter_defaultPMTPID]
        PMT = TSProgramMap()
        audioConfig = nil
        videoConfig = nil
        videoTimestamp = .invalid
        audioTimestamp = .invalid
        PCRTimestamp = .invalid
        isRunning.mutate { $0 = false }
    }
}
