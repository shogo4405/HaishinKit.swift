import AppKit
import AVFoundation
import Foundation
import HaishinKit

final class PlaybackViewController: NSViewController {
    @IBOutlet private weak var lfView: MTHKView!
    private let audioEngine = AVAudioEngine()
    private let netStreamSwitcher: NetStreamSwitcher = .init()

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { @MainActor in
            await netStreamSwitcher.setPreference(Preference.default)
            await netStreamSwitcher.stream?.attachAudioEngine(audioEngine)
            await netStreamSwitcher.stream?.addObserver(lfView)
        }
    }

    @IBAction private func didTappedPlayback(_ button: NSButton) {
        Task { @MainActor in
            if button.title == "Playback" {
                button.title = "Close"
                await netStreamSwitcher.open(.playback)
            } else {
                button.title = "Playback"
                await netStreamSwitcher.close()
            }
        }
    }
}
