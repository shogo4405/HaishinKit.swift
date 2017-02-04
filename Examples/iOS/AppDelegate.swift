import UIKit
import XCGLogger

let logger:XCGLogger = XCGLogger.default

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window:UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        XCGLogger.default.setup(
            level: .info,
            showLogIdentifier: true,
            showFunctionName: true,
            showThreadName: true,
            showLevel: true,
            showFileNames: false,
            showLineNumbers: true,
            showDate: true,
            writeToFile: nil,
            fileLevel: nil
        )
        return true
    }
}
