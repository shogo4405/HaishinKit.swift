import AVFAudio
import Foundation

class IOUnit<C: IOCaptureUnit> {
    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.IOUnit.lock")
    weak var mixer: IOMixer?

    #if os(tvOS)
    private var _captures: [UInt8: Any] = [:]
    @available(tvOS 17.0, *)
    var captures: [UInt8: C] {
        return _captures as! [UInt8: C]
    }
    #elseif os(iOS) || os(macOS) || os(visionOS)
    var captures: [UInt8: C] = [:]
    #endif

    @available(tvOS 17.0, *)
    func capture(for track: UInt8) -> C? {
        #if os(tvOS)
        if _captures[track] == nil {
            _captures[track] = .init(track)
        }
        return _captures[track] as? C
        #else
        if captures[track] == nil {
            captures[track] = .init(track)
        }
        return captures[track]
        #endif
    }
}
