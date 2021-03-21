struct Preference {
    static var defaultInstance = Preference()

    var uri: String? = "rtmp://192.168.10.47:1935/live"
    var streamName: String? = "live"
}
