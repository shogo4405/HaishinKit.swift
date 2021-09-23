import Cocoa
import HaishinKit
import Logboard

let logger = Logboard.with("com.haishinkit.Exsample.macOS")

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Logboard.with(HaishinKitIdentifier).level = .info
    }
}
