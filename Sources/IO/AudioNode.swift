import AVFoundation

enum AudioNodeError: Error {
    case unableToFindAudioComponent
    case unableToCreateAudioUnit(_ status: OSStatus)
    case unableToInitializeAudioUnit(_ status: OSStatus)
    case unableToUpdateBus(_ status: OSStatus)
    case unableToRetrieveValue(_ status: OSStatus)
    case unableToConnectToNode(_ status: OSStatus)
}

class AudioNode {
    enum BusScope: String, CaseIterable {
        case input
        case output

        var audioUnitScope: AudioUnitScope {
            switch self {
            case .input:
                return kAudioUnitScope_Input
            case .output:
                return kAudioUnitScope_Output
            }
        }
    }

    let audioUnit: AudioUnit

    init(description: inout AudioComponentDescription) throws {
        guard let audioComponent = AudioComponentFindNext(nil, &description) else {
            throw AudioNodeError.unableToFindAudioComponent
        }
        var audioUnit: AudioUnit?
        let status = AudioComponentInstanceNew(audioComponent, &audioUnit)
        guard status == noErr, let audioUnit else {
            throw AudioNodeError.unableToCreateAudioUnit(status)
        }
        self.audioUnit = audioUnit
    }

    deinit {
        AudioOutputUnitStop(audioUnit)
        AudioUnitUninitialize(audioUnit)
        AudioComponentInstanceDispose(audioUnit)
    }

    func initializeAudioUnit() throws {
        let status = AudioUnitInitialize(audioUnit)
        guard status == noErr else {
            throw AudioNodeError.unableToInitializeAudioUnit(status)
        }
    }

    @discardableResult
    func connect(to node: AudioNode, sourceBus: Int = 0, destBus: Int = 0) throws -> AudioUnitConnection {
        var connection = AudioUnitConnection(sourceAudioUnit: audioUnit,
                                             sourceOutputNumber: 0,
                                             destInputNumber: 0)
        let status = AudioUnitSetProperty(node.audioUnit,
                                          kAudioUnitProperty_MakeConnection,
                                          kAudioUnitScope_Input,
                                          0,
                                          &connection,
                                          UInt32(MemoryLayout<AudioUnitConnection>.size))
        guard status == noErr else {
            throw AudioNodeError.unableToConnectToNode(status)
        }
        return connection
    }

    func update(format: AVAudioFormat, bus: Int, scope: BusScope) throws {
        var asbd = format.streamDescription.pointee
        let status = AudioUnitSetProperty(audioUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          scope.audioUnitScope,
                                          UInt32(bus),
                                          &asbd,
                                          UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        guard status == noErr else {
            throw AudioNodeError.unableToUpdateBus(status)
        }
    }

    func format(bus: Int, scope: BusScope) throws -> AudioStreamBasicDescription {
        var asbd = AudioStreamBasicDescription()
        var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioUnitGetProperty(audioUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          scope.audioUnitScope,
                                          UInt32(bus),
                                          &asbd,
                                          &propertySize)
        guard status == noErr else {
            throw AudioNodeError.unableToRetrieveValue(status)
        }
        return asbd
    }

    /// Apple bug: Cannot set to less than 8 buses
    func update(busCount: Int, scope: BusScope) throws {
        var busCount = UInt32(busCount)
        let status = AudioUnitSetProperty(audioUnit,
                                          kAudioUnitProperty_ElementCount,
                                          scope.audioUnitScope,
                                          0,
                                          &busCount,
                                          UInt32(MemoryLayout<UInt32>.size))
        guard status == noErr else {
            throw AudioNodeError.unableToUpdateBus(status)
        }
    }

    func busCount(scope: BusScope) throws -> Int {
        var busCount: UInt32 = 0
        var propertySize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioUnitGetProperty(audioUnit,
                                          kAudioUnitProperty_ElementCount,
                                          scope.audioUnitScope,
                                          0,
                                          &busCount,
                                          &propertySize)
        guard status == noErr else {
            throw AudioNodeError.unableToUpdateBus(status)
        }
        return Int(busCount)
    }
}

class MixerNode: AudioNode {
    private var mixerComponentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Mixer,
        componentSubType: kAudioUnitSubType_MultiChannelMixer,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0)

    init(format: AVAudioFormat) throws {
        try super.init(description: &mixerComponentDescription)
    }

