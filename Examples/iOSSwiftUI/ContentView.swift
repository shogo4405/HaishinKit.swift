import AVFoundation
import HaishinKit
import SwiftUI
import VideoToolbox

struct ContentView: View {
    @ObservedObject var viewModel = ViewModel()

    private var lfView: MTHKSwiftUiView!
    private var menuView: MenuView!

    init() {
        viewModel.config()
        lfView = MTHKSwiftUiView(rtmpStream: $viewModel.rtmpStream)
        menuView = MenuView(viewModel: viewModel)
    }

    var body: some View {
        ZStack {
            lfView
                .ignoresSafeArea()
                .onTapGesture { location in
                    self.viewModel.tapScreen(touchPoint: location)
                }

            menuView
        }
        .onAppear {
            self.viewModel.registerForPublishEvent()
        }
        .onDisappear {
            self.viewModel.unregisterForPublishEvent()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
