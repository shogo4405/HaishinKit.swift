import Foundation

enum RTMPFrameType:UInt8 {
    case Key = 1
    case Inter = 2
    case Disposable = 3
    case Generated = 4
    case Command = 5
}

enum RTMPAVCPacketType:UInt8 {
    case Seq = 0
    case Nal = 1
    case Eos = 2
}

enum RTMPAACPacketType:UInt8 {
    case Seq = 0
    case Raw = 1
}

enum RTMPAudioCodec:UInt8 {
    case PCM = 0
    case ADPCM = 1
    case MP3 = 2
    case PCMLE = 3
    case Nellymoser16K = 4
    case Nellymoser8K = 5
    case Nellymoser = 6
    case G711A = 7
    case G711MU = 8
    case AAC = 10
    case Speex = 11
    case MP3_8k = 14
}

enum RTMPSoundRate:UInt8 {
    case KHz5_5 = 0
    case KHz11 = 1
    case KHz22 = 2
    case KHz44 = 3
}

enum RTMPSoundSize:UInt8 {
    case Snd8bit = 0
    case Snd16bit = 1
}

enum RTMPSoundType:UInt8 {
    case Mono = 0
    case Stereo = 1
}

enum RTMPVideoCodec:UInt8 {
    case SORENSON_H263 = 2
    case SCREEN_1 = 3
    case ON2_VP6 = 4
    case ON2_VP6_ALPHA = 5
    case SCREEN_2 = 6
    case AVC = 7
}

enum RTMPSampleType:UInt8 {
    case Video = 0
    case Audio = 1

    var headerSize:Int {
        switch self {
        case .Video:
            return 5
        case .Audio:
            return 2
        }
    }
}

protocol RTMPMuxerDelegate: class {
    func sampleOutput(muxer:RTMPMuxer, type:RTMPSampleType, timestamp:Double, buffer:NSData)
    func didSetSampleTables(muxer:RTMPMuxer, sampleTables:[MP4SampleTable])
}

final class RTMPMuxer: MP4Sampler {
    var sampleTypes:Dictionary<Int, RTMPSampleType> = [:]
    var timestamps:Dictionary<Int, Double> = [:]
    var configurationChanged:Bool = true
    weak var delegate:RTMPMuxerDelegate? = nil

    override var sampleTables:[MP4SampleTable] {
        didSet {
            if (!configurationChanged) {
                return
            }

            sampleTypes.removeAll(keepCapacity: false)
            delegate?.didSetSampleTables(self, sampleTables: sampleTables)

            for i in 0..<sampleTables.count {

                if let avcC:MP4Box = sampleTables[i].trak.getBoxesByName("avcC").first {
                    sampleTypes[i] = RTMPSampleType.Video
                    let buffer:NSMutableData = NSMutableData()
                    var data:[UInt8] = [0x00, RTMPAVCPacketType.Seq.rawValue, 0x00, 0x00, 0x00]
                    data[0] = RTMPFrameType.Key.rawValue << 4 | RTMPVideoCodec.AVC.rawValue
                    buffer.appendBytes(&data, length: data.count)
                    buffer.appendData(currentFile.readDataOfBox(avcC))
                    delegate?.sampleOutput(self, type: RTMPSampleType.Video, timestamp: 0, buffer: buffer)
                    timestamps[i] = 0
                }
                
                if let esds:MP4ElementaryStreamDescriptorBox = sampleTables[i].trak.getBoxesByName("esds").first as? MP4ElementaryStreamDescriptorBox {
                    sampleTypes[i] = RTMPSampleType.Audio
                    let buffer:NSMutableData = NSMutableData()
                    var data:[UInt8] = [0x00, RTMPAACPacketType.Seq.rawValue]
                    data[0] = RTMPAudioCodec.AAC.rawValue << 4 | RTMPSoundRate.KHz44.rawValue << 2 | RTMPSoundSize.Snd16bit.rawValue << 1 | RTMPSoundType.Stereo.rawValue
                    data += esds.audioDecorderSpecificConfig
                    buffer.appendBytes(&data, length: data.count)
                    delegate?.sampleOutput(self, type: RTMPSampleType.Audio, timestamp: 0, buffer: buffer)
                    timestamps[i] = 0
                }
            }
            
            configurationChanged = false
        }
    }

    override init() {
        super.init()
    }

    override func sampleOutput(index:Int, buffer:NSData, timestamp:Double, keyframe:Bool) {
        let type:RTMPSampleType? = sampleTypes[index]

        if (type == nil) {
            return
        }

        let mutableBuffer:NSMutableData = NSMutableData()
        var data:[UInt8] = [UInt8](count: type!.headerSize, repeatedValue: 0x00)

        switch type! {
        case RTMPSampleType.Video:
            data[0] = ((keyframe ? RTMPFrameType.Key.rawValue : RTMPFrameType.Inter.rawValue) << 4) | RTMPVideoCodec.AVC.rawValue
            data[1] = RTMPAVCPacketType.Nal.rawValue
            break
        case RTMPSampleType.Audio:
            // XXX: 実際のデータの内容に関わらず固定です
            data[0] = RTMPAudioCodec.AAC.rawValue << 4 | RTMPSoundRate.KHz44.rawValue << 2 | RTMPSoundSize.Snd16bit.rawValue << 1 | RTMPSoundType.Stereo.rawValue
            data[1] = RTMPAACPacketType.Raw.rawValue
            break
        }

        mutableBuffer.appendBytes(&data, length: data.count)
        mutableBuffer.appendData(buffer)

        delegate?.sampleOutput(self, type: type!, timestamp: timestamps[index]!, buffer: mutableBuffer)
        timestamps[index] = timestamp + (timestamps[index]! - floor(timestamps[index]!))
    }

    func createMetadata(sampleTables:[MP4SampleTable]) -> ECMAObject {
        var metadata:ECMAObject = ECMAObject()

        for sampleTable in sampleTables {
            if let avc1:MP4VisualSampleEntryBox = sampleTable.trak.getBoxesByName("avc1").first as? MP4VisualSampleEntryBox {
                metadata["width"] = avc1.width
                metadata["height"] = avc1.height
                metadata["videocodecid"] = RTMPVideoCodec.AVC.rawValue
            }

            if let mp4a:MP4AudioSampleEntryBox = sampleTable.trak.getBoxesByName("mp4a").first as? MP4AudioSampleEntryBox {
                metadata["audiocodecid"] = RTMPAudioCodec.AAC.rawValue
                metadata["audiodatarate"] = mp4a.sampleRate
                metadata["audiochannels"] = mp4a.channelCount
                metadata["audiosamplerate"] = mp4a.sampleRate
                metadata["audiosamplesize"] = mp4a.sampleSize
            }
        }

        return metadata
    }
}
