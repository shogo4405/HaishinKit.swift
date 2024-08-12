import AVFoundation
import Foundation

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
                guard let asbd = try? format(bus: UInt8(busIndex), scope: scope) else {
                    busDescription.append("failed to get \(scope.rawValue) bus format for bus \(busIndex)")
                    continue
                }
                if let mixerNode = self as? MixerNode, let volume = try? mixerNode.volume(bus: UInt8(busIndex), of: scope) {
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
                    throw Error.unableToRetrieveValue(status)
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
                    throw Error.unableToRetrieveValue(status)
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
