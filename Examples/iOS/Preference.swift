struct Preference {
    static var defaultInstance = Preference()

    var uri: String? = "rtmp://192.168.1.3/vod"
    var streamName: String? = "sample.mp4"
}
