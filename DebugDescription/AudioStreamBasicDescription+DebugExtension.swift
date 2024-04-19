import AVFoundation
import Foundation

#if DEBUG
extension AudioStreamBasicDescription {
    enum ReadableFormatFlag: String, CaseIterable, CustomStringConvertible {
        case audioFormatFlagIsFloat = "audio_IsFloat"
        case audioFormatFlagIsBigEndian = "audio_IsBigEndian"
        case audioFormatFlagIsSignedInteger = "audio_IsSignedInteger"
        case audioFormatFlagIsPacked = "audio_IsPacked"
        case audioFormatFlagIsAlignedHigh = "audio_IsAlignedHigh"
        case audioFormatFlagIsNonInterleaved = "audio_IsNonInterleaved"
        case audioFormatFlagIsNonMixable = "audio_IsNonMixable"
        case audioFormatFlagsAreAllClear = "audio_sAreAllClear"
        case linearPCMFormatFlagIsFloat = "pcm_IsFloat"
        case linearPCMFormatFlagIsBigEndian = "pcm_IsBigEndian"
        case linearPCMFormatFlagIsSignedInteger = "pcm_IsSignedInteger"
        case linearPCMFormatFlagIsPacked = "pcm_IsPacked"
        case linearPCMFormatFlagIsAlignedHigh = "pcm_IsAlignedHigh"
        case linearPCMFormatFlagIsNonInterleaved = "pcm_IsNonInterleaved"
        case linearPCMFormatFlagIsNonMixable = "pcm_IsNonMixable"
        case linearPCMFormatFlagsSampleFractionShift = "pcm_SampleFractionShift"
        case linearPCMFormatFlagsSampleFractionMask = "pcm_SampleFractionMask"
        case linearPCMFormatFlagsAreAllClear = "pcm_AreAllClear"
        case appleLosslessFormatFlag_16BitSourceData = "ll_16BitSourceData"
        case appleLosslessFormatFlag_20BitSourceData = "ll_20BitSourceData"
        case appleLosslessFormatFlag_24BitSourceData = "ll_24BitSourceData"
        case appleLosslessFormatFlag_32BitSourceData = "ll_32BitSourceData"

        var flagValue: AudioFormatFlags {
            switch self {
            // swiftlint:disable switch_case_on_newline
            case .audioFormatFlagIsFloat: return kAudioFormatFlagIsFloat
            case .audioFormatFlagIsBigEndian: return kAudioFormatFlagIsBigEndian
            case .audioFormatFlagIsSignedInteger: return kAudioFormatFlagIsSignedInteger
            case .audioFormatFlagIsPacked: return kAudioFormatFlagIsPacked
            case .audioFormatFlagIsAlignedHigh: return kAudioFormatFlagIsAlignedHigh
            case .audioFormatFlagIsNonInterleaved: return kAudioFormatFlagIsNonInterleaved
            case .audioFormatFlagIsNonMixable: return kAudioFormatFlagIsNonMixable
            case .audioFormatFlagsAreAllClear: return kAudioFormatFlagsAreAllClear
            case .linearPCMFormatFlagIsFloat: return kLinearPCMFormatFlagIsFloat
            case .linearPCMFormatFlagIsBigEndian: return kLinearPCMFormatFlagIsBigEndian
            case .linearPCMFormatFlagIsSignedInteger: return kLinearPCMFormatFlagIsSignedInteger
            case .linearPCMFormatFlagIsPacked: return kLinearPCMFormatFlagIsPacked
            case .linearPCMFormatFlagIsAlignedHigh: return kLinearPCMFormatFlagIsAlignedHigh
            case .linearPCMFormatFlagIsNonInterleaved: return kLinearPCMFormatFlagIsNonInterleaved
            case .linearPCMFormatFlagIsNonMixable: return kLinearPCMFormatFlagIsNonMixable
            case .linearPCMFormatFlagsSampleFractionShift: return kLinearPCMFormatFlagsSampleFractionShift
            case .linearPCMFormatFlagsSampleFractionMask: return kLinearPCMFormatFlagsSampleFractionMask
            case .linearPCMFormatFlagsAreAllClear: return kLinearPCMFormatFlagsAreAllClear
            case .appleLosslessFormatFlag_16BitSourceData: return kAppleLosslessFormatFlag_16BitSourceData
            case .appleLosslessFormatFlag_20BitSourceData: return kAppleLosslessFormatFlag_20BitSourceData
            case .appleLosslessFormatFlag_24BitSourceData: return kAppleLosslessFormatFlag_24BitSourceData
            case .appleLosslessFormatFlag_32BitSourceData: return kAppleLosslessFormatFlag_32BitSourceData
            // swiftlint:enable switch_case_on_newline
            }
        }

        static func flags(from flagOptionSet: AudioFormatFlags) -> Set<ReadableFormatFlag> {
            var result = Set<ReadableFormatFlag>()
            allCases.forEach { flag in
                if flag.flagValue & flagOptionSet == flag.flagValue {
                    result.insert(flag)
                }
            }
            return result
        }

