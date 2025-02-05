struct Preference: Sendable {
    // Temp
    static nonisolated(unsafe) var `default` = Preference()

    var uri: String? = "srt://192.168.1.6:9998"
    var streamName: String? = "live"
}
