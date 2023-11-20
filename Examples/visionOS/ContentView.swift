import RealityKit
import RealityKitContent
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = ViewModel()

    private var lfView: PiPHKSwiftUiView!

    init() {
        viewModel.config()
        lfView = PiPHKSwiftUiView(rtmpStream: $viewModel.rtmpStream)
    }

    var body: some View {
        VStack {
            lfView
                .ignoresSafeArea()
                .onTapGesture { _ in
                    self.viewModel.startPlaying()
                }
            Text("Hello, world!")
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