        static func flagOptionSet(from flagSet: Set<ReadableFormatFlag>) -> AudioFormatFlags {
            var optionSet: AudioFormatFlags = 0
            flagSet.forEach { flag in
                optionSet |= flag.flagValue
            }
            return optionSet
        }

        public var description: String {
            rawValue
        }
    }

    struct ReadableFlagOptionSet: OptionSet, CustomStringConvertible {
        public let rawValue: AudioFormatFlags
        public let flags: Set<ReadableFormatFlag>

        public init(rawValue value: AudioFormatFlags) {
            self.rawValue = value
            flags = ReadableFormatFlag.flags(from: rawValue)
        }

        public var description: String {
            guard ReadableFormatFlag.flagOptionSet(from: flags) == rawValue else {
                return "Unable to parse AudioFormatFlags"
            }
            let result = flags.sorted(by: { $0.rawValue < $1.rawValue }).map { $0.description }.joined(separator: " | ")
            return "AudioFormatFlags(\(result))"
        }
    }

    var readableFormatID: String {
        switch mFormatID {
        // swiftlint:disable switch_case_on_newline
        case kAudioFormatLinearPCM: return "LinearPCM"
        case kAudioFormatAC3: return "AC3"
        case kAudioFormat60958AC3: return "60958AC3"
        case kAudioFormatAppleIMA4: return "AppleIMA4"
        case kAudioFormatMPEG4AAC: return "MPEG4AAC"
        case kAudioFormatMPEG4CELP: return "MPEG4CELP"
        case kAudioFormatMPEG4HVXC: return "MPEG4HVXC"
        case kAudioFormatMPEG4TwinVQ: return "MPEG4TwinVQ"
        case kAudioFormatMACE3: return "MACE3"
        case kAudioFormatMACE6: return "MACE6"
        case kAudioFormatULaw: return "ULaw"
        case kAudioFormatALaw: return "ALaw"
        case kAudioFormatQDesign: return "QDesign"
        case kAudioFormatQDesign2: return "QDesign2"
        case kAudioFormatQUALCOMM: return "QUALCOMM"
        case kAudioFormatMPEGLayer1: return "MPEGLayer1"
        case kAudioFormatMPEGLayer2: return "MPEGLayer2"
        case kAudioFormatMPEGLayer3: return "MPEGLayer3"
        case kAudioFormatTimeCode: return "TimeCode"
        case kAudioFormatMIDIStream: return "MIDIStream"
        case kAudioFormatParameterValueStream: return "ParameterValueStream"
        case kAudioFormatAppleLossless: return "AppleLossless"
        case kAudioFormatMPEG4AAC_HE: return "MPEG4AAC_HE"
        case kAudioFormatMPEG4AAC_LD: return "MPEG4AAC_LD"
        case kAudioFormatMPEG4AAC_ELD: return "MPEG4AAC_ELD"
        case kAudioFormatMPEG4AAC_ELD_SBR: return "MPEG4AAC_ELD_SBR"
        case kAudioFormatMPEG4AAC_ELD_V2: return "MPEG4AAC_ELD_V2"
        case kAudioFormatMPEG4AAC_HE_V2: return "MPEG4AAC_HE_V2"
        case kAudioFormatMPEG4AAC_Spatial: return "MPEG4AAC_Spatial"
        case kAudioFormatAMR: return "AMR"
        case kAudioFormatAMR_WB: return "AMR_WB"
        case kAudioFormatAudible: return "Audible"
        case kAudioFormatiLBC: return "iLBC"
        case kAudioFormatDVIIntelIMA: return "DVIIntelIMA"
        case kAudioFormatMicrosoftGSM: return "MicrosoftGSM"
        case kAudioFormatAES3: return "AES3"
        case kAudioFormatEnhancedAC3: return "EnhancedAC3"
        default: return "unknown_(\(Int(mFormatID)))"
        // swiftlint:enable switch_case_on_newline
        }
    }

    var readableFlags: ReadableFlagOptionSet {
        ReadableFlagOptionSet(rawValue: mFormatFlags)
    }
}

extension AudioStreamBasicDescription: CustomDebugStringConvertible {
    // MARK: CustomDebugStringConvertible
    public var debugDescription: String {
        "AudioStreamBasicDescription(mSampleRate: \(mSampleRate), mFormatID: \(mFormatID) \(readableFormatID), "
            + "mFormatFlags: \(mFormatFlags) \(readableFlags), mBytesPerPacket: \(mBytesPerPacket), "
            + "mFramesPerPacket: \(mFramesPerPacket), mBytesPerFrame: \(mBytesPerFrame), "
            + "mChannelsPerFrame: \(mChannelsPerFrame), mBitsPerChannel: \(mBitsPerChannel), mReserved: \(mReserved)"
    }
}

#endif
