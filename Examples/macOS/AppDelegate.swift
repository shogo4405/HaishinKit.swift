import Cocoa

class Logger {
    func verbose(_ message: CustomStringConvertible) {
        print("ok")
    }
    func debug(_ message: CustomStringConvertible) {}
    func info(_ message: CustomStringConvertible) {}
    func warning(_ message: CustomStringConvertible) {}
    func error(_ message: CustomStringConvertible) {}
    func fatal(_ message: CustomStringConvertible) {}
}

extension Logger: LFLogger {
    func severe(_ message: CustomStringConvertible) { fatal(message) }
}

let logger: Logger = Logger()

        
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window:NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        lfLogger = logger
    }
}
