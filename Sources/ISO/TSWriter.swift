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
    /// Specifies the delegate instance.
    public weak var delegate: T?
    /// Specifies the exptected medias = [.video, .audio].
    public var expectedMedias: Set<AVMediaType> = []
    /// Specifies the audio format.
    public var audioFormat: AVAudioFormat? {
        didSet {
            guard let audioFormat, audioFormat != oldValue else {
                return
            }
            var data = ESSpecificData()
            data.streamType = audioFormat.formatDescription.streamType
            data.elementaryPID = kTSWriter_defaultAudioPID
            PMT.elementaryStreamSpecificData.append(data)
            audioContinuityCounter = 0
            writeProgramIfNeeded()
        }
    }
    /// Specifies the video format.
    public var videoFormat: CMFormatDescription? {
        didSet {
            guard let videoFormat, videoFormat != oldValue else {
                return
            }
            var data = ESSpecificData()
            data.streamType = videoFormat.streamType
            data.elementaryPID = kTSWriter_defaultVideoPID
            PMT.elementaryStreamSpecificData.append(data)
            videoContinuityCounter = 0
            writeProgramIfNeeded()
        }
    }

    private(set) var PAT: TSProgramAssociation = {
        let PAT: TSProgramAssociation = .init()
        PAT.programs = [1: kTSWriter_defaultPMTPID]
        return PAT
    }()
    private(set) var PMT: TSProgramMap = .init()
    private var PCRPID: UInt16 = kTSWriter_defaultVideoPID
    private var canWriteFor: Bool {
        guard !expectedMedias.isEmpty else {
            return true
        }
        if expectedMedias.contains(.audio) && expectedMedias.contains(.video) {
            return audioFormat != nil && videoFormat != nil
        }
        if expectedMedias.contains(.video) {
            return videoFormat != nil
        }
        if expectedMedias.contains(.audio) {
            return audioFormat != nil
        }
        return false
    }
    private var videoTimeStamp: CMTime = .invalid
    private var audioTimeStamp: CMTime = .invalid
    private var clockTimeStamp: CMTime = .zero
    private var segmentDuration: Double = kTSWriter_defaultSegmentDuration
    private var rotatedTimeStamp: CMTime = .zero
    private var audioContinuityCounter: UInt8 = 0
    private var videoContinuityCounter: UInt8 = 0

    /// Creates a new instance with segument duration.
    public init(segmentDuration: Double = 2.0) {
        self.segmentDuration = segmentDuration
    }

    /// Appends a buffer.
    public func append(_ audioBuffer: AVAudioBuffer, when: AVAudioTime) {
        guard let audioBuffer = audioBuffer as? AVAudioCompressedBuffer, canWriteFor else {
            return
        }
        if audioTimeStamp == .invalid {
            audioTimeStamp = when.makeTime()
            if PCRPID == kTSWriter_defaultAudioPID {
                clockTimeStamp = audioTimeStamp
            }
        }
        if var pes = PacketizedElementaryStream(audioBuffer, when: when, timeStamp: audioTimeStamp) {
            pes.streamID = 192
            writePacketizedElementaryStream(
                kTSWriter_defaultAudioPID,
                PES: pes,
                timeStamp: when.makeTime(),
                randomAccessIndicator: true
            )
        }
    }

    /// Appends a buffer.
    public func append(_ sampleBuffer: CMSampleBuffer) {
        guard canWriteFor else {
            return
        }
        switch sampleBuffer.formatDescription?.mediaType {
        case .video?:
            if videoTimeStamp == .invalid {
                videoTimeStamp = sampleBuffer.presentationTimeStamp
                if PCRPID == kTSWriter_defaultVideoPID {
                    clockTimeStamp = videoTimeStamp
                }
            }
            if var pes = PacketizedElementaryStream(sampleBuffer, timeStamp: videoTimeStamp) {
                let timestamp = sampleBuffer.decodeTimeStamp == .invalid ?
                    sampleBuffer.presentationTimeStamp : sampleBuffer.decodeTimeStamp
                pes.streamID = 224
                writePacketizedElementaryStream(
                    kTSWriter_defaultVideoPID,
                    PES: pes,
                    timeStamp: timestamp,
                    randomAccessIndicator: !sampleBuffer.isNotSync
                )
            }
        default:
            break
        }
    }

    /// Clears the writer object for new transport stream.
    public func clear() {
        audioContinuityCounter = 0
        videoContinuityCounter = 0
        PCRPID = kTSWriter_defaultVideoPID
        PAT.programs.removeAll()
        PAT.programs = [1: kTSWriter_defaultPMTPID]
        PMT = TSProgramMap()
        videoTimeStamp = .invalid
        audioTimeStamp = .invalid
        clockTimeStamp = .zero
    }

    private func writePacketizedElementaryStream(_ PID: UInt16, PES: PacketizedElementaryStream, timeStamp: CMTime, randomAccessIndicator: Bool) {
        let packets: [TSPacket] = split(PID, PES: PES, timestamp: timeStamp)
        rotateFileHandle(timeStamp)

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

    private func rotateFileHandle(_ timestamp: CMTime) {
        let duration = timestamp.seconds - rotatedTimeStamp.seconds
        guard segmentDuration < duration else {
            return
        }
        writeProgramIfNeeded()
        rotatedTimeStamp = timestamp
        delegate?.writer(self, didRotateFileHandle: timestamp)
    }

    private func write(_ data: Data) {
        delegate?.writer(self, didOutput: data)
    }

    private func writeProgram() {
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

    private func writeProgramIfNeeded() {
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
        let duration: Double = timestamp.seconds - clockTimeStamp.seconds
        if PCRPID == PID && 0.02 <= duration {
            PCR = UInt64((timestamp.seconds - (PID == kTSWriter_defaultVideoPID ? videoTimeStamp : audioTimeStamp).seconds) * TSTimestamp.resolution)
            clockTimeStamp = timestamp
        }
        var packets: [TSPacket] = []
        for packet in PES.arrayOfPackets(PID, PCR: PCR) {
            packets.append(packet)
        }
        return packets
    }
}
