//
//  TabBarView.swift
//  PopcornTimetvOS SwiftUI
//
//  Created by Alexandru Tudose on 19.06.2021.
//  Copyright © 2021 PopcornTime. All rights reserved.
//

import SwiftUI

struct CurrentTabKey: EnvironmentKey {
    static var defaultValue: TabBarView.Selection = .movies
}
extension EnvironmentValues {
    var currentTab: TabBarView.Selection {
        get { self[CurrentTabKey.self] }
        set { self[CurrentTabKey.self] = newValue }
    }
}

struct TabBarView: View {
    enum Selection: Int {
        case movies = 0, shows, watchlist, search, downloads, settings
    }
    @State var selectedTab = Selection.movies
    @StateObject var searchModel = SearchViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            #if os(tvOS) || os(iOS)
            SearchView(viewModel: searchModel)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    #if os(iOS)
                    Text("Search")
                    #endif
                }
                .tag(Selection.search)
            #endif
            MoviesView()
                .tabItem {
                    #if os(iOS)
                    Image("Movies On").renderingMode(.template)
                    #endif
                    Text("Movies")
                }
                .tag(Selection.movies)
            ShowsView()
                .tabItem {
                    #if os(iOS)
                    Image("Shows On").renderingMode(.template)
                    #endif
                    Text("Shows")
                }
                .tag(Selection.shows)
            WatchlistView()
                .tabItem {
                    #if os(iOS)
                    Image("Watchlist On").renderingMode(.template)
                    #endif
                    Text("Watchlist")
                }
                .tag(Selection.watchlist)
            DownloadsView()
                .tabItem {
                    #if os(iOS)
                    Image(systemName: "square.and.arrow.down")
                    #endif
                    Text("Downloads")
                }
                .tag(Selection.downloads)
            #if os(tvOS) || os(iOS)
            SettingsView()
                .tabItem {
                    #if os(iOS)
                    Image("Settings On").renderingMode(.template)
                    #endif
                    Text("Settings")
                }
                .tag(Selection.settings)
            #endif
            
        }
        .environment(\.currentTab, selectedTab)
        #if os(macOS)
        .modifier(MacTabBarView(searchModel: searchModel, selectedTab: $selectedTab))
        #else
        .ignoresSafeArea()
        #endif
    }
}

struct TabBarView_Previews: PreviewProvider {
    static var previews: some View {
        TabBarView()
            .preferredColorScheme(.dark)
            .tint(.white)
    }
}
