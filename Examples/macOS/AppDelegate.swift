import Cocoa
import HaishinKit
import Logboard

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Logboard.with(HaishinKitIdentifier).level = .info
    }
}
