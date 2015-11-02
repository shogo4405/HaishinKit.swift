import Foundation

protocol RTMPMuxerDelegate: class {
    func sampleOutput(muxer:RTMPMuxer, type:RTMPSampleType, timestamp:Double, buffer:NSData)
}

final class RTMPMuxer: NSObject {
    var sampleTypes:[Int:RTMPSampleType] = [:]
    var timestamps:[Int:Double] = [:]
    var configurationChanged:Bool = true
    var videoSettings:[String: AnyObject] = [:]
    var audioSettings:[String: AnyObject] = [:]
    lazy var audioEncoder:AACEncoder = AACEncoder()
    lazy var videoEncoder:AVCEncoder = AVCEncoder()
    weak var delegate:RTMPMuxerDelegate? = nil

    func sampleOutput(index:Int, buffer:NSData, timestamp:Double, keyframe:Bool) {
        let type:RTMPSampleType? = sampleTypes[index]

        if (type == nil) {
            return
        }

        let mutableBuffer:NSMutableData = NSMutableData()
        var data:[UInt8] = [UInt8](count: type!.headerSize, repeatedValue: 0x00)

        switch type! {
        case RTMPSampleType.Video:
            data[0] = ((keyframe ? FLVTag.FrameType.Key.rawValue : FLVTag.FrameType.Inter.rawValue) << 4) | FLVTag.VideoCodec.AVC.rawValue
            data[1] = FLVTag.AVCPacketType.Nal.rawValue
            break
        case RTMPSampleType.Audio:
            // XXX: 実際のデータの内容に関わらず固定です
            data[0] = FLVTag.AudioCodec.AAC.rawValue << 4 | FLVTag.SoundRate.KHz44.rawValue << 2 | FLVTag.SoundSize.Snd16bit.rawValue << 1 | FLVTag.SoundType.Stereo.rawValue
            data[1] = FLVTag.AACPacketType.Raw.rawValue
            break
        }

        mutableBuffer.appendBytes(&data, length: data.count)
        mutableBuffer.appendData(buffer)

        delegate?.sampleOutput(self, type: type!, timestamp: timestamps[index]!, buffer: mutableBuffer)
        timestamps[index] = timestamp + (timestamps[index]! - floor(timestamps[index]!))
    }
}
