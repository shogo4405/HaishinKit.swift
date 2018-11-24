/**
 - seealso: https://tools.ietf.org/html/draft-pantos-http-live-streaming-19
 */
struct M3U {
    static let header: String = "#EXTM3U"
    static let defaultVersion: Int = 3

    var version: Int = M3U.defaultVersion
    var mediaList: [M3UMediaInfo] = []
    var mediaSequence: Int = 0
    var targetDuration: Double = 5
}

extension M3U: CustomStringConvertible {
    // MARK: CustomStringConvertible
    var description: String {
        var lines: [String] = [
            "#EXTM3U",
            "#EXT-X-VERSION: \(version)",
            "#EXT-X-MEDIA-SEQUENCE: \(mediaSequence)",
            "#EXT-X-TARGETDURATION: \(Int(targetDuration))"
        ]
        for info in mediaList {
            lines.append("#EXTINF: \(info.duration),")
            lines.append(info.url.pathComponents.last!)
        }
        return lines.joined(separator: "\r\n")
    }
}

// MARK: -
struct M3UMediaInfo {
    let url: URL
    let duration: Double
}
