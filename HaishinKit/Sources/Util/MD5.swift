import Foundation

/**
 Message Digest Algorithm 5
 - seealso: https://ja.wikipedia.org/wiki/MD5
 - seealso: https://www.ietf.org/rfc/rfc1321.txt
 */
enum MD5 {
    static let a: UInt32 = 0x67452301
    static let b: UInt32 = 0xefcdab89
    static let c: UInt32 = 0x98badcfe
    static let d: UInt32 = 0x10325476

    static let S11: UInt32 = 7
    static let S12: UInt32 = 12
    static let S13: UInt32 = 17
    static let S14: UInt32 = 22
    static let S21: UInt32 = 5
    static let S22: UInt32 = 9
    static let S23: UInt32 = 14
    static let S24: UInt32 = 20
    static let S31: UInt32 = 4
    static let S32: UInt32 = 11
    static let S33: UInt32 = 16
    static let S34: UInt32 = 23
    static let S41: UInt32 = 6
    static let S42: UInt32 = 10
    static let S43: UInt32 = 15
    static let S44: UInt32 = 21

    struct Context {
        var a: UInt32 = MD5.a
        var b: UInt32 = MD5.b
        var c: UInt32 = MD5.c
        var d: UInt32 = MD5.d

        mutating func FF(_ x: UInt32, _ s: UInt32, _ k: UInt32) {
            let swap: UInt32 = d
            let F: UInt32 = (b & c) | ((~b) & d)
            d = c
            c = b
            b = b &+ rotateLeft(a &+ F &+ k &+ x, s)
            a = swap
        }

        mutating func GG(_ x: UInt32, _ s: UInt32, _ k: UInt32) {
            let swap: UInt32 = d
            let G: UInt32 = (d & b) | (c & (~d))
            d = c
            c = b
            b = b &+ rotateLeft(a &+ G &+ k &+ x, s)
            a = swap
        }

        mutating func HH(_ x: UInt32, _ s: UInt32, _ k: UInt32) {
            let swap: UInt32 = d
            let H: UInt32 = b ^ c ^ d
            d = c
            c = b
            b = b &+ rotateLeft(a &+ H &+ k &+ x, s)
            a = swap
        }

        mutating func II(_ x: UInt32, _ s: UInt32, _ k: UInt32) {
            let swap: UInt32 = d
            let I: UInt32 = c ^ (b | (~d))
            d = c
            c = b
            b = b &+ rotateLeft(a &+ I &+ k &+ x, s)
            a = swap
        }

        func rotateLeft(_ x: UInt32, _ n: UInt32) -> UInt32 {
            ((x << n) & 0xFFFFFFFF) | (x >> (32 - n))
        }

        var data: Data {
            a.data + b.data + c.data + d.data
        }
    }

    static func base64(_ message: String) -> String {
        calculate(message).base64EncodedString(options: .lineLength64Characters)
    }

    static func calculate(_ message: String) -> Data {
        calculate(ByteArray().writeUTF8Bytes(message).data)
    }

