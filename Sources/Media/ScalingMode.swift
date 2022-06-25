/**
 * The scaling mode.
 * - seealso: https://developer.apple.com/documentation/videotoolbox/kvtpixeltransferpropertykey_scalingmode
 */
public enum ScalingMode: String {
    case normal = "Normal"
    case letterbox = "Letterbox"
    case cropSourceToCleanAperture = "CropSourceToCleanAperture"
    case trim = "Trim"
}
