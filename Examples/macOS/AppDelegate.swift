import Cocoa
import XCGLogger
import AudioToolbox

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window:NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        XCGLogger.defaultInstance().xcodeColorsEnabled = true
        XCGLogger.defaultInstance().setup(
            .verbose,
            showThreadName: true, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: nil, fileLogLevel: nil)

        let viewController:LiveViewController = LiveViewController()
        viewController.title = "lf - lIVE fRAMEWORK"
        window = NSWindow(contentViewController: viewController)
        window.delegate = viewController
        window.makeKeyAndOrderFront(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
}
