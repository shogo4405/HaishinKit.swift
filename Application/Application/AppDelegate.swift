import lf
import UIKit
import XCGLogger

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window:UIWindow?
    var rootViewController:UINavigationController = {
        let controller:UINavigationController = UINavigationController()
        controller.setViewControllers([ LiveViewController()], animated: true)
        controller.navigationBar.tintColor = UIColor.whiteColor()
        controller.navigationBar.barTintColor = UIColor(
            red: 0x00 / 0xff, green: 0xa4 / 0xff, blue: 0xe4 / 0xff, alpha: 0
        )
        return controller
    }()

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        XCGLogger.defaultInstance().outputLogLevel = .Info
        XCGLogger.defaultInstance().xcodeColorsEnabled = true

        window = UIWindow(frame: UIScreen.mainScreen().bounds)
        window?.backgroundColor = UIColor.whiteColor()
        window?.rootViewController = rootViewController
        window?.makeKeyAndVisible()

        return true
    }
}
