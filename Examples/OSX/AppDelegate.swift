import Cocoa
import XCGLogger
import AudioToolbox

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window:NSWindow!

    func applicationDidFinishLaunching(aNotification: NSNotification) {

        XCGLogger.defaultInstance().xcodeColorsEnabled = true
        XCGLogger.defaultInstance().setup(
            .Verbose,
            showThreadName: true, showLogLevel: true, showFileNames: true, showLineNumbers: true, writeToFile: nil, fileLogLevel: nil)

        let viewController:LiveViewController = LiveViewController()
        viewController.title = "lf - lIVE fRAMEWORK"
        window = NSWindow(contentViewController: viewController)
        window.delegate = viewController
        window.makeKeyAndOrderFront(self)
    }

    func applicationWillTerminate(aNotification: NSNotification) {
    }
}
