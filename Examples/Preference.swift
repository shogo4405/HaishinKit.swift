struct Preference: Sendable {
    // Temp
    static nonisolated(unsafe) var `default` = Preference()

    var uri: String? = "srt://live-push-15.talk-fun.com:9000?streamid=#!::h=live-push-15.talk-fun.com,r=live/11306_IyIhLCEnSCshLisuLS9AEA,txSecret=6c5e2071219af14dc4f87f01b70d6eab,txTime=674E68BC"
    var streamName: String? = "live"
}
