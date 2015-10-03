import UIKit

final class TabBarController: UITabBarController {
    var goLiveView:GoLiveViewController!
    var showLiveView:ShowLiveViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        goLiveView = GoLiveViewController()
        goLiveView.tabBarItem = UITabBarItem(tabBarSystemItem: UITabBarSystemItem.Featured, tag: 1)

        showLiveView = ShowLiveViewController()
        showLiveView.tabBarItem = UITabBarItem(tabBarSystemItem: UITabBarSystemItem.Bookmarks, tag: 2)
        
        let tabs:[UIViewController] = [goLiveView, showLiveView]
        setViewControllers(tabs, animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
