import Foundation
import XCTest

@testable import HaishinKit

final class SessionDescriptionTests: XCTestCase {
    static let contents:String =
    "v=0\n" +
    "o=- 486606654 486606654 IN IP4 127.0.0.1\n" +
    "s=sample.mp4\n" +
    "c=IN IP4 0.0.0.0\n" +
    "t=0 0\n" +
    "a=sdplang:en\n" +
    "a=range:npt=0- 634.633\n" +
    "a=control:*\n" +
    "m=audio 0 RTP/AVP 96\n" +
    "a=rtpmap:96 mpeg4-generic/48000/2\n" +
    "a=fmtp:96 profile-level-id=1;mode=AAC-hbr;sizelength=13;indexlength=3;indexdeltalength=3;config=119056e500\n" +
    "a=control:trackID=1\n" +
    "m=video 0 RTP/AVP 97\n" +
    "a=rtpmap:97 H264/90000\n" +
    "a=fmtp:97 packetization-mode=1;profile-level-id=42C015;sprop-parameter-sets=Z0LAFdoCAJbARAAAAwAEAAADAPA8WLqA,aM4yyA==\n" +
    "a=cliprect:0,0,288,512\n" +
    "a=framesize:97 512-288\n" +
    "a=framerate:30.0\n" +
    "a=control:trackID=2"

    func testString() {
        var session:SessionDescription = SessionDescription()
        session.description = SessionDescriptionTests.contents
    }
}
