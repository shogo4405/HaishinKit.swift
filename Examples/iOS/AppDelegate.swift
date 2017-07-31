import UIKit
import AVFoundation
import HaishinKit

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


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window:UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        lfLogger = logger
        do {
            try AVAudioSession.sharedInstance().setPreferredSampleRate(44_100)
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
            try AVAudioSession.sharedInstance().setMode(AVAudioSessionModeDefault)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
        }

        return true
    }
}
