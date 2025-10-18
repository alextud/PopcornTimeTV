//
//  SearchView.swift
//  PopcornTimetvOS SwiftUI
//
//  Created by Alexandru Tudose on 19.06.2021.
//  Copyright © 2021 PopcornTime. All rights reserved.
//

import SwiftUI
import PopcornKit

struct SearchView: View, CharacterHeadshotLoader {
    struct Theme {
        let itemWidth: CGFloat = value(tvOS: 240, macOS: 160)
        let personWidth: CGFloat  = value(tvOS: 220, macOS: 150)
        var horizontalPadding: CGFloat { value(tvOS: 40, macOS: 40, compactSize: 10) }
        let itemSpacing: CGFloat = value(tvOS: 30, macOS: 20)
        let columnSpacing: CGFloat = value(tvOS: 60, macOS: 30)
    }
    static let theme = Theme()
    
    @StateObject var viewModel = SearchViewModel()
    @FocusState private var isFocused: Bool
    
    let columns = [
        GridItem(.adaptive(minimum: theme.itemWidth), spacing: theme.itemSpacing)
    ]
    
    
    var body: some View {
        VStack {
            searchView
            errorView
            if viewModel.isLoading {
                ProgressView()
            }
            switch viewModel.selection {
            case .movies:
                moviesSection
            case .shows:
                showsSection
            case .people:
                peopleSection
            }
            Spacer()
        }
        #if os(iOS) || os(tvOS)
        .searchable(text: $viewModel.search)
        .focused($isFocused)
        #endif
        #if os(iOS)
        .navigationBarHidden(true)
        .onAppear {
            if viewModel.search.isEmpty {
                isFocused = true
            }
        }
        #endif
    }
    
    @ViewBuilder
    var searchView: some View {
        #if os(iOS)
        VStack {
            SearchBarView(text: $viewModel.search)
            pickerView
            .pickerStyle(.segmented)
        }
        .padding([.leading, .trailing])
        .padding(.horizontal, SearchView.theme.horizontalPadding)
        #elseif os(tvOS)
        pickerView
        #elseif os(macOS)
//        pickerView
//            .pickerStyle(.segmented)
//            .frame(maxWidth: 200)
//            .padding()
        #endif
    }
    
    @ViewBuilder
    var pickerView: some View {
        Picker("", selection: $viewModel.selection) {
             Text("Movies").tag(SearchViewModel.SearchType.movies)
             Text("Shows").tag(SearchViewModel.SearchType.shows)
             Text("People").tag(SearchViewModel.SearchType.people)
        }
    }
    
    @ViewBuilder
    var moviesSection: some View {
        if viewModel.movies.isEmpty && !viewModel.isLoading {
            emptyView
        } else {
            scrollContainerView {
                ForEach(viewModel.movies, id: \.self) { movie in
                    NavigationLink(
                        destination: MovieDetailsView(viewModel: MovieDetailsViewModel(movie: movie)),
                        label: {
                            MovieView(movie: movie)
                                .frame(width:SearchView.theme.itemWidth)
                        })
                    .buttonStyle(PlainNavigationLinkButtonStyle())
                }
            }
        }
    }
    
    @ViewBuilder
    var showsSection: some View {
        if viewModel.shows.isEmpty && !viewModel.isLoading {
            emptyView
        } else {
            scrollContainerView {
                ForEach(viewModel.shows, id: \.self) { show in
                    NavigationLink(
                        destination: ShowDetailsView(viewModel: ShowDetailsViewModel(show: show)),
                        label: {
                            ShowView(show: show)
                                .frame(width:SearchView.theme.itemWidth)
                        })
                        .buttonStyle(PlainNavigationLinkButtonStyle())
                }
            }
        }
    }
    
    @ViewBuilder
    var peopleSection: some View {
        if viewModel.persons.isEmpty && !viewModel.isLoading {
            emptyView
        } else {
            let persons = viewModel.persons
            
            scrollContainerView {
                ForEach(0..<persons.count, id: \.self) { index in
                    NavigationLink(
                        destination: PersonDetailsView(viewModel: PersonDetailsViewModel(person: persons[index])),
                        label: {
                            PersonView(person: persons[index], radius: SearchView.theme.personWidth)
                        })
                        .buttonStyle(PlainNavigationLinkButtonStyle())
                        .task {
                            await loadHeadshotIfMissing(person: persons[index], into: $viewModel.persons)
                        }
                }
            }
        }
    }
    
    @ViewBuilder
    var errorView: some View {
        if let error = viewModel.error {
            HStack() {
                Spacer()
                ErrorView(error: error)
                    .padding(.bottom, 100)
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    func scrollContainerView(content:() -> some View) -> some View {
        #if os(tvOS)
        ScrollView(.horizontal) {
            LazyHStack(spacing: 40) {
                content()
            }
            .padding(.leading, 50)
            Spacer()
        }
        .focusSection()
        #endif
        
        #if os(iOS) || os(macOS)
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: SearchView.theme.columnSpacing) {
                content()
            }
            .padding()
        }
//        .scrollDismissesKeyboard(.immediately)
        #endif
    }
    
    @ViewBuilder
    var emptyView: some View {
        if viewModel.search.count > 0 && viewModel.error == nil {
            let openQuote = Locale.current.quotationBeginDelimiter ?? "\""
            let closeQuote = Locale.current.quotationEndDelimiter ?? "\""
            let description = String.localizedStringWithFormat("We didn't turn anything up for %@. Try something else.".localized, "\(openQuote + viewModel.search + closeQuote)")
            
            VStack {
                Spacer()
                Text("No results")
                    .font(.title2)
                    .padding()
                Text(description)
                    .font(.callout)
                    .foregroundColor(.appSecondary)
                    .frame(maxWidth: 400)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        let searchView = SearchView()
//        searchView.viewModel.movies = Movie.dummiesFromJSON()
//        searchView.viewModel.isLoading = true
//        NavigationView {
            searchView
//        }
//        return searchView
    }
}
