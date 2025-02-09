import Foundation
import Testing

import libsrt
@testable import SRTHaishinKit

@Suite struct SRTSocketOptionsTests {
    @Test func parseUri() async {
        let url = URL(string: "srt://localhost:9000?passphrase=1234&streamid=5678&latency=1935&sndsyn=1")
        let options = SRTSocketOption.from(uri: url)
        #expect(options[.passphrase] as! String == "1234")
        #expect(options[.streamid] as! String == "5678")
        #expect(options[.latency] as! Int32 == 1935)
        #expect(options[.sndsyn] as! Bool == true)
    }

    @Test func string() throws {
        let socket = srt_create_socket()
        let string = "hello"
        try SRTSocketOption.streamid.setOption(socket, value: string)
        #expect(try SRTSocketOption.streamid.getOption(socket) == string.data(using: .ascii))
    }

    @Test func int32() throws {
        let socket = srt_create_socket()
        var int32: Int32 = 100
        try SRTSocketOption.latency.setOption(socket, value: int32)
        #expect(try SRTSocketOption.latency.getOption(socket) == Data(bytes: &int32, count: MemoryLayout<Int32>.size))
    }

    @Test func int64() throws {
        let socket = srt_create_socket()
        var int64: Int64 = 1000
        try SRTSocketOption.inputbw.setOption(socket, value: int64)
        #expect(try SRTSocketOption.inputbw.getOption(socket) == Data(bytes: &int64, count: MemoryLayout<Int64>.size))
    }

    @Test func bool() throws {
        let socket = srt_create_socket()
        var bool = true
        try SRTSocketOption.tlpktdrop.setOption(socket, value: bool)
        #expect(try SRTSocketOption.tlpktdrop.getOption(socket) == Data(bytes: &bool, count: MemoryLayout<Bool>.size))
    }

    @Test func transtype() throws {
        /*
        // ToDo
        let socket = srt_create_socket()
        let transtype = "live"
        var result = SRTT_FILE.rawValue
        try SRTSocketOption.transtype.setOption(socket, value: transtype)
        print(try SRTSocketOption.transtype.getOption(socket).bytes)
        #expect(try SRTSocketOption.transtype.getOption(socket) == Data(bytes: &result, count: MemoryLayout<Int32>.size))
        */
    }
}
