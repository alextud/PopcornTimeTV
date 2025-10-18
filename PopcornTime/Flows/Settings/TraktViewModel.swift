//
//  TraktViewModel.swift
//  PopcornTime
//
//  Created by Alexandru Tudose on 18.09.2021.
//  Copyright © 2021 PopcornTime. All rights reserved.
//

import Foundation
import PopcornKit
import SwiftUI

class TraktViewModel: ObservableObject {
    @Published var displayCode: String?
    @Published var error: Error?
    
    var intervalTimer: Timer?
    var deviceCode: String?
    var expiresIn: Date?
    
    var onSuccess: () -> Void = {}
    
    init (onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
    }
    
    func getNewCode() {
        self.error = nil
        Task { @MainActor in
            do {
                let authorization = try await TraktAuthApi.shared.generateCode()
                self.displayCode = authorization.userCode
                self.expiresIn = authorization.expiresInDate
                self.deviceCode = authorization.deviceCode
                
                // Schedule timer on main run loop to avoid Swift 6 async context warning
                let timer = Timer(timeInterval: TimeInterval(authorization.interval), target: self, selector: #selector(self.poll), userInfo: nil, repeats: true)
                RunLoop.main.add(timer, forMode: .default)
                self.intervalTimer = timer
            } catch let error {
                self.error = error
            }
        }
    }
    
    func stopTimer() {
        self.intervalTimer?.invalidate()
        self.intervalTimer = nil
    }
    
    @objc public func poll(timer: Timer) {
        if let expiresIn = expiresIn, expiresIn < Date() {
            timer.invalidate()
            getNewCode()
        } else if let deviceCode = deviceCode, deviceCode.isEmpty == false {
            Task { @MainActor [weak self] in
                try await TraktAuthApi.shared.check(deviceCode: deviceCode)
                self?.onSuccess()
            }
        }
    }
}
