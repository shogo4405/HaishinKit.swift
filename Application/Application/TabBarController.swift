import UIKit

final class TabBarController: UITabBarController {
    var goLive:GoLiveViewController!
    var showLive:ShowLiveViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        goLive = GoLiveViewController()
        goLive.tabBarItem = UITabBarItem(tabBarSystemItem: .Featured, tag: 1)

        showLive = ShowLiveViewController()
        showLive.tabBarItem = UITabBarItem(tabBarSystemItem: .Bookmarks, tag: 2)

        setViewControllers([goLive, showLive], animated: true)
    }
}
