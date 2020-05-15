import HaishinKit
import UIKit

final class ViewController: UIViewController {
    @IBOutlet private weak var lfView: GLHKView!

    var rtmpConnection = RTMPConnection()
    var rtmpStream: RTMPStream!

    override func viewDidLoad() {
        super.viewDidLoad()
        rtmpConnection.delegate = self
        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpConnection.connect(Preference.defaultInstance.uri!)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        lfView?.attachStream(rtmpStream)
    }
}


extension ViewController: RTMPConnectionDelegate {
    func connectionDidSucceed(_ connection: RTMPConnection) {
        rtmpStream!.play(Preference.defaultInstance.streamName)
    }
}
