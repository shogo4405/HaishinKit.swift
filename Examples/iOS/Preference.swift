struct Preference {
    static var `default` = Preference()

    var uri: String? = "rtmp://192.168.1.6/live"
    var streamName: String? = "live"
}
