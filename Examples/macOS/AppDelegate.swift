import Cocoa
import XCGLogger

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
    }
}

