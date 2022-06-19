//
//  Views.swift
//  iOSSwiftUI
//
//  Created by Inpyo Hong on 2022/01/07.
//  Copyright © 2022 Shogo Endo. All rights reserved.
//

import Combine
import Foundation
import SwiftUI

struct TopMenuView: View {
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        VStack {
            HStack {
                Text(viewModel.fps)
                    .foregroundColor(Color.white)

                Spacer()

                Button(action: {
                    self.viewModel.rotateCamera()
                }, label: {
                    Text("Camera")
                })

                Button(action: {
                    self.viewModel.toggleTorch()
                }, label: {
                    Text("Torch")
                })
            }

            HStack {
                Spacer()

                Picker("Select Video Effect", selection: $viewModel.videoEffect) {
                    ForEach(viewModel.videoEffectData, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            HStack {
                Spacer()

                Picker("Select Frame Rate", selection: $viewModel.frameRate) {
                    ForEach(viewModel.frameRateData, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
    }
}

struct BottomMenuView: View {
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        VStack {
            HStack(spacing: 40) {
                VStack(spacing: -6) {
                    HStack {
                        Slider(
                            value: $viewModel.zoomLevel,
                            in: 1...5,
                            step: 1,
                            onEditingChanged: { value in
                                print("zoom level", value)
                                viewModel.changeZoomLevel(level: viewModel.zoomLevel)
                            }
                        )

                        Spacer()
                            .frame(width: 100)
                    }

                    VStack(spacing: -12) {
                        HStack {
                            Spacer()
                            Text("video \(Int(viewModel.videoRate))/kbps")
                                .foregroundColor(Color.white)
                                .font(.title3)
                        }

                        Slider(
                            value: $viewModel.videoRate,
                            in: 32...1024,
                            step: 1,
                            onEditingChanged: { _ in
                                print("videoRate", viewModel.videoRate, "kbps")
                                viewModel.changeVideoRate(level: viewModel.videoRate)
                            }
                        )
                    }

                    VStack(spacing: -12) {
                        HStack {
                            Spacer()
                            Text("audio \(Int(viewModel.audioRate))/kbps")
                                .foregroundColor(Color.white)
                                .font(.title3)
                        }

                        Slider(
                            value: $viewModel.audioRate,
                            in: 15...120,
                            step: 1,
                            onEditingChanged: { _ in
                                print("audioRate", viewModel.audioRate, "kbps")
                                viewModel.changeAudioRate(level: viewModel.audioRate)
                            }
                        )
                    }
                }

                VStack(alignment: .center) {
                    Button(action: {
                        self.viewModel.published.toggle()

                        if self.viewModel.published {
                            self.viewModel.startPublish()
                        } else {
                            self.viewModel.stopPublish()
                        }
                    }, label: {
                        let state = self.viewModel.published ? "■" : "●"
                        Text(state)
                            .foregroundColor(Color.red)
                            .font(.title)
                    })

                    Button(action: {
                        self.viewModel.pausePublish()
                    }, label: {
                        Text("P")
                            .foregroundColor(Color.white)
                            .padding(2)
                            .background(
                                Rectangle()
                                    .cornerRadius(4)
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(Color.blue)
                            )
                    })
                }
            }
        }
    }
}

struct MenuView: View {
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        VStack {
            TopMenuView(viewModel: viewModel)

            Spacer()

            BottomMenuView(viewModel: viewModel)
        }
        .padding()
    }
}
