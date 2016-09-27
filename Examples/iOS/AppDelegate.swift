import UIKit
import XCGLogger

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window:UIWindow?
    var rootViewController:UINavigationController = {
        let controller:UINavigationController = UINavigationController()
        controller.setViewControllers([LiveViewController()], animated: true)
        controller.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        controller.navigationBar.isTranslucent = true
        controller.navigationBar.titleTextAttributes = [
            NSForegroundColorAttributeName: UIColor.white
        ]
        controller.navigationBar.tintColor = UIColor.white
        controller.navigationBar.shadowImage = UIImage()
        return controller
    }()

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
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = UIColor.white
        window?.rootViewController = rootViewController
        window?.makeKeyAndVisible()

        return true
    }
}
