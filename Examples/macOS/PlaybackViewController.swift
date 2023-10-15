import AppKit
import Foundation
import HaishinKit

final class PlaybackViewController: NSViewController {
    @IBOutlet private weak var lfView: MTHKView!
    private let netStreamSwitcher: NetStreamSwitcher = .init()
    private var stream: NetStream {
        return netStreamSwitcher.stream
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        netStreamSwitcher.uri = Preference.defaultInstance.uri!
        lfView.attachStream(stream)
    }

    @IBAction private func didTappedPlayback(_ button: NSButton) {
        netStreamSwitcher.open(.playback)
    }
}
