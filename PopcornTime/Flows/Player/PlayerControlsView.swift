//
//  PlayerControlsView.swift
//  PlayerControlsView
//
//  Created by Alexandru Tudose on 14.08.2021.
//  Copyright © 2021 PopcornTime. All rights reserved.
//

import SwiftUI
import PopcornKit

struct PlayerControlsView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            #if os(iOS)
            topView
                .padding([.leading, .trailing], 20)
                .padding(.top, 10)
            #endif
            Spacer()
            bottomView
                .padding([.leading, .trailing], 20)
                .padding(.bottom, 10)
        }
        .preferredColorScheme(.dark)
        .accentColor(.white)
    }
    
    @ViewBuilder
    var topView: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 0) {
                Group {
                    closeButton
                    ratioButton
                }
                .shadow(color: .gray, radius: 2, x: 0, y: 0)
            }
            
            Spacer()
            #if os(iOS)
            VolumeButtonSlider(onVolumeChange: {
                viewModel.resetIdleTimer()
            })
                .frame(width: 200)
                .padding([.leading, .trailing], 10)
            #endif
        }
        .frame(height: 46)
        .padding(.top, 1)
    }
    
    @ViewBuilder
    var bottomView: some View {
        #if os(iOS)
        let multiplier = UIDevice.current.userInterfaceIdiom == .phone ? 0.8 : 1
        Spacer()
        HStack(spacing: 60) {
            Group {
                rewindButton(width: 55 * multiplier, imageInset: 20)
                playButton(width: 90 * multiplier, imageInset: 25)
                forwardButton(width: 55 * multiplier, imageInset: 20)
            }
            .background {
                Circle()
                    .fill(Color(white: 0.2, opacity: 0.5))
            }
        }
        .buttonStyle(.plain)
        Spacer()
        bottomViewCompact
        #else
        bottomViewRegular
        #endif
    }
    
    @ViewBuilder
    var bottomViewRegular: some View {
        HStack(spacing: 10) {
            rewindButton()
            playButton()
                .padding([.leading, .trailing], 4)
            forwardButton()
            Text(viewModel.progress.isScrubbing ? viewModel.progress.scrubbingTime : viewModel.progress.elapsedTime)
                .monospacedDigit()
                .foregroundColor(.gray)
                .frame(minWidth: 40)
            progressView
            Text(viewModel.progress.remainingTime)
                .monospacedDigit()
                .foregroundColor(.gray)
                .frame(minWidth: 40)
            AirplayView()
                .frame(width: 40)
            subtitlesButton
        }
        .tint(.white)
        #if os(macOS)
        .frame(height: 35)
        #else
        .frame(height: 45)
        #endif
        .frame(maxWidth: 750)
        .padding([.leading, .trailing], 10)
        .background {
            Color.clear
                .background(.regularMaterial)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    var bottomViewCompact: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                progressView
            }
            HStack(spacing: 10) {
                Group {
                    Text(viewModel.progress.isScrubbing ? viewModel.progress.scrubbingTime : viewModel.progress.elapsedTime)
                    Spacer()
                    AirplayView()
                        .frame(width: 40)
                    subtitlesButton
                        .frame(width: 40)
                    Text(viewModel.progress.remainingTime)
                }
                .monospacedDigit()
                .foregroundColor(.white)
                .frame(height: 20)
                .frame(minWidth: 40)
                .shadow(color: .gray, radius: 2, x: 0, y: 0)
            }
        }
        .tint(.white)
        .frame(maxWidth: 1000)
        .padding([.leading, .trailing], 10)
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    var progressView: some View {
        ZStack {
            if viewModel.isLoading {
                HStack(spacing: 10) {
                    Spacer()
                    ProgressView()
                    Text("Loading...")
                    Spacer()
                }
            } else {
                ProgressView(value: viewModel.progress.bufferProgress)
                #if os(iOS)
                    .padding(.top, 1)
                    .padding([.leading, .trailing], 1)
                #endif
                    .tint(.gray)
                Slider(value: Binding(get: {
                    viewModel.progress.isScrubbing ? viewModel.progress.scrubbingProgress : viewModel.progress.progress
                }, set: { value in
                    viewModel.progress.scrubbingProgress = value
                    viewModel.positionSliderDidDrag()
                })) { started in
                    viewModel.clickGesture()
                }
                .tint(Color(white: 1, opacity: 0.9))
                .overlay(content: {
                    snapshotImage
                })
            }
        }
    }
    
    @ViewBuilder
    var snapshotImage: some View {
        if let image = viewModel.progress.screenshotImage, viewModel.progress.isScrubbing {
            GeometryReader { geometry in
                #if os(macOS)
                Image(nsImage: image)
                    .border(Color.init(white: 1.0, opacity: 0.5), width: 1)
                    .padding(.top, -image.size.height - 15)
                    .padding(.leading, CGFloat(viewModel.progress.scrubbingProgress) * geometry.size.width - 0.5 * image.size.width)
                #elseif os(iOS)
                Image(uiImage: image)
                    .border(Color.init(white: 1.0, opacity: 0.5), width: 1)
                    .padding(.top, -image.size.height - 15)
                    .padding(.leading, CGFloat(viewModel.progress.scrubbingProgress) * geometry.size.width - 0.5 * image.size.width)
                #endif
            }
        }
    }
    
    @ViewBuilder
    var closeButton: some View {
        Button {
            withAnimation {
                dismiss()
            }
        } label: {
            Color.clear
                .overlay(
                    Image("CloseiOS")
                        .renderingMode(.template)
                        .tint(.white)
                )
                
        }
        .frame(width: 46)
    }
    
    @ViewBuilder
    var ratioButton: some View {
        #if os(iOS)
        Button {
            viewModel.switchVideoDimensions()
        } label: {
            Color.clear
                .overlay{
                    Image(viewModel.videoAspectRatio == .fit ?  "Scale To Fill" : "Scale To Fit")
                        .resizable()
                        .renderingMode(.template)
                        .tint(.white)
                        .frame(width: 22, height: 22)
                }
        }
        .frame(width: 46)
        #else
        EmptyView()
        #endif
    }
    
    @ViewBuilder
    func playButton(width: CGFloat = 32, imageInset: CGFloat = 7) -> some View {
        Button {
            viewModel.playandPause()
        } label: {
            Image(viewModel.isPlaying ? "Pause" : "Play")
                .resizable()
                .frame(width: width - imageInset, height: width - imageInset)
                .frame(width: width, height: width)
                .contentShape(Rectangle())
        }
        .disabled(viewModel.isLoading)
        .frame(width: width)
    }
    
    @ViewBuilder
    func rewindButton(width: CGFloat = 32, imageInset: CGFloat = 7) -> some View {
        Button {
            viewModel.rewind()
        } label: {
            Image("SkipBack30") //"Rewind"
                .resizable()
                .frame(width: width - imageInset, height: width - imageInset)
                .frame(width: width, height: width)
                .contentShape(Rectangle())
        }
        .onLongPressGesture(perform: {}, onPressingChanged: { started in
            viewModel.rewindHeld(started)
        })
        .disabled(viewModel.isLoading || viewModel.progress.progress == 0.0)
        .frame(width: width)
    }
    
    @ViewBuilder
    func forwardButton(width: CGFloat = 32, imageInset: CGFloat = 7) -> some View {
        Button {
            viewModel.fastForward()
        } label: {
//            Image("Fast Forward")
            Image("SkipForward30")
                .resizable()
                .frame(width: width - imageInset, height: width - imageInset)
                .frame(width: width, height: width)
                .contentShape(Rectangle())
        }
        .disabled(viewModel.isLoading || viewModel.progress.progress == 1.0)
        .onLongPressGesture(perform: {}, onPressingChanged: { started in
            viewModel.fastForwardHeld(started)
        })
        .frame(width: width)
    }
    
