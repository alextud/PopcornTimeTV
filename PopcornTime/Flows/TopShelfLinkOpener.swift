//
//  TopShelfLinkOpener.swift
//  TopShelfLinkOpener
//
//  Created by Alexandru Tudose on 10.09.2021.
//  Copyright © 2021 PopcornTime. All rights reserved.
//

import SwiftUI
import PopcornKit
import ObjectMapper

struct TopShelfLinkOpener: ViewModifier {
    @State var media: Media?
    
    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                openUrl(url: url)
            }
            .navigationDestination(isPresented: .constant(media != nil)) {
                mediaView
            }
    }
    
    @ViewBuilder
    var mediaView: some View {
        switch media {
        case let movie as Movie:
            MovieDetailsView(viewModel: MovieDetailsViewModel(movie: movie))
        case let show as Show:
            ShowDetailsView(viewModel: ShowDetailsViewModel(show: show))
        default:
            EmptyView()
        }
    }
    
    func openUrl(url: URL) {
        if url.scheme == AppScheme {
            guard
                let actions = url.absoluteString.removingPercentEncoding?.components(separatedBy: "\(AppScheme):?action=").last?.components(separatedBy: "»"),
                let type = actions.first, let json = actions.last
                else {
                    return
            }
            
            switch type {
            case "showMovie":
                self.media = Mapper<Movie>().map(JSONString: json)
            case "showShow":
                self.media = Mapper<Show>().map(JSONString: json)
            default:
                break
            }
        }
    }

}
