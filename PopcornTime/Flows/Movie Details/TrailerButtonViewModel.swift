//
//  TrailerButtonViewModel.swift
//  PopcornTimetvOS SwiftUI
//
//  Created by Alexandru Tudose on 21.06.2021.
//  Copyright © 2021 PopcornTime. All rights reserved.
//

import SwiftUI
import AVKit
import PopcornKit

class TrailerButtonViewModel: ObservableObject {
    var media: Media
    var trailerCode: String?
    var trailerUrl: URL? // scrapped from youtube
    @Published var error: Error?
    var season: Int? // only for shows

    
    init(movie: Movie) {
        self.media = movie
        self.trailerCode = movie.trailerCode
    }
    
    init(show: Show, season: Int) {
        self.media = show
        self.season = season
    }
    
    var _trailerVidePlayer: AVPlayer?
    var trailerVidePlayer: AVPlayer? {
        guard let url = trailerUrl else { return nil }
        if let player = _trailerVidePlayer {
            return player
        }
        
        let media = self.media
        let player = AVPlayer(url: url)
        
        #if os(tvOS) || os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowBluetoothA2DP, .allowAirPlay])
        
        let title = self.makeMetadataItem(.commonIdentifierArtwork, value: media.title)
        let summary = self.makeMetadataItem(.commonIdentifierDescription, value: media.summary)
        player.currentItem?.externalMetadata = [title, summary]
        
        if let string = media.mediumCoverImage,
            let url = URL(string: string) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url) {
                    let image = self.makeMetadataItem(.commonIdentifierArtwork, value: data as NSData)
                    Task { @MainActor in
                        player.currentItem?.externalMetadata.append(image)
                    }
                }
            }
        }
        #endif
        
        _trailerVidePlayer = player
        
        return player
    }
    
    @discardableResult
    func loadTrailerUrl() async throws -> URL {
        if let url = trailerUrl {
            return url
        }
        
        if trailerCode == nil, let tmdbId = self.media.tmdbId, let season {
            self.trailerCode = try? await TMDBApi.shared.getTrailerVideo(tmdbId: tmdbId, season: season)
        }
        
        let notFoundError = NSError(domain: "popcorn", code: 2, userInfo: [NSLocalizedDescriptionKey: "Trailer not found!".localized])
        guard let id = trailerCode else {
            throw notFoundError
        }
        
        let video = try await YoutubeApi.getVideo(id: id)
        guard let url = YoutubeApi.bestPlayableURL(from: video) else {
            throw notFoundError
        }
        self.trailerUrl = url
        
        return url
    }
    
    private func makeMetadataItem(_ identifier: AVMetadataIdentifier, value: Any) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as? NSCopying & NSObjectProtocol
        item.extendedLanguageTag = "und"
        return item.copy() as! AVMetadataItem
    }
}
