struct Preference: Sendable {
    // Temp
    static nonisolated(unsafe) var `default` = Preference()

    var uri: String? = "rtmp://192.168.1.4/live"
    var streamName: String? = "live"
}
