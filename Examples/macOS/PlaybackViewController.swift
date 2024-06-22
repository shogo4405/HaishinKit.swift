import AppKit
import Foundation
import HaishinKit

final class PlaybackViewController: NSViewController {
    @IBOutlet private weak var lfView: MTHKView!
    private let netStreamSwitcher: NetStreamSwitcher = .init()
    private var stream: IOStream {
        return netStreamSwitcher.stream
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        netStreamSwitcher.uri = Preference.default.uri!
        lfView.attachStream(stream)
    }

    @IBAction private func didTappedPlayback(_ button: NSButton) {
        if button.title == "Playback" {
            button.title = "Close"
            netStreamSwitcher.open(.playback)
        } else {
            button.title = "Playback"
            netStreamSwitcher.close()
        }
    }
}
