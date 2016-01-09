import Foundation
import XCTest

final class MD5Tests: XCTestCase {
    func testCalculate() {
        XCTAssertEqual( "".md5, "d41d8cd98f00b204e9800998ecf8427e")
        XCTAssertEqual("a".md5, "0cc175b9c0f1b6a831c399e269772661")
        XCTAssertEqual("abc".md5, "900150983cd24fb0d6963f7d28e17f72")
        XCTAssertEqual("message digest".md5, "f96b697d7cb7938d525a2f31aaf161d0")
        XCTAssertEqual("abcdefghijklmnopqrstuvwxyz".md5, "c3fcd3d76192e4007dfb496cca67e13b")
        XCTAssertEqual("12345678901234567890123456789012345678901234567890123456789012345678901234567890".md5, "57edf4a22be3c955ac49da2e2107b67a")
    }
}
