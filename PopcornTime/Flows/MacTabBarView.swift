//
//  Untitled.swift
//  PopcornTime
//
//  Created by Alexandru Tudose on 18.10.2025.
//  Copyright © 2025 PopcornTime. All rights reserved.
//
import SwiftUI

struct MacTabBarView: ViewModifier {
    @ObservedObject var searchModel: SearchViewModel
    @Binding var selectedTab: TabBarView.Selection
    
    func body(content: Content) -> some View {
        ZStack {
            if selectedTab == .search {
                searchView
            } else {
               content
            }
        }
        .toolbar(content: {
            ToolbarItem(placement: .primaryAction) {
                EmptyView()
                    .searchable(text: $searchModel.search)
                    .onChange(of: searchModel.search) { newValue in
                        if selectedTab != .search {
                            searchModel.selection = selectedTab == .shows ? .shows : .movies
                        }
                        selectedTab = newValue.isEmpty ? .movies : .search
                    }
            }
        })
    }
    
    var searchView: some View {
        SearchView(viewModel: searchModel)
            .tag(TabBarView.Selection.search)
            .toolbar(content: {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $searchModel.selection) {
                        Text("Movies").tag(SearchViewModel.SearchType.movies)
                        Text("Shows").tag(SearchViewModel.SearchType.shows)
                        Text("People").tag(SearchViewModel.SearchType.people)
                    }
                    .pickerStyle(.segmented)
                }
            })
    }
}
