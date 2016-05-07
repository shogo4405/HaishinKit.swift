import Cocoa
import XCGLogger
import AudioToolbox

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window:NSWindow!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        XCGLogger.defaultInstance().outputLogLevel = .Info
        XCGLogger.defaultInstance().xcodeColorsEnabled = true

        let viewController:LiveViewController = LiveViewController()
        viewController.title = "lf - lIVE fRAMEWORK"
        window = NSWindow(contentViewController: viewController)
        window.makeKeyAndOrderFront(self)
    }

    func applicationWillTerminate(aNotification: NSNotification) {
    }
}
