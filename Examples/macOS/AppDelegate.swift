import Cocoa
import Logboard
import HaishinKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Logboard.with(HaishinKitIdentifier).level = .trace
    }
}
