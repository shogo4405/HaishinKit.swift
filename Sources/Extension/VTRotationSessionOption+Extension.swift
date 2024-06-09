import Foundation
import VideoToolbox

@available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
struct VTRotationSessionOptionKey: RawRepresentable {
    typealias RawValue = String

    static let rotation = VTRotationSessionOptionKey(rawValue: kVTPixelRotationPropertyKey_Rotation as String)

    let rawValue: String
    var CFString: CFString {
        return rawValue as CFString
    }

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

@available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
struct VTRotationSessionOptionValue: RawRepresentable {
    typealias RawValue = String

    static let _90 = VTRotationSessionOptionValue(rawValue: kVTRotation_CW90 as String)
    static let _180 = VTRotationSessionOptionValue(rawValue: kVTRotation_180 as String)
    static let _270 = VTRotationSessionOptionValue(rawValue: kVTRotation_CCW90 as String)

    let rawValue: String
    var CFString: CFString {
        return rawValue as CFString
    }

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

@available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
struct VTRotationSessionOption {
    let key: VTRotationSessionOptionKey
    let value: VTRotationSessionOptionValue
}

@available(iOS 16.0, tvOS 16.0, macOS 13.0, *)
extension VTPixelRotationSession {
    func setOption(_ option: VTRotationSessionOption) -> OSStatus {
        VTSessionSetProperty(self, key: option.key.CFString, value: option.value.CFString)
    }
}