    static func calculate(_ data: Data) -> Data {
        var context = Context()

        let count: Data = UInt64(data.count * 8).bigEndian.data
        let message = ByteArray(data: data + [0x80])
        message.length += 64 - (message.length % 64)
        message[message.length - 8] = count[7]
        message[message.length - 7] = count[6]
        message[message.length - 6] = count[5]
        message[message.length - 5] = count[4]
        message[message.length - 4] = count[3]
        message[message.length - 3] = count[2]
        message[message.length - 2] = count[1]
        message[message.length - 1] = count[0]

        // swiftlint:disable:this closure_body_length
        message.sequence(64) {
            let x: [UInt32] = $0.toUInt32()

            guard x.count == 16 else {
                return
            }

            var ctx = Context()
            ctx.a = context.a
            ctx.b = context.b
            ctx.c = context.c
            ctx.d = context.d

            /* Round 1 */
            ctx.FF(x[ 0], S11, 0xd76aa478)
            ctx.FF(x[ 1], S12, 0xe8c7b756)
            ctx.FF(x[ 2], S13, 0x242070db)
            ctx.FF(x[ 3], S14, 0xc1bdceee)
            ctx.FF(x[ 4], S11, 0xf57c0faf)
            ctx.FF(x[ 5], S12, 0x4787c62a)
            ctx.FF(x[ 6], S13, 0xa8304613)
            ctx.FF(x[ 7], S14, 0xfd469501)
            ctx.FF(x[ 8], S11, 0x698098d8)
            ctx.FF(x[ 9], S12, 0x8b44f7af)
            ctx.FF(x[10], S13, 0xffff5bb1)
            ctx.FF(x[11], S14, 0x895cd7be)
            ctx.FF(x[12], S11, 0x6b901122)
            ctx.FF(x[13], S12, 0xfd987193)
            ctx.FF(x[14], S13, 0xa679438e)
            ctx.FF(x[15], S14, 0x49b40821)

            /* Round 2 */
            ctx.GG(x[ 1], S21, 0xf61e2562)
            ctx.GG(x[ 6], S22, 0xc040b340)
            ctx.GG(x[11], S23, 0x265e5a51)
            ctx.GG(x[ 0], S24, 0xe9b6c7aa)
            ctx.GG(x[ 5], S21, 0xd62f105d)
            ctx.GG(x[10], S22, 0x2441453)
            ctx.GG(x[15], S23, 0xd8a1e681)
            ctx.GG(x[ 4], S24, 0xe7d3fbc8)
            ctx.GG(x[ 9], S21, 0x21e1cde6)
            ctx.GG(x[14], S22, 0xc33707d6)
            ctx.GG(x[ 3], S23, 0xf4d50d87)
            ctx.GG(x[ 8], S24, 0x455a14ed)
            ctx.GG(x[13], S21, 0xa9e3e905)
            ctx.GG(x[ 2], S22, 0xfcefa3f8)
            ctx.GG(x[ 7], S23, 0x676f02d9)
            ctx.GG(x[12], S24, 0x8d2a4c8a)

            /* Round 3 */
            ctx.HH(x[ 5], S31, 0xfffa3942)
            ctx.HH(x[ 8], S32, 0x8771f681)
            ctx.HH(x[11], S33, 0x6d9d6122)
            ctx.HH(x[14], S34, 0xfde5380c)
            ctx.HH(x[ 1], S31, 0xa4beea44)
            ctx.HH(x[ 4], S32, 0x4bdecfa9)
            ctx.HH(x[ 7], S33, 0xf6bb4b60)
            ctx.HH(x[10], S34, 0xbebfbc70)
            ctx.HH(x[13], S31, 0x289b7ec6)
            ctx.HH(x[ 0], S32, 0xeaa127fa)
            ctx.HH(x[ 3], S33, 0xd4ef3085)
            ctx.HH(x[ 6], S34, 0x4881d05)
            ctx.HH(x[ 9], S31, 0xd9d4d039)
            ctx.HH(x[12], S32, 0xe6db99e5)
            ctx.HH(x[15], S33, 0x1fa27cf8)
            ctx.HH(x[ 2], S34, 0xc4ac5665)

            /* Round 4 */
            ctx.II(x[ 0], S41, 0xf4292244)
            ctx.II(x[ 7], S42, 0x432aff97)
            ctx.II(x[14], S43, 0xab9423a7)
            ctx.II(x[ 5], S44, 0xfc93a039)
            ctx.II(x[12], S41, 0x655b59c3)
            ctx.II(x[ 3], S42, 0x8f0ccc92)
            ctx.II(x[10], S43, 0xffeff47d)
            ctx.II(x[ 1], S44, 0x85845dd1)
            ctx.II(x[ 8], S41, 0x6fa87e4f)
            ctx.II(x[15], S42, 0xfe2ce6e0)
            ctx.II(x[ 6], S43, 0xa3014314)
            ctx.II(x[13], S44, 0x4e0811a1)
            ctx.II(x[ 4], S41, 0xf7537e82)
            ctx.II(x[11], S42, 0xbd3af235)
            ctx.II(x[ 2], S43, 0x2ad7d2bb)
            ctx.II(x[ 9], S44, 0xeb86d391)

            context.a = context.a &+ ctx.a
            context.b = context.b &+ ctx.b
            context.c = context.c &+ ctx.c
            context.d = context.d &+ ctx.d
        }

        return context.data
    }
}
