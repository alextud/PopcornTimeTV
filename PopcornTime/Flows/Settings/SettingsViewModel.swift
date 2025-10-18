//
//  SettingsViewModel.swift
//  PopcornTimetvOS SwiftUI
//
//  Created by Alexandru Tudose on 31.07.2021.
//  Copyright © 2021 PopcornTime. All rights reserved.
//

import SwiftUI
import PopcornKit
import Network

class SettingsViewModel: ObservableObject {
    @Published var clearCache = ClearCache()
    
    @Published var isTraktLoggedIn: Bool = TraktSession.shared.isLoggedIn()
    var traktAuthorizationUrl: URL {
        return TraktAuthApi.shared.authorizationUrl(appScheme: AppScheme)
    }
    
    // MARK: - OpenSubtitles
    @Published var isOpenSubtitlesLoggedIn: Bool = SubtitlesApi.shared.isLoggedIn
    @Published var isOpenSubtitlesLoading: Bool = false
    @Published var openSubtitlesLoginError: String?
    
    var lastUpdate: String {
        var date = "Never".localized
        if let lastChecked = Session.lastVersionCheckPerformedOnDate {
            date = DateFormatter.localizedString(from: lastChecked, dateStyle: .short, timeStyle: .short)
        }
        return date
    }
    
    var version: String {
        let bundle = Bundle.main
        return [bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString"), bundle.object(forInfoDictionaryKey: "CFBundleVersion")].compactMap({$0 as? String}).joined(separator: ".")
    }
    
    func validate(traktUrl: URL) {
        if traktUrl.scheme?.lowercased() == AppScheme.lowercased() {
            Task { @MainActor in
                try await TraktAuthApi.shared.authenticate(traktUrl)
                self.traktDidLoggedIn()
            }
        }
    }
    
    func traktLogout() {
        TraktSession.shared.logout()
        isTraktLoggedIn = false
    }
    
    func traktDidLoggedIn() {
        isTraktLoggedIn = true
        TraktApi.shared.syncUserData()
    }
    
    // MARK: - OpenSubtitles Methods
    func openSubtitlesLogin(username: String, password: String) {
        guard !username.isEmpty && !password.isEmpty else { return }
        
        isOpenSubtitlesLoading = true
        openSubtitlesLoginError = nil
        
        Task { @MainActor in
            do {
                _ = try await SubtitlesApi.shared.login(username: username, password: password)
                self.isOpenSubtitlesLoggedIn = true
                self.openSubtitlesLoginError = nil
            } catch {
                self.openSubtitlesLoginError = error.localizedDescription
                // Keep the dialog open by not changing the login state
                // The error message will be displayed in the dialog
            }
            self.isOpenSubtitlesLoading = false
        }
    }
    
    func openSubtitlesLogout() {
        self.isOpenSubtitlesLoading = true
        Task { @MainActor in
            do {
                try await SubtitlesApi.shared.logout()
            } catch {
                print("OpenSubtitles logout error: \(error)")
            }
            self.isOpenSubtitlesLoggedIn = false
            self.isOpenSubtitlesLoading = false
        }
    }
    
    @Published var serverUrl: String = PopcornKit.serverURL()
    var chekServerIsUpTask: Task<(), Never>?
    
    func changeUrl(_ url: String) {
        self.chekServerIsUpTask?.cancel()
        self.chekServerIsUpTask = Task { @MainActor [weak self] in
            self?.serverUrl = await PopcornKit.setUserCustomUrls(newUrl: url)
            self?.chekServerIsUpTask = nil
        }
    }
    
    var networkMonitor: NWPathMonitor = {
        let monitor = NWPathMonitor()
        monitor.start(queue: .global())
        return monitor
    }()
    
    var hasCellularNetwork: Bool {
        return networkMonitor.currentPath.availableInterfaces.contains(where: {$0.type == .cellular }) || networkMonitor.currentPath.isExpensive
    }
}
