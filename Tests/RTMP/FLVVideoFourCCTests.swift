import Foundation
import XCTest
import AVFoundation

@testable import HaishinKit

final class FLVVideoFourCCTests: XCTestCase {
    func testMain() {
        XCTAssertEqual("av01", str4(n: Int(FLVVideoFourCC.av1.rawValue)))
        XCTAssertEqual("hvc1", str4(n: Int(FLVVideoFourCC.hevc.rawValue)))
        XCTAssertEqual("vp09", str4(n: Int(FLVVideoFourCC.vp9.rawValue)))
    }

    func str4(n: Int) -> String {
        var result = String(UnicodeScalar((n >> 24) & 255)?.description ?? "")
        result.append(UnicodeScalar((n >> 16) & 255)?.description ?? "")
        result.append(UnicodeScalar((n >> 8) & 255)?.description ?? "")
        result.append(UnicodeScalar(n & 255)?.description ?? "")
        return result
    }
}

