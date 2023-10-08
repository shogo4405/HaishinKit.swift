import AVFoundation

extension AVAudioPCMBuffer {
    final func makeSampleBuffer(_ when: AVAudioTime) -> CMSampleBuffer? {
        var status: OSStatus = noErr
        var sampleBuffer: CMSampleBuffer?
        status = CMAudioSampleBufferCreateWithPacketDescriptions(
            allocator: nil,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format.formatDescription,
            sampleCount: Int(frameLength),
            presentationTimeStamp: when.makeTime(),
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        )
        guard let sampleBuffer else {
            logger.warn("CMAudioSampleBufferCreateWithPacketDescriptions returned errorr: ", status)
            return nil
        }
        status = CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: audioBufferList
        )
        if status != noErr {
            logger.warn("CMSampleBufferSetDataBufferFromAudioBufferList returned errorr: ", status)
        }
        return sampleBuffer
    }

    final func copy(_ audioPCMBuffer: AVAudioBuffer) -> Bool {
        guard let audioPCMBuffer = audioPCMBuffer as? AVAudioPCMBuffer, frameLength == audioPCMBuffer.frameLength else {
            return false
        }
        let numSamples = Int(frameLength)
        if format.isInterleaved {
            let channelCount = Int(format.channelCount)
            switch format.commonFormat {
            case .pcmFormatInt16:
                memcpy(int16ChannelData?[0], audioPCMBuffer.int16ChannelData?[0], numSamples * channelCount * 2)
            case .pcmFormatInt32:
                memcpy(int32ChannelData?[0], audioPCMBuffer.int32ChannelData?[0], numSamples * channelCount * 4)
            case .pcmFormatFloat32:
                memcpy(floatChannelData?[0], audioPCMBuffer.floatChannelData?[0], numSamples * channelCount * 4)
            default:
                break
            }
        } else {
            for i in 0..<Int(format.channelCount) {
                switch format.commonFormat {
                case .pcmFormatInt16:
                    memcpy(int16ChannelData?[i], audioPCMBuffer.int16ChannelData?[i], numSamples * 2)
                case .pcmFormatInt32:
                    memcpy(int32ChannelData?[i], audioPCMBuffer.int32ChannelData?[i], numSamples * 4)
                case .pcmFormatFloat32:
                    memcpy(floatChannelData?[i], audioPCMBuffer.floatChannelData?[i], numSamples * 4)
                default:
                    break
                }
            }
        }
        return true
    }

    final func muted() {
        let numSamples = Int(frameLength)
        if format.isInterleaved {
            let channelCount = Int(format.channelCount)
            switch format.commonFormat {
            case .pcmFormatInt16:
                int16ChannelData?[0].update(repeating: 0, count: numSamples * channelCount)
            case .pcmFormatInt32:
                int32ChannelData?[0].update(repeating: 0, count: numSamples * channelCount)
            case .pcmFormatFloat32:
                floatChannelData?[0].update(repeating: 0, count: numSamples * channelCount)
            default:
                break
            }
        } else {
            for i in 0..<Int(format.channelCount) {
                switch format.commonFormat {
                case .pcmFormatInt16:
                    int16ChannelData?[i].update(repeating: 0, count: numSamples)
                case .pcmFormatInt32:
                    int32ChannelData?[i].update(repeating: 0, count: numSamples)
                case .pcmFormatFloat32:
                    floatChannelData?[i].update(repeating: 0, count: numSamples)
                default:
                    break
                }
            }
        }
    }
}
