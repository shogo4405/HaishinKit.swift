struct Preference {
    static var defaultInstance: Preference = Preference()

    var uri: String? = "rtmp://test:test@192.168.11.15/vod"
    var streamName: String? = "sample-mono.mp4"
}
