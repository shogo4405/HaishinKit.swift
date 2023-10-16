import AVFoundation

#if DEBUG
extension AVAudioCommonFormat: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .pcmFormatFloat32:
            return "float32"
        case .pcmFormatFloat64:
            return "float64"
        case .pcmFormatInt16:
            return "int16"
        case .pcmFormatInt32:
            return "int32"
        case .otherFormat:
            return "other"
        @unknown default:
            return "unknown"
        }
    }
}

extension AudioFormatID: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case kAudioFormatAC3:
            return "kAudioFormatAC3"
        case kAudioFormatAES3:
            return "kAudioFormatAES3"
        case kAudioFormatALaw:
            return "kAudioFormatALaw"
        case kAudioFormatAMR:
            return "kAudioFormatAMR"
        case kAudioFormatAMR_WB:
            return "kAudioFormatAMR_WB"
        case kAudioFormatAppleIMA4:
            return "kAudioFormatAppleIMA4"
        case kAudioFormatAppleLossless:
            return "kAudioFormatAppleLossless"
        case kAudioFormatAudible:
            return "kAudioFormatAudible"
        case kAudioFormatDVIIntelIMA:
            return "kAudioFormatDVIIntelIMA"
        case kAudioFormatEnhancedAC3:
            return "kAudioFormatEnhancedAC3"
        case kAudioFormatFLAC:
            return "kAudioFormatFLAC"
        case kAudioFormatLinearPCM:
            return "kAudioFormatLinearPCM"
        case kAudioFormatMACE3:
            return "kAudioFormatMACE3"
        case kAudioFormatMACE6:
            return "kAudioFormatMACE6"
        case kAudioFormatMIDIStream:
            return "kAudioFormatMIDIStream"
        case kAudioFormatMPEG4AAC:
            return "kAudioFormatMPEG4AAC"
        case kAudioFormatMPEG4AAC_ELD:
            return "kAudioFormatMPEG4AAC_ELD"
        case kAudioFormatMPEG4AAC_ELD_SBR:
            return "kAudioFormatMPEG4AAC_ELD_SBR"
        case kAudioFormatMPEG4AAC_ELD_V2:
            return "kAudioFormatMPEG4AAC_ELD_V2"
        case kAudioFormatMPEG4AAC_HE:
            return "kAudioFormatMPEG4AAC_HE"
        case kAudioFormatMPEG4AAC_HE_V2:
            return "kAudioFormatMPEG4AAC_HE_V2"
        case kAudioFormatMPEG4AAC_LD:
            return "kAudioFormatMPEG4AAC_LD"
        case kAudioFormatMPEG4AAC_Spatial:
            return "kAudioFormatMPEG4AAC_Spatial"
        case kAudioFormatMPEG4CELP:
            return "kAudioFormatMPEG4CELP"
        case kAudioFormatMPEG4HVXC:
            return "kAudioFormatMPEG4HVXC"
        case kAudioFormatMPEG4TwinVQ:
            return "kAudioFormatMPEG4TwinVQ"
        case kAudioFormatMPEGD_USAC:
            return "kAudioFormatMPEGD_USAC"
        case kAudioFormatMPEGLayer1:
            return "kAudioFormatMPEGLayer1"
        case kAudioFormatMPEGLayer2:
            return "kAudioFormatMPEGLayer2"
        case kAudioFormatMPEGLayer3:
            return "kAudioFormatMPEGLayer3"
        case kAudioFormatMicrosoftGSM:
            return "kAudioFormatMicrosoftGSM"
        case kAudioFormatOpus:
            return "kAudioFormatOpus"
        case kAudioFormatParameterValueStream:
            return "kAudioFormatParameterValueStream"
        case kAudioFormatQDesign:
            return "kAudioFormatQDesign"
        case kAudioFormatQDesign2:
            return "kAudioFormatQDesign2"
        case kAudioFormatQUALCOMM:
            return "kAudioFormatQUALCOMM"
        case kAudioFormatTimeCode:
            return "kAudioFormatTimeCode"
        case kAudioFormatULaw:
            return "kAudioFormatULaw"
        case kAudioFormatiLBC:
            return "kAudioFormatiLBC"
        default:
            return "unknown"
        }
    }
}
#endif
