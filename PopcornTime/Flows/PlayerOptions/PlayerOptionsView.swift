//
//  PlayerOptionsView.swift
//  PopcornTimetvOS SwiftUI
//
//  Created by Alexandru Tudose on 25.06.2021.
//  Copyright © 2021 PopcornTime. All rights reserved.
//

import SwiftUI
import PopcornKit
#if os(tvOS)
import TVVLCKit
#elseif os(iOS)
import MobileVLCKit
#elseif os(macOS)
import VLCKit
#endif

struct PlayerOptionsView: View {
    let theme = Theme()
    var media: Media?
    @State var selectedTab = Selection.subtitles
    @Binding var audioDelay: Int
    @Binding var audioProfile: EqualizerProfiles
    @Binding var subtitleDelay: Int
    @Binding var subtitleEncoding: String
    @Binding var subtitle: Subtitle?
    @Binding var audioTrackIndex: Int
    var audioTracks: [String]
    
    enum Selection: Int {
        case info = 0, subtitles, audio
    }
    
    #if os(tvOS)
    var body: some View {
        TabView(selection: $selectedTab) {
            InfoView(media: media)
                .tabItem {
                    Text("Info")
                }
                .tag(Selection.info)
            SubtitlesView(currentDelay: $subtitleDelay,
                          currentEncoding: $subtitleEncoding,
                          currentSubtitle: $subtitle,
                          viewModel: SubtitlesViewModel(subtitles: media?.subtitles ?? [:])
                )
                .tabItem {
                    Text("Subtitles")
                }
                .tag(Selection.subtitles)
            AudioView(
                currentDelay: $audioDelay,
                currentSound: $audioProfile,
                audioTrackIndex: $audioTrackIndex,
                audioTracks: audioTracks)
                .tabItem {
                    Text("Audio")
                }
                .tag(Selection.audio)
        }
        .ignoresSafeArea(.all)
        .frame(maxHeight: theme.maxHeight)
        .padding([.bottom], 30)
        .background(VisualEffectBlur().cornerRadius(60).padding(.top, 100))
        .padding([.leading, .trailing], 120)
        .padding([.top], 30)
    }
    
    #else
    var body: some View {
        VStack {
            Picker("", selection: $selectedTab) {
                Text("Info").tag(Selection.info)
                Text("Subtitles").tag(Selection.subtitles)
                Text("Audio").tag(Selection.audio)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.bottom, 10)

            switch(selectedTab) {
            case .info:
                InfoView(media: media)
            case .subtitles:
                SubtitlesView(currentDelay: $subtitleDelay,
                              currentEncoding: $subtitleEncoding,
                              currentSubtitle: $subtitle,
                              viewModel: SubtitlesViewModel(subtitles: media?.subtitles ?? [:]))
            case .audio:
                AudioView(currentDelay: $audioDelay,
                          currentSound: $audioProfile,
                          audioTrackIndex: $audioTrackIndex,
                          audioTracks: audioTracks)
            }
        }
        .frame(maxWidth: 1024, maxHeight: theme.maxHeight)
        .padding(.bottom, 20)
        .background(.regularMaterial).cornerRadius(10)
        .padding(.horizontal, theme.horizontalSpacing)
        .padding(.top, 40)
    }
    #endif
}

extension PlayerOptionsView {
    struct Theme {
        let maxHeight: CGFloat = value(tvOS: 440, macOS: 280)
        let horizontalSpacing: CGFloat = value(tvOS: 50, macOS: 50, compactSize: 0)
    }
}

struct PlayerOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                PlayerOptionsView(media: Movie.dummy(),
                                  selectedTab: PlayerOptionsView.Selection.subtitles,
                                  audioDelay: .constant(0),
                                  audioProfile: .constant(.fullDynamicRange),
                                  subtitleDelay: .constant(0),
                                  subtitleEncoding: .constant(""),
                                  subtitle: .constant(nil),
                                  audioTrackIndex: .constant(0),
                                  audioTracks: [])
                Spacer()
            }
            
            VStack {
                PlayerOptionsView(media: Movie.dummy(),
                                  selectedTab: PlayerOptionsView.Selection.info,
                                  audioDelay: .constant(0),
                                  audioProfile: .constant(.fullDynamicRange),
                                  subtitleDelay: .constant(0),
                                  subtitleEncoding: .constant(""),
                                  subtitle: .constant(nil),
                                  audioTrackIndex: .constant(0),
                                  audioTracks: [])
                Spacer()
            }
            
            VStack {
                PlayerOptionsView(media: Movie.dummy(),
                                  selectedTab: PlayerOptionsView.Selection.audio,
                                  audioDelay: .constant(0),
                                  audioProfile: .constant(.fullDynamicRange),
                                  subtitleDelay: .constant(0),
                                  subtitleEncoding: .constant(""),
                                  subtitle: .constant(nil),
                                  audioTrackIndex: .constant(0),
                                  audioTracks: [])
                Spacer()
            }
        }
        .background(Color.gray)
        .ignoresSafeArea()
    }
}
