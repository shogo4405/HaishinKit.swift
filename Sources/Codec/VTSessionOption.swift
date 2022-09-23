import Foundation

public struct VTSessionOption: Hashable {
    public static func == (lhs: VTSessionOption, rhs: VTSessionOption) -> Bool {
        return lhs.key.CFString == rhs.key.CFString
    }

    let key: VTSessionOptionKey
    let value: AnyObject

    public func hash(into hasher: inout Hasher) {
        return hasher.combine(key.CFString)
    }
}
