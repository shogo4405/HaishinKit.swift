import Foundation

struct Preference {
    static var defaultInstance:Preference = Preference()
    
    var uri:String? = "rtmp://test:test@192.168.11.19/live"
    var streamName:String? = "live"
}
