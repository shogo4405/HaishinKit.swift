import Foundation
import Testing

import libsrt
@testable import SRTHaishinKit

@Suite struct SRTConnectionTests {
    @Test func streamid_success() async throws {
        let listener = SRTConnection()
        try await listener.connect(URL(string: "srt://:10000?streamid=test"))
        let connection = SRTConnection()
        try await connection.connect(URL(string: "srt://127.0.0.1:10000?streamid=test"))
        await connection.close()
        await listener.close()
    }

    // Flaky Test.
    func streamid_failed_success() async throws {
        let listener = SRTConnection()
        try await listener.connect(URL(string: "srt://:10001?streamid=test&passphrase=a546994dbf25a0823f0cbadff9cc5088k9e7c2027e8e40933a04ef574bc61cd4a"))
        let connection1 = SRTConnection()
        await #expect(throws: SRTError.self) {
                try await connection1.connect(URL(string: "srt://127.0.0.1:10001?streamid=test2&passphrase=a546994dbf25a0823f0cbadff9cc5088k9e7c2027e8e40933a04ef574bc61cd4"))
        }
        let connection2 = SRTConnection()
        try await connection2.connect(URL(string: "srt://127.0.0.1:10001?streamid=test&passphrase=a546994dbf25a0823f0cbadff9cc5088k9e7c2027e8e40933a04ef574bc61cd4a"))
        await #expect(connection2.connected == true)
        await connection1.close()
        await connection2.close()
        await listener.close()
    }
}
