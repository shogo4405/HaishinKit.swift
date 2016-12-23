import Cocoa
import XCGLogger
import AudioToolbox

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window:NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        XCGLogger.default.setup(
            level: .info,
            showThreadName: true,
            showLevel: true,
            showFileNames: true,
            showLineNumbers: true,
            writeToFile: nil,
            fileLevel: nil
        )

        let viewController:LiveViewController = LiveViewController()
        viewController.title = "HaishinKit"
        window = NSWindow(contentViewController: viewController)
        window.delegate = viewController
        window.makeKeyAndOrderFront(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }
}
