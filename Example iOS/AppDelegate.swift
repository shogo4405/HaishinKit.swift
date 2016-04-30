import UIKit
import XCGLogger

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window:UIWindow?
    var rootViewController:UINavigationController = {
        let controller:UINavigationController = UINavigationController()
        controller.setViewControllers([LiveViewController()], animated: true)
        controller.navigationBar.setBackgroundImage(UIImage(), forBarMetrics: UIBarMetrics.Default)
        controller.navigationBar.translucent = true
        controller.navigationBar.titleTextAttributes = [
            NSForegroundColorAttributeName: UIColor.whiteColor()
        ]
        controller.navigationBar.tintColor = UIColor.whiteColor()
        controller.navigationBar.shadowImage = UIImage()
        return controller
    }()

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        XCGLogger.defaultInstance().outputLogLevel = .Verbose
        XCGLogger.defaultInstance().xcodeColorsEnabled = true

        window = UIWindow(frame: UIScreen.mainScreen().bounds)
        window?.backgroundColor = UIColor.whiteColor()
        window?.rootViewController = rootViewController
        window?.makeKeyAndVisible()

        return true
    }
}
