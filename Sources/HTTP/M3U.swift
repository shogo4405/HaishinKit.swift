import Foundation

/**
 - seealso: https://tools.ietf.org/html/draft-pantos-http-live-streaming-19
 */
struct M3U {
    static let header:String = "#EXTM3U"
    static let defaultVersion:Int = 3

    var version:Int = M3U.defaultVersion
    var mediaList:[M3UMediaInfo] = []
    var mediaSequence:Int = 0
    var targetDuration:Double = 5
}

// MARK: CustomStringConvertible
extension M3U: CustomStringConvertible {
    var description:String {
        var lines:[String] = [
            "#EXTM3U",
            "#EXT-X-VERSION:\(version)",
            "#EXT-X-MEDIA-SEQUENCE:\(mediaSequence)",
            "#EXT-X-TARGETDURATION:\(Int(targetDuration))"
        ]
        for info in mediaList {
            guard let pathComponents:[String] = info.url.pathComponents else {
                continue
            }
            lines.append("#EXTINF:\(info.duration),")
            lines.append(pathComponents.last!)
        }
        return lines.joinWithSeparator("\r\n")
    }
}

// MARK: -
struct M3UMediaInfo {
    var url:NSURL
    var duration:Double
}