//    @ViewBuilder
//    var airplayButton: some View {
//        Image("AirPlay")
//        #if os(iOS)
//        .tint(.gray)
//        #endif
//        .frame(width: 32)
//    }
    
    @ViewBuilder
    var subtitlesButton: some View {
        Button {
            withAnimation {
                viewModel.showInfo = true
                viewModel.showControls = false
            }
        } label: {
            Image("Subtitles")
                .renderingMode(.template)
                .foregroundColor(.gray)
                .padding(.top, 2)
                .padding(.leading, -3)
                .frame(width: 40)
        }
        .frame(width: 32)
    }
}

struct PlayerControlsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PlayerControlsView()
                .preferredColorScheme(.dark)
                .background(.white)
                .environmentObject(playingPlayerModel)
                .previewInterfaceOrientation(.landscapeLeft)
                .previewDisplayName("White background")
            PlayerControlsView()
                .preferredColorScheme(.dark)
                .background(.blue)
                .environmentObject(playingPlayerModel)
                .previewInterfaceOrientation(.landscapeLeft)
                .previewDisplayName("Black background")
        }
        
        PlayerControlsView()
            .preferredColorScheme(.dark)
            .environmentObject(loadingPlayerModel)
    }
    
    static var playingPlayerModel: PlayerViewModel {
        let url = URL(string: "https://multiplatform-f.akamaihd.net/i/multi/will/bunny/big_buck_bunny_,640x360_400,640x360_700,640x360_1000,950x540_1500,.f4v.csmil/master.m3u8")!
        
        let showControlsModel = PlayerViewModel(media: Movie.dummy(), fromUrl: url, localUrl: url, directory: url, streamer: .init())
        showControlsModel.isLoading = false
        showControlsModel.showControls = false
        showControlsModel.showInfo = false
        showControlsModel.isPlaying = true
        showControlsModel.progress = .init(progress: 0.2, isBuffering: false, bufferProgress: 0.7, isScrubbing: false, scrubbingProgress: 0, remainingTime: "-23:10", elapsedTime: "02:20", scrubbingTime: "la la", screenshot: nil, hint: .none)
        return showControlsModel
    }
    
    static var loadingPlayerModel: PlayerViewModel {
        let url = URL(string: "https://multiplatform-f.akamaihd.net/i/multi/will/bunny/big_buck_bunny_,640x360_400,640x360_700,640x360_1000,950x540_1500,.f4v.csmil/master.m3u8")!
        
        let showControlsModel = PlayerViewModel(media: Movie.dummy(), fromUrl: url, localUrl: url, directory: url, streamer: .init())
        showControlsModel.isLoading = true
        showControlsModel.progress = .init(progress: 0.1, isBuffering: true, bufferProgress: 0.7, isScrubbing: false, scrubbingProgress: 0, remainingTime: "-23:10", elapsedTime: "01:20", scrubbingTime: "03:04", screenshot: nil, hint: .none)
        return showControlsModel
    }
}
