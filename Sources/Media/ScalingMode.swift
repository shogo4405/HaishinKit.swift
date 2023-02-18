/**
 * The scaling mode.
 * - seealso: https://developer.apple.com/documentation/videotoolbox/kvtpixeltransferpropertykey_scalingmode
 * - seealso: https://developer.apple.com/documentation/videotoolbox/vtpixeltransfersession/pixel_transfer_properties/scaling_mode_constants
 */
public enum ScalingMode: String, Codable {
    /// kVTScalingMode_Normal
    case normal = "Normal"
    /// kVTScalingMode_Letterbox:
    case letterbox = "Letterbox"
    /// kVTScalingMode_CropSourceToCleanAperture
    case cropSourceToCleanAperture = "CropSourceToCleanAperture"
    /// kVTScalingMode_Trim
    case trim = "Trim"
}
