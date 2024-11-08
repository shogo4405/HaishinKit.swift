import Foundation
import Testing

@testable import HaishinKit

@Suite struct MD5Tests {
    func hex(_ data: Data) -> String {
        var hash = ""
        for i in 0..<data.count {
            hash += String(format: "%02x", data[i])
        }
        return hash
    }

    @Test func calculate() {
        #expect(hex(MD5.calculate("")) == "d41d8cd98f00b204e9800998ecf8427e")
        #expect(hex(MD5.calculate("a")) == "0cc175b9c0f1b6a831c399e269772661")
        #expect(hex(MD5.calculate("abc")) == "900150983cd24fb0d6963f7d28e17f72")
        #expect(hex(MD5.calculate("message digest")) == "f96b697d7cb7938d525a2f31aaf161d0")
        #expect(hex(MD5.calculate("abcdefghijklmnopqrstuvwxyz")) == "c3fcd3d76192e4007dfb496cca67e13b")
        #expect(hex(MD5.calculate("12345678901234567890123456789012345678901234567890123456789012345678901234567890")) == "57edf4a22be3c955ac49da2e2107b67a")
    }
}
