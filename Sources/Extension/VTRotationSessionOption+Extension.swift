import Foundation
import VideoToolbox

struct VTRotationSessionOptionKey {
    @available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
    static let rotation = VTRotationSessionOptionKey(CFString: kVTPixelRotationPropertyKey_Rotation)

    let CFString: CFString
}

struct VTRotationSessionOptionValue {
    @available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
    static let _90 = VTRotationSessionOptionValue(CFString: kVTRotation_CW90)
    @available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
    static let _180 = VTRotationSessionOptionValue(CFString: kVTRotation_180)
    @available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
    static let _270 = VTRotationSessionOptionValue(CFString: kVTRotation_CCW90)

    let CFString: CFString
}

struct VTRotationSessionOption {
    let key: VTRotationSessionOptionKey
    let value: VTRotationSessionOptionValue
}

@available(iOS 16.0, *)
extension VTPixelRotationSession {
    func setOption(_ option: VTRotationSessionOption) -> OSStatus { 
        VTSessionSetProperty(self, key: option.key.CFString, value: option.value.CFString)
    }
}
