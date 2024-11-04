import AVFoundation

class AudioNode {
    enum Error: Swift.Error {
        case unableToFindAudioComponent
        case unableToCreateAudioUnit(_ status: OSStatus)
        case unableToInitializeAudioUnit(_ status: OSStatus)
        case unableToUpdateBus(_ status: OSStatus)
        case unableToRetrieveValue(_ status: OSStatus)
        case unableToConnectToNode(_ status: OSStatus)
    }

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
            throw Error.unableToFindAudioComponent
        }
        var audioUnit: AudioUnit?
        let status = AudioComponentInstanceNew(audioComponent, &audioUnit)
        guard status == noErr, let audioUnit else {
            throw Error.unableToCreateAudioUnit(status)
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
            throw Error.unableToInitializeAudioUnit(status)
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
            throw Error.unableToConnectToNode(status)
        }
        return connection
    }

    func update(format: AVAudioFormat, bus: UInt8, scope: BusScope) throws {
        var asbd = format.streamDescription.pointee
        let status = AudioUnitSetProperty(audioUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          scope.audioUnitScope,
                                          UInt32(bus),
                                          &asbd,
                                          UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        guard status == noErr else {
            throw Error.unableToUpdateBus(status)
        }
    }

    func format(bus: UInt8, scope: BusScope) throws -> AudioStreamBasicDescription {
        var asbd = AudioStreamBasicDescription()
        var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioUnitGetProperty(audioUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          scope.audioUnitScope,
                                          UInt32(bus),
                                          &asbd,
                                          &propertySize)
        guard status == noErr else {
            throw Error.unableToRetrieveValue(status)
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
            throw Error.unableToUpdateBus(status)
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
            throw Error.unableToUpdateBus(status)
        }
        return Int(busCount)
    }
}

final class MixerNode: AudioNode {
    private var mixerComponentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Mixer,
        componentSubType: kAudioUnitSubType_MultiChannelMixer,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0)

    init(format: AVAudioFormat) throws {
        try super.init(description: &mixerComponentDescription)
    }

    func update(inputCallback: inout AURenderCallbackStruct, bus: UInt8) throws {
        let status = AudioUnitSetProperty(audioUnit,
                                          kAudioUnitProperty_SetRenderCallback,
                                          kAudioUnitScope_Input,
                                          UInt32(bus),
                                          &inputCallback,
                                          UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        guard status == noErr else {
            throw Error.unableToUpdateBus(status)
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
            throw Error.unableToUpdateBus(status)
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
            throw Error.unableToRetrieveValue(status)
        }
        return value != 0
    }

    func update(volume: Float, bus: UInt8, scope: AudioNode.BusScope) throws {
        let value: AudioUnitParameterValue = max(0, min(1, volume))
        let status = AudioUnitSetParameter(audioUnit,
                                           kMultiChannelMixerParam_Volume,
                                           scope.audioUnitScope,
                                           UInt32(bus),
                                           value,
                                           0)
        guard status == noErr else {
            throw Error.unableToUpdateBus(status)
        }
    }

    func volume(bus: UInt8, of scope: AudioNode.BusScope) throws -> Float {
        var value: AudioUnitParameterValue = 0
        let status = AudioUnitGetParameter(audioUnit,
                                           kMultiChannelMixerParam_Volume,
                                           scope.audioUnitScope,
                                           UInt32(bus),
                                           &value)
        guard status == noErr else {
            throw Error.unableToUpdateBus(status)
        }
        return value
    }
}

final class OutputNode: AudioNode {
    enum Error: Swift.Error {
        case unableToRenderFrames
        case unableToAllocateBuffer
    }

    private var outputComponentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Output,
        componentSubType: kAudioUnitSubType_GenericOutput,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0)

    var format: AVAudioFormat {
        buffer.format
    }
    private let buffer: AVAudioPCMBuffer
    private var timeStamp: AudioTimeStamp = {
        var timestamp = AudioTimeStamp()
        timestamp.mFlags = .sampleTimeValid
        return timestamp
    }()

    init(format: AVAudioFormat) throws {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
            throw Error.unableToAllocateBuffer
        }
        self.buffer = buffer
        try super.init(description: &outputComponentDescription)
    }

    func render(numberOfFrames: AVAudioFrameCount,
                sampleTime: AVAudioFramePosition) throws -> AVAudioPCMBuffer {
        timeStamp.mSampleTime = Float64(sampleTime)
        buffer.frameLength = numberOfFrames
        let status = AudioUnitRender(audioUnit,
                                     nil,
                                     &timeStamp,
                                     0,
                                     numberOfFrames,
                                     buffer.mutableAudioBufferList)
        guard status == noErr else {
            throw Error.unableToRenderFrames
        }
        return buffer
    }
}
