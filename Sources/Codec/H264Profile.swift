import Foundation
import VideoToolbox

/// The type of VideoCodec supports H264 profiles.
/// - Notes: For flutter plugin.
public enum H264Profile: String {
    /// Baseline Profile.
    case baseline
    /// Main Profile.
    case main
    /// High Profile.
    case high

    func CFString(_ level: H264Level) -> CFString {
        switch self {
        case .baseline:
            switch level {
            case .auto:
                return kVTProfileLevel_H264_Baseline_AutoLevel
            case .level3_0:
                return kVTProfileLevel_H264_Baseline_3_0
            case .level3_1:
                return kVTProfileLevel_H264_Baseline_3_1
            case .level3_2:
                return kVTProfileLevel_H264_Baseline_3_2
            case .level4_0:
                return kVTProfileLevel_H264_Baseline_4_0
            case .level4_1:
                return kVTProfileLevel_H264_Baseline_4_1
            case .level4_2:
                return kVTProfileLevel_H264_Baseline_4_2
            case .level5_0:
                return kVTProfileLevel_H264_Baseline_5_0
            case .level5_1:
                return kVTProfileLevel_H264_Baseline_5_1
            case .level5_2:
                return kVTProfileLevel_H264_Baseline_5_2
            }
        case .main:
            switch level {
            case .auto:
                return kVTProfileLevel_H264_Main_AutoLevel
            case .level3_0:
                return kVTProfileLevel_H264_Main_3_0
            case .level3_1:
                return kVTProfileLevel_H264_Main_3_1
            case .level3_2:
                return kVTProfileLevel_H264_Main_3_2
            case .level4_0:
                return kVTProfileLevel_H264_Main_4_0
            case .level4_1:
                return kVTProfileLevel_H264_Main_4_1
            case .level4_2:
                return kVTProfileLevel_H264_Main_4_2
            case .level5_0:
                return kVTProfileLevel_H264_Main_5_0
            case .level5_1:
                return kVTProfileLevel_H264_Main_5_1
            case .level5_2:
                return kVTProfileLevel_H264_Main_5_2
            }
        case .high:
            switch level {
            case .auto:
                return kVTProfileLevel_H264_High_AutoLevel
            case .level3_0:
                return kVTProfileLevel_H264_High_3_0
            case .level3_1:
                return kVTProfileLevel_H264_High_3_1
            case .level3_2:
                return kVTProfileLevel_H264_High_3_2
            case .level4_0:
                return kVTProfileLevel_H264_High_4_0
            case .level4_1:
                return kVTProfileLevel_H264_High_4_1
            case .level4_2:
                return kVTProfileLevel_H264_High_4_2
            case .level5_0:
                return kVTProfileLevel_H264_High_5_0
            case .level5_1:
                return kVTProfileLevel_H264_High_5_1
            case .level5_2:
                return kVTProfileLevel_H264_High_5_2
            }
        }
    }
}

/// The type of VideoCodec supports profile levels.
/// - Note: For flutter plugin.
public enum H264Level {
    case auto
    case level3_0
    case level3_1
    case level3_2
    case level4_0
    case level4_1
    case level4_2
    case level5_0
    case level5_1
    case level5_2
}
