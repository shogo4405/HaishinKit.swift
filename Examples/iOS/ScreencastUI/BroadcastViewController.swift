import ReplayKit

final class BroadcastViewController: UIViewController {
    @IBOutlet private weak var startButton: UIButton!
    @IBOutlet private weak var var endpointURLField: UITextField!
    @IBOutlet private weak var var streamNameField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        startButton.addTarget(self, action: #selector(userDidFinishSetup), for: .touchDown)
    }

    @objc
    func userDidFinishSetup() {

        let broadcastURL = URL(string: endpointURLField.text!)!

        let streamName: String = streamNameField.text!
        let endpointURL: String = endpointURLField.text!
        let setupInfo: [String: NSCoding & NSObjectProtocol] =  [
            "endpointURL": endpointURL as NSString,
            "streamName": streamName as NSString
        ]

        let broadcastConfiguration = RPBroadcastConfiguration()
        broadcastConfiguration.clipDuration = 2
        broadcastConfiguration.videoCompressionProperties = [
            AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel as NSSecureCoding & NSObjectProtocol
        ]

        self.extensionContext?.completeRequest(
            withBroadcast: broadcastURL,
            broadcastConfiguration: broadcastConfiguration,
            setupInfo: setupInfo
        )
    }

    func userDidCancelSetup() {
        let error = NSError(domain: "com.haishinkit.HaishinKit", code: -1, userInfo: nil)
        self.extensionContext?.cancelRequest(withError: error)
    }
}
