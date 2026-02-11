//
//  PlayerControlGestures.swift
//  PopcornTime
//
//  Created by Alexandru Tudose on 21.10.2022.
//  Copyright © 2022 PopcornTime. All rights reserved.
//

import SwiftUI

extension VLCPlayerView {
    
    #if os(tvOS)
    func addGestures(viewModel: PlayerViewModel, dismiss: DismissAction, playerHasFocus: Bool, namespace: Namespace.ID) -> some View {
        self
            .addGestures(onSwipeDown: {
                guard !viewModel.progress.showUpNext else { return }
                withAnimation {
                    viewModel.showInfo = true
                }
            }, onSwipeUp: {
                guard !viewModel.progress.showUpNext else { return }
                withAnimation {
                    viewModel.showControls = true
                }
            }, onPositionSliderDrag: { offset in
                viewModel.handlePositionSliderDrag(offset: offset)
            })
            .focusable(playerHasFocus)
            .prefersDefaultFocus(!viewModel.showInfo, in: namespace)
            .onLongPressGesture(minimumDuration: 0.01, perform: {
                withAnimation {
                    if viewModel.showControls {
                        viewModel.clickGesture()
                    } else {
                        viewModel.toggleControlsVisible()
                    }
                }
            })
            .onPlayPauseCommand {
                withAnimation {
                    viewModel.playandPause()
                }
            }
            .onMoveCommand(perform: { direction in
                switch direction {
                case .down:
                    withAnimation(.spring()) {
                        viewModel.showInfo = true
                    }
                case .up:
                    withAnimation {
                        viewModel.showControls = true
                    }
                    viewModel.resetIdleTimer()
                case .left:
                    withAnimation {
                        viewModel.showControls = true
                    }
                    viewModel.rewind()
                    viewModel.progress.hint = .rewind
                    viewModel.resetIdleTimer()
                case .right:
                    withAnimation {
                        viewModel.showControls = true
                    }
                    viewModel.fastForward()
                    viewModel.progress.hint = .fastForward
                    viewModel.resetIdleTimer()
                @unknown default:
                    break
                }
            })
            .onExitCommand {
                if viewModel.showInfo {
                    withAnimation{
                        viewModel.showInfo = false
                    }
                } else if viewModel.showControls {
                    withAnimation{
                        viewModel.showControls = false
                    }
                } else {
                    viewModel.stop()
                    dismiss()
                }
            }
    }
    
    #else
    func addGestures(viewModel: PlayerViewModel, dismiss: DismissAction) -> some View {
        self
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    if viewModel.showInfo == true {
                        viewModel.showInfo = false
                    } else {
                        viewModel.toggleControlsVisible()
                    }
                }
            }
    }
    #endif
}
