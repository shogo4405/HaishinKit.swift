import Logboard

public struct HaishinKit {
    public static var identifier:String = "com.haishinkit.HaishinKit"
}

let logger:Logboard = Logboard.with(HaishinKit.identifier)

public enum CMSampleBufferType: String {
    case video = "video"
    case audio = "audio"
}