    func update(inputCallback: inout AURenderCallbackStruct, bus: Int) throws {
        let status = AudioUnitSetProperty(audioUnit,
                                          kAudioUnitProperty_SetRenderCallback,
                                          kAudioUnitScope_Input,
                                          UInt32(bus),
                                          &inputCallback,
                                          UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        guard status == noErr else {
            throw AudioNodeError.unableToUpdateBus(status)
        }
    }

    func enable(bus: Int, scope: AudioNode.BusScope, isEnabled: Bool) throws {
        let value: AudioUnitParameterValue = isEnabled ? 1 : 0
        let status = AudioUnitSetParameter(audioUnit,
                                           kMultiChannelMixerParam_Enable,
                                           scope.audioUnitScope,
                                           UInt32(bus),
                                           value,
                                           0)
        guard status == noErr else {
            throw AudioNodeError.unableToUpdateBus(status)
        }
    }

    func isEnabled(bus: Int, scope: AudioNode.BusScope) throws -> Bool {
        var value: AudioUnitParameterValue = 0
        let status = AudioUnitGetParameter(audioUnit,
                                           kMultiChannelMixerParam_Enable,
                                           scope.audioUnitScope,
                                           UInt32(bus),
                                           &value)
        guard status == noErr else {
            throw AudioNodeError.unableToRetrieveValue(status)
        }
        return value != 0
    }

    func update(volume: Float, bus: Int, scope: AudioNode.BusScope) throws {
        let value: AudioUnitParameterValue = max(0, min(1, volume))
        let status = AudioUnitSetParameter(audioUnit,
                                           kMultiChannelMixerParam_Volume,
                                           scope.audioUnitScope,
                                           UInt32(bus),
                                           value,
                                           0)
        guard status == noErr else {
            throw AudioNodeError.unableToUpdateBus(status)
        }
    }

    func volume(bus: Int, of scope: AudioNode.BusScope) throws -> Float {
        var value: AudioUnitParameterValue = 0
        let status = AudioUnitGetParameter(audioUnit,
                                           kMultiChannelMixerParam_Volume,
                                           scope.audioUnitScope,
                                           UInt32(bus),
                                           &value)
        guard status == noErr else {
            throw AudioNodeError.unableToUpdateBus(status)
        }
        return value
    }
}

enum OutputNodeError: Error {
    case unableToRenderFrames
    case unableToAllocateBuffer
}

class OutputNode: AudioNode {
    private var outputComponentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Output,
        componentSubType: kAudioUnitSubType_GenericOutput,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0)

    let format: AVAudioFormat

    init(format: AVAudioFormat) throws {
        self.format = format
        try super.init(description: &outputComponentDescription)
    }

    func render(numberOfFrames: AVAudioFrameCount,
                sampleTime: AVAudioFramePosition) throws -> AVAudioPCMBuffer {
        var timeStamp = AudioTimeStamp()
        timeStamp.mFlags = .sampleTimeValid
        timeStamp.mSampleTime = Float64(sampleTime)

        let channelCount = format.channelCount
        let audioBufferList = AudioBufferList.allocate(maximumBuffers: Int(channelCount))
        defer {
            free(audioBufferList.unsafeMutablePointer)
        }
        for i in 0..<Int(channelCount) {
            audioBufferList[i] = AudioBuffer(mNumberChannels: 1,
                                             mDataByteSize: format.streamDescription.pointee.mBytesPerFrame,
                                             mData: nil)
        }

        let status = AudioUnitRender(audioUnit,
                                     nil,
                                     &timeStamp,
                                     0,
                                     numberOfFrames,
                                     audioBufferList.unsafeMutablePointer)

        guard status == noErr else {
            throw OutputNodeError.unableToRenderFrames
        }

        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: numberOfFrames) else {
            throw OutputNodeError.unableToAllocateBuffer
        }

        pcmBuffer.frameLength = numberOfFrames

        for channel in 0..<Int(channelCount) {
            let mDataByteSize = Int(audioBufferList[channel].mDataByteSize)

            switch format.commonFormat {
            case .pcmFormatInt16:
                let pcmChannelData = pcmBuffer.int16ChannelData?[channel]
                let audioBufferData = audioBufferList[channel].mData?.assumingMemoryBound(to: Int16.self)
                if let pcmChannelData, let audioBufferData {
                    memcpy(pcmChannelData, audioBufferData, mDataByteSize)
                }
            case .pcmFormatInt32:
                let pcmChannelData = pcmBuffer.int32ChannelData?[channel]
                let audioBufferData = audioBufferList[channel].mData?.assumingMemoryBound(to: Int32.self)
                if let pcmChannelData, let audioBufferData {
                    memcpy(pcmChannelData, audioBufferData, mDataByteSize)
                }
            case .pcmFormatFloat32:
                let pcmChannelData = pcmBuffer.floatChannelData?[channel]
                let audioBufferData = audioBufferList[channel].mData?.assumingMemoryBound(to: Float32.self)
                if let pcmChannelData, let audioBufferData {
                    memcpy(pcmChannelData, audioBufferData, mDataByteSize)
                }
            default:
                break
            }
        }

        return pcmBuffer
    }
}
