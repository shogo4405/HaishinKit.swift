struct Preference {
    static var defaultInstance = Preference()

    var uri: String? = "rtmp://localhost/vod"
    var streamName: String? = "sample.mp4"
}
