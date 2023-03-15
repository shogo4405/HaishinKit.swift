import CoreMedia
import Foundation

struct ADTSHeader: Equatable {
    static let size: Int = 7
    static let sizeWithCrc = 9
    static let sync: UInt8 = 0xFF

    var sync = Self.sync
    var id: UInt8 = 0
    var layer: UInt8 = 0
    var protectionAbsent = false
    var profile: UInt8 = 0
    var sampleFrequencyIndex: UInt8 = 0
    var channelConfiguration: UInt8 = 0
    var originalOrCopy = false
    var home = false
    var copyrightIdBit = false
    var copyrightIdStart = false
    var aacFrameLength: UInt16 = 0
    var bufferFullness: UInt16 = 0
    var aacFrames: UInt8 = 0

    init() {
    }

    init(data: Data) {
        self.data = data
    }

    func makeFormatDescription() -> CMFormatDescription? {
        guard
            let type = AudioSpecificConfig.AudioObjectType(rawValue: profile + 1),
            let frequency = AudioSpecificConfig.SamplingFrequency(rawValue: sampleFrequencyIndex),
            let channel = AudioSpecificConfig.ChannelConfiguration(rawValue: channelConfiguration) else {
            return nil
        }
        var formatDescription: CMAudioFormatDescription?
        var audioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: frequency.sampleRate,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: UInt32(type.rawValue),
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: UInt32(channel.rawValue),
            mBitsPerChannel: 0,
            mReserved: 0
        )
        guard CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &audioStreamBasicDescription,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        ) == noErr else {
            return nil
        }
        return formatDescription
    }
}

extension ADTSHeader: DataConvertible {
    var data: Data {
        get {
            Data()
        }
        set {
            guard ADTSHeader.size <= data.count else {
                return
            }
            sync = newValue[0]
            id = (newValue[1] & 0b00001111) >> 3
            layer = (newValue[1] >> 2) & 0b00000011
            protectionAbsent = (newValue[1] & 0b00000001) == 1
            profile = newValue[2] >> 6 & 0b11
            sampleFrequencyIndex = (newValue[2] >> 2) & 0b00001111
            channelConfiguration = ((newValue[2] & 0b1) << 2) | newValue[3] >> 6
            originalOrCopy = (newValue[3] & 0b00100000) == 0b00100000
            home = (newValue[3] & 0b00010000) == 0b00010000
            copyrightIdBit = (newValue[3] & 0b00001000) == 0b00001000
            copyrightIdStart = (newValue[3] & 0b00000100) == 0b00000100
            aacFrameLength = UInt16(newValue[3] & 0b00000011) << 11 | UInt16(newValue[4]) << 3 | UInt16(newValue[5] >> 5)
            bufferFullness = UInt16(newValue[5]) >> 2 | UInt16(newValue[6] >> 2)
            aacFrames = newValue[6] & 0b00000011
        }
    }
}

class ADTSReader: Sequence {
    private var data: Data = .init()

    func read(_ data: Data) {
        self.data = data
    }

    func makeIterator() -> ADTSReaderIterator {
        return ADTSReaderIterator(data: data)
    }
}

struct ADTSReaderIterator: IteratorProtocol {
    private let data: Data
    private var cursor: Int = 0
    private var header: ADTSHeader = .init()

    init(data: Data) {
        self.data = data
    }

    mutating func next() -> Int? {
        guard cursor < data.count else {
            return nil
        }
        header.data = data.advanced(by: cursor)
        defer {
            cursor += Int(header.aacFrameLength)
        }
        return Int(header.aacFrameLength)
    }
}
