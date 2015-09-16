import UIKit

final class TabBarController: UITabBarController {
    var goLiveView:GoLiveViewController!
    var settingView:SettingViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        goLiveView = GoLiveViewController()
        goLiveView.tabBarItem = UITabBarItem(tabBarSystemItem: UITabBarSystemItem.Featured, tag: 1)
        
        settingView = SettingViewController()
        settingView.tabBarItem = UITabBarItem(tabBarSystemItem: UITabBarSystemItem.Bookmarks, tag: 2)
        
        let tabs:[UIViewController] = [goLiveView, settingView]
        setViewControllers(tabs, animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
