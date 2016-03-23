import lf
import UIKit
import Foundation
import AVFoundation

final class PreferenceController: UIViewController {

    let closeButton:UIButton = {
        let button:UIButton = UIButton()
        button.layer.cornerRadius = 22
        button.setTitle("X", forState: .Normal)
        button.backgroundColor = UIColor.grayColor()
        return button
    }()

    let scrollView:UIScrollView = UIScrollView()

    override func viewDidLoad() {
        super.viewDidLoad()
        closeButton.addTarget(self, action: #selector(PreferenceController.closePreference), forControlEvents: .TouchDown)
        view.addSubview(closeButton)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        closeButton.frame = CGRect(x: view.frame.width - 44 - 20 , y: 20, width: 44, height: 44)
    }

    func closePreference() {
        dismissViewControllerAnimated(true, completion: nil)
    }
}
