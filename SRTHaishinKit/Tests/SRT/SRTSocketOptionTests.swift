import Foundation
import Testing

import libsrt
@testable import SRTHaishinKit

@Suite struct SRTSocketOptionsTests {
    @Test func parseUri() async {
        let url = URL(string: "srt://localhost:9000?passphrase=1234&streamid=5678&latency=1935&sndsyn=1&transtype=file")
        let options = SRTSocketOption.from(uri: url)
        #expect(options[.passphrase] as! String == "1234")
        #expect(options[.streamid] as! String == "5678")
        #expect(options[.latency] as! Int32 == 1935)
        #expect(options[.sndsyn] as! Bool == true)
        #expect(options[.transtype] as! SRT_TRANSTYPE == SRTT_FILE)
    }

    @Test func string() throws {
        let socket = srt_create_socket()
        let string = "hello"
        try SRTSocketOption.streamid.setOption(socket, value: string)
        #expect(try SRTSocketOption.streamid.getOption(socket) == string.data(using: .ascii))
        srt_close(socket)
    }

    @Test func int32() throws {
        let socket = srt_create_socket()
        var int32: Int32 = 100
        try SRTSocketOption.latency.setOption(socket, value: int32)
        #expect(try SRTSocketOption.latency.getOption(socket) == Data(bytes: &int32, count: MemoryLayout<Int32>.size))
        srt_close(socket)
    }

    @Test func int64() throws {
        let socket = srt_create_socket()
        var int64: Int64 = 1000
        try SRTSocketOption.inputbw.setOption(socket, value: int64)
        #expect(try SRTSocketOption.inputbw.getOption(socket) == Data(bytes: &int64, count: MemoryLayout<Int64>.size))
        srt_close(socket)
    }

    @Test func bool() throws {
        let socket = srt_create_socket()
        var bool = true
        try SRTSocketOption.tlpktdrop.setOption(socket, value: bool)
        #expect(try SRTSocketOption.tlpktdrop.getOption(socket) == Data(bytes: &bool, count: MemoryLayout<Bool>.size))
        srt_close(socket)
    }

    @Test func transtype() throws {
        let socket = srt_create_socket()
        var bool = true
        // The default is true for Live mode, and false for File mode.
        // It does not support transtype.getOption, so I will test it by observing changes in the surrounding properties.
        #expect(try SRTSocketOption.nakreport.getOption(socket) == Data(bytes: &bool, count: MemoryLayout<Bool>.size))
        try SRTSocketOption.transtype.setOption(socket, value: SRTT_FILE)
        bool = false
        #expect(try SRTSocketOption.nakreport.getOption(socket) == Data(bytes: &bool, count: MemoryLayout<Bool>.size))
        srt_close(socket)
    }

    @Test func mode() throws {
        #expect(SRTSocketOption.getMode(uri: URL(string: "srt://192.168.1.1:9000?mode=caller")) == SRTMode.caller)
        #expect(SRTSocketOption.getMode(uri: URL(string: "srt://192.168.1.1:9000?mode=client")) == SRTMode.caller)
        #expect(SRTSocketOption.getMode(uri: URL(string: "srt://192.168.1.1:9000?mode=listener")) == SRTMode.listener)
        #expect(SRTSocketOption.getMode(uri: URL(string: "srt://192.168.1.1:9000?mode=server")) == SRTMode.listener)
        #expect(SRTSocketOption.getMode(uri: URL(string: "srt://192.168.1.1:9000")) == SRTMode.caller)
        #expect(SRTSocketOption.getMode(uri: URL(string: "srt://:9000")) == SRTMode.listener)
    }
}
