import HaishinKit
import SwiftUI

struct PiPHKSwiftUiView: UIViewRepresentable {
    var piphkView = PiPHKView(frame: .zero)

    @Binding var rtmpStream: RTMPStream

    func makeUIView(context: Context) -> PiPHKView {
        piphkView.videoGravity = .resizeAspectFill
        return piphkView
    }

    func updateUIView(_ uiView: PiPHKView, context: Context) {
        Task { @MainActor in
            await rtmpStream.addOutput(piphkView)
        }
    }
}
