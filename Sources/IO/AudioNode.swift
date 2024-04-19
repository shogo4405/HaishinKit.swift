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
                                             sourceOutputNumber: UInt32(sourceBus),
                                             destInputNumber: UInt32(destBus))
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

extension AudioNode: CustomStringConvertible {
    var description: String {
        var description: [String] = []

        for scope in BusScope.allCases {
            guard let busCount = try? busCount(scope: scope) else {
                description.append("failed to get \(scope.rawValue) bus count")
                continue
            }
            guard busCount > 0 else {
                continue
            }
            var busDescription: [String] = []
            for busIndex in 0..<busCount {
                guard let asbd = try? format(bus: busIndex, scope: scope) else {
                    busDescription.append("failed to get \(scope.rawValue) bus format for bus \(busIndex)")
                    continue
                }
                if let mixerNode = self as? MixerNode, let volume = try? mixerNode.volume(bus: busIndex, of: scope) {
                    if scope != .input || scope == .input && (try? mixerNode.isEnabled(bus: UInt8(busIndex), scope: scope)) ?? false {
                        busDescription.append("bus: \(busIndex), volume: \(volume), format: \(asbd)")
                    }
                } else {
                    busDescription.append("bus: \(busIndex), format: \(asbd)")
                }
            }

            description.append("\(scope.rawValue) \(busDescription.count)/\(busCount)")
            description.append(busDescription.joined(separator: "; "))
        }

        let parametersList = (try? parameters) ?? []
        if !parametersList.isEmpty {
            description.append("parameters: ")
            for parameter in parametersList {
                description.append("\(parameter)")
            }
        }

        return "AudioNode(\(description.joined(separator: "; ")))"
    }

    private var parameters: [AudioUnitParameter] {
        get throws {
            var result = [AudioUnitParameter]()
            var status: OSStatus = noErr

            var parameterListSize: UInt32 = 0
            AudioUnitGetPropertyInfo(audioUnit,
                                     kAudioUnitProperty_ParameterList,
                                     kAudioUnitScope_Global,
                                     0,
                                     &parameterListSize,
                                     nil)

            let numberOfParameters = Int(parameterListSize) / MemoryLayout<AudioUnitParameterID>.size
            let parameterIds = UnsafeMutablePointer<AudioUnitParameterID>.allocate(capacity: numberOfParameters)
            defer { parameterIds.deallocate() }

            if numberOfParameters > 0 {
                status = AudioUnitGetProperty(audioUnit,
                                              kAudioUnitProperty_ParameterList,
                                              kAudioUnitScope_Global,
                                              0,
                                              parameterIds,
                                              &parameterListSize)
                guard status == noErr else {
                    throw AudioNodeError.unableToRetrieveValue(status)
                }
            }

            var info = AudioUnitParameterInfo()
            var infoSize = UInt32(MemoryLayout<AudioUnitParameterInfo>.size)

            for i in 0..<numberOfParameters {
                let id = parameterIds[i]
                status = AudioUnitGetProperty(audioUnit,
                                              kAudioUnitProperty_ParameterInfo,
                                              kAudioUnitScope_Global,
                                              id,
                                              &info,
                                              &infoSize)
                guard status == noErr else {
                    throw AudioNodeError.unableToRetrieveValue(status)
                }
                result.append(AudioUnitParameter(info, id: id))
            }

            return result
        }
    }
}

private struct AudioUnitParameter: CustomStringConvertible {
    var id: Int
    var name: String = ""
    var minValue: Float
    var maxValue: Float
    var defaultValue: Float
    var unit: AudioUnitParameterUnit

    init(_ info: AudioUnitParameterInfo, id: AudioUnitParameterID) {
        self.id = Int(id)
        if let cfName = info.cfNameString?.takeUnretainedValue() {
            name = String(cfName)
        }
        minValue = info.minValue
        maxValue = info.maxValue
        defaultValue = info.defaultValue
        unit = info.unit
    }

    var description: String {
        return "\(name), id: \(id), min: \(minValue), max: \(maxValue), default: \(defaultValue), unit: \(unit) \(unitName)"
    }

    var unitName: String {
        switch unit {
        case .generic:
            return "generic"
        case .indexed:
            return "indexed"
        case .boolean:
            return "boolean"
        case .percent:
            return "percent"
        case .seconds:
            return "seconds"
        case .sampleFrames:
            return "sampleFrames"
        case .phase:
            return "phase"
        case .rate:
            return "rate"
        case .hertz:
            return "hertz"
        case .cents:
            return "cents"
        case .relativeSemiTones:
            return "relativeSemiTones"
        case .midiNoteNumber:
            return "midiNoteNumber"
        case .midiController:
            return "midiController"
        case .decibels:
            return "decibels"
        case .linearGain:
            return "linearGain"
        case .degrees:
            return "degrees"
        case .equalPowerCrossfade:
            return "equalPowerCrossfade"
        case .mixerFaderCurve1:
            return "mixerFaderCurve1"
        case .pan:
            return "pan"
        case .meters:
            return "meters"
        case .absoluteCents:
            return "absoluteCents"
        case .octaves:
            return "octaves"
        case .BPM:
            return "BPM"
        case .beats:
            return "beats"
        case .milliseconds:
            return "milliseconds"
        case .ratio:
            return "ratio"
        case .customUnit:
            return "customUnit"
        case .midi2Controller:
            return "midi2Controller"
        default:
            return "unknown_\(unit)"
        }
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

    func enable(bus: UInt8, scope: AudioNode.BusScope, isEnabled: Bool) throws {
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

    func isEnabled(bus: UInt8, scope: AudioNode.BusScope) throws -> Bool {
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
