import AppKit
import AVFoundation
import Foundation
import HaishinKit

final class PlaybackViewController: NSViewController {
    @IBOutlet private weak var lfView: MTHKView!
    private let netStreamSwitcher: HKStreamSwitcher = .init()
    private let audioPlayer = AudioPlayer(audioEngine: AVAudioEngine())

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { @MainActor in
            await netStreamSwitcher.setPreference(Preference.default)
            await netStreamSwitcher.stream?.attachAudioPlayer(audioPlayer)
            await netStreamSwitcher.stream?.addOutput(lfView)
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
