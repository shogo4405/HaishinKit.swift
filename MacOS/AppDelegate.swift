import Cocoa
import XCGLogger

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window:NSWindow!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        XCGLogger.defaultInstance().outputLogLevel = .Verbose
        XCGLogger.defaultInstance().xcodeColorsEnabled = true

        let viewController:LiveViewController = LiveViewController()
        viewController.title = "lf - lIVE fRAMEWORK"
        window = NSWindow(contentViewController: viewController)
        window.makeKeyAndOrderFront(self)
    }

    func applicationWillTerminate(aNotification: NSNotification) {
    }
}
