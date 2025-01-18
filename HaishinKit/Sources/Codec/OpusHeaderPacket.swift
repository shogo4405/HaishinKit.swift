import CoreMedia
import Foundation

struct OpusHeaderPacket {
    static let signature = "OpusHead"

    let channels: Int
    let sampleRate: Double

    var payload: Data {
        var data = Data()
        data.append(contentsOf: Self.signature.utf8)
        data.append(0x01)
        data.append(UInt8(channels))
        data.append(UInt16(0).data)
        data.append(UInt32(sampleRate).data)
        data.append(UInt16(0).data)
        data.append(0x00)
        return data
    }

    init?(formatDescription: CMFormatDescription?) {
        guard
            let streamDescription = formatDescription?.audioStreamBasicDescription else {
            return nil
        }
        channels = Int(streamDescription.mChannelsPerFrame)
        sampleRate = streamDescription.mSampleRate
    }
}
