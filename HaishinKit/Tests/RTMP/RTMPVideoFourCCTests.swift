import AVFoundation
import Foundation
import Testing

@testable import HaishinKit

@Suite struct RTMPVideoFourCCTests {
    @Test func main() {
        #expect("av01" == str4(n: Int(RTMPVideoFourCC.av1.rawValue)))
        #expect("hvc1" == str4(n: Int(RTMPVideoFourCC.hevc.rawValue)))
        #expect("vp09" == str4(n: Int(RTMPVideoFourCC.vp9.rawValue)))
    }

    func str4(n: Int) -> String {
        var result = String(UnicodeScalar((n >> 24) & 255)?.description ?? "")
        result.append(UnicodeScalar((n >> 16) & 255)?.description ?? "")
        result.append(UnicodeScalar((n >> 8) & 255)?.description ?? "")
        result.append(UnicodeScalar(n & 255)?.description ?? "")
        return result
    }
}
