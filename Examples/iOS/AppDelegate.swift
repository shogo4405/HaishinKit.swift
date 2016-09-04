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

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: Any]?) -> Bool {

        XCGLogger.defaultInstance().outputLogLevel = .info
        XCGLogger.defaultInstance().xcodeColorsEnabled = true

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = UIColor.white
        window?.rootViewController = rootViewController
        window?.makeKeyAndVisible()

        return true
    }
}
