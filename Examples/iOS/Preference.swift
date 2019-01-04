struct Preference {
    static var defaultInstance = Preference()

    var uri: String? = "rtmp://test:test@192.168.11.15/live"
    var streamName: String? = "live"
}
