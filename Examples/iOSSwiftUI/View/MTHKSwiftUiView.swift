import Foundation
import HaishinKit
import SwiftUI

struct MTHKSwiftUiView: UIViewRepresentable {
    var mthkView = MTHKView(frame: .zero)

    @Binding var rtmpStream: RTMPStream

    func makeUIView(context: Context) -> MTHKView {
        mthkView.videoGravity = .resizeAspectFill
        return mthkView
    }

    func updateUIView(_ uiView: MTHKView, context: Context) {
        mthkView.attachStream(rtmpStream)
    }
}
