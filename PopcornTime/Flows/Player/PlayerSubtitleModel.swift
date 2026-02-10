//
//  PlayerSubtitleModel.swift
//  PlayerSubtitleModel
//
//  Created by Alexandru Tudose on 26.08.2021.
//  Copyright © 2021 PopcornTime. All rights reserved.
//

import Foundation
import SwiftUI
#if os(tvOS)
import TVVLCKit
#elseif os(iOS)
import MobileVLCKit
#elseif os(macOS)
import VLCKit
#endif
import PopcornKit

class PlayerSubtitleModel {
    private(set) var media: Media
    private(set) var mediaplayer: VLCMediaPlayer
    private(set) var downloadDirectory: URL
    private let NSNotFound: Int32 = -1
    let settings = SubtitleSettings.shared
    var currentSubtitle: Subtitle?
    
    public let vlcSettingTextEncoding = "subsdec-encoding"
    
    init(media: Media, mediaplayer: VLCMediaPlayer, directory: URL, localPathToMedia: URL) {
        self.media = media
        self.mediaplayer = mediaplayer
        self.downloadDirectory = directory
        mediaplayer.currentVideoSubTitleDelay = 0

        loadSubtitles(localPathToMedia: localPathToMedia)
        
        let vlcAppearance = mediaplayer as VLCFontAppearance
        vlcAppearance.setTextRendererFontSize?(NSNumber(value: settings.size.rawValue))
        vlcAppearance.setTextRendererFontColor?(NSNumber(value: settings.color.rawValue))
        vlcAppearance.setTextRendererFontForceBold?(NSNumber(booleanLiteral: settings.style == .bold || settings.style == .boldItalic))
        // Only set custom font if it's not a system font (system fonts start with ".")
        if !settings.fontName.hasPrefix(".") {
            vlcAppearance.setTextRendererFont?(settings.fontName as NSString)
        }
        
        mediaplayer.media?.addOptions([vlcSettingTextEncoding: settings.encoding])
    }
    
    func loadSubtitles(localPathToMedia: URL) {
        if media.subtitles.count == 0 {
            Task { @MainActor in
                do {
                    var subtitles = try await media.getSubtitles()
                    if subtitles.isEmpty {
                        subtitles = try await media.getSubtitles(orWithFilePath: localPathToMedia)
                    }
                    
                    self.media.subtitles = subtitles
                    configureUserDefaultSubtitle()
                } catch (let error){
                    print(error)
                }
                
                
            }
        } else {
            configureUserDefaultSubtitle()
        }
    }
    
    func configureUserDefaultSubtitle() {
        if let preferredLanguage = settings.language {
            self.currentSubtitle = media.subtitles[preferredLanguage]?.first
            configurePlayer(subtitle: self.currentSubtitle)
        }
    }
    
    func configurePlayer(subtitle: Subtitle?) {
        if let subtitle = subtitle {
            Task { @MainActor in
                do {
                    guard subtitle.fileId > 0 else {
                        return
                    }
                    let subtitlePath = try await PopcornKit.downloadOpenSubtitleFile(subtitle, downloadDirectory: downloadDirectory)
                    self.mediaplayer.addPlaybackSlave(subtitlePath, type: .subtitle, enforce: true)
                } catch {
                    print("[Subtitle] ", error)
                }
            }
        } else {
            mediaplayer.currentVideoSubTitleIndex = NSNotFound // Remove all subtitles
        }
    }
    
    lazy var subtitleEncodingBinding: Binding<String> =  {
        Binding(get: { [unowned self] in
            settings.encoding
        }, set: { [unowned self] encoding in
            settings.encoding = encoding
            settings.save()
            mediaplayer.media?.addOptions([vlcSettingTextEncoding: encoding])
        })
    }()
    
    lazy var subtitleDelayBinding: Binding<Int> = {
        Binding(get: { [unowned self] in
            mediaplayer.currentVideoSubTitleDelay / 1_000_000 // from microseconds to seconds
        }, set: { [unowned self] newDelay in
            mediaplayer.currentVideoSubTitleDelay = newDelay * 1_000_000
        })
    }()
    
    lazy var subtitleBinding: Binding<Subtitle?> = {
        Binding(get: { [unowned self] in
            currentSubtitle
        }, set: { [unowned self] subtitle in
            currentSubtitle = subtitle
            configurePlayer(subtitle: subtitle)
        })
    }()
}
