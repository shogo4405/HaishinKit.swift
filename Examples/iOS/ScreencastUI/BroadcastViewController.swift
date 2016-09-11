import ReplayKit

class BroadcastViewController: UIViewController {
    @IBOutlet
    var startButton:UIButton!

    @IBOutlet
    var endpointURLField:UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        startButton.addTarget(self, action: #selector(BroadcastViewController.userDidFinishSetup), for: .touchDown)
    }

    func userDidFinishSetup() {

        let broadcastURL:URL = URL(string: endpointURLField.text!)!

        let endpointURL:String = endpointURLField.text!
        let setupInfo: [String: NSCoding & NSObjectProtocol] =  [
            "endpointURL" : endpointURL as NSString
        ]

        let broadcastConfiguration:RPBroadcastConfiguration = RPBroadcastConfiguration()

        self.extensionContext?.completeRequest(
            withBroadcast: broadcastURL,
            broadcastConfiguration: broadcastConfiguration,
            setupInfo: setupInfo
        )
    }

    func userDidCancelSetup() {
        let error = NSError(domain: "com.github.shogo4405.lf", code: -1, userInfo: nil)
        self.extensionContext?.cancelRequest(withError: error)
    }
}
