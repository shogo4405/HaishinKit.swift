import Foundation

/**
 - seealso: https://tools.ietf.org/html/draft-pantos-http-live-streaming-19
 */
struct M3U {
    static let header:String = "#EXTM3U"
    static let defaultVersion:Int = 3

    internal var version:Int = M3U.defaultVersion
    internal var mediaList:[M3UMediaInfo] = []
    internal var mediaSequence:Int = 0
    internal var targetDuration:Double = 5
}

extension M3U: CustomStringConvertible {
    // MARK: CustomStringConvertible
    internal var description:String {
        var lines:[String] = [
            "#EXTM3U",
            "#EXT-X-VERSION:\(version)",
            "#EXT-X-MEDIA-SEQUENCE:\(mediaSequence)",
            "#EXT-X-TARGETDURATION:\(Int(targetDuration))"
        ]
        for info in mediaList {
            lines.append("#EXTINF:\(info.duration),")
            lines.append(info.url.pathComponents.last!)
        }
        return lines.joined(separator: "\r\n")
    }
}

// MARK: -
struct M3UMediaInfo {
    internal var url:URL
    internal var duration:Double
}
