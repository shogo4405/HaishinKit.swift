import Foundation
import SwiftUI
import HaishinKit

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
