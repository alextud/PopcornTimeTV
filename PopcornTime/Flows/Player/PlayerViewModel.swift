//
//  PlayerViewModel.swift
//  PopcornTimetvOS SwiftUI
//
//  Created by Alexandru Tudose on 21.06.2021.
//  Copyright © 2021 PopcornTime. All rights reserved.
//

import Foundation
import PopcornKit
#if os(tvOS)
import TVVLCKit
#elseif os(iOS)
import MobileVLCKit
#elseif os(macOS)
import VLCKit
typealias SiriRemoteGestureRecognizer = Any
#endif
import PopcornTorrent
import AVKit
import MediaPlayer
import SwiftUI


enum TransportBarHint: String {
    case none
    case fastForward = "ScanForward"
    case rewind = "ScanBackward"
    case jumpForward30 = "SkipForward30"
    case jumpBackward30 = "SkipBack30"
}


class PlayerViewModel: NSObject, ObservableObject {
    var media: Media
    private(set) var mediaplayer = VLCMediaPlayer()
    private var nowPlaying: NowPlayingController
    var audioController: PlayerAudioModel
    var subtitleController: PlayerSubtitleModel
    
    private(set) var streamer: PTTorrentStreamer
    
    private var idleWorkItem: DispatchWorkItem?
    internal var workItem: DispatchWorkItem?
    internal var torrentStatusChangeObserver: AnyObject?
    
    internal var startPosition: Float = 0.0
    var resumePlayback = false
    @Published var resumePlaybackAlert = false
    
    @Published var isLoading = true
    @Published var isPlaying = false
    @Published var showControls = false
    @Published var showInfo = false
    
    var dismiss: DismissAction?
    
    struct Progress {
        var progress: Float = 0
        var isBuffering = false
        var bufferProgress: Float = 0
        var isScrubbing = false
        var scrubbingProgress: Float = 0
        var remainingTime: String = ""
        var elapsedTime: String = ""
        var scrubbingTime: String = ""
        var screenshot: CGImage?
        var hint: TransportBarHint = .none
        var showUpNext = false
        var showUpNextProgress: CGFloat = 0
        
        #if os(macOS)
        var screenshotImage: NSImage? {
            screenshot.flatMap{ NSImage(cgImage: $0, size: NSSize(width: 200, height: 100)) }
        }
        #elseif os(iOS)
        var screenshotImage: UIImage? {
            screenshot.flatMap{ UIImage(cgImage: $0, scale: 2.5, orientation: .up) }
        }
        #elseif os(tvOS)
        var screenshotImage: UIImage? {
            screenshot.flatMap{ UIImage(cgImage: $0, scale: 1, orientation: .up) }
        }
        #endif
    }
    @Published var progress = Progress()
    
    init(media: Media, fromUrl: URL, localUrl: URL, directory: URL, streamer: PTTorrentStreamer) {
        self.media = media
        self.streamer = streamer
        #if os(tvOS) || os(iOS)
        mediaplayer.audio?.passthrough = true
        #endif
        let vlcMedia = VLCMedia(url: fromUrl)
        // Set title metadata to prevent crash in VLC's ArtCacheGetDirPath when title is NULL
        vlcMedia.metaData.title = media.title
        mediaplayer.media = vlcMedia

        self.nowPlaying = NowPlayingController(mediaplayer: mediaplayer, media: media, localPathToMedia: localUrl)
        self.audioController = PlayerAudioModel(mediaplayer: mediaplayer)
        self.subtitleController = PlayerSubtitleModel(media: media, mediaplayer: mediaplayer, directory: directory, localPathToMedia: localUrl)
        
        super.init()
        mediaplayer.delegate = self
        self.nowPlaying.onPlayPause = { [weak self] in
            self?.playandPause()
        }
        
        torrentStatusChangeObserver = NotificationCenter.default.addObserver(forName: .PTTorrentStatusDidChange, object: streamer, queue: nil) { [unowned self] notification in
            guard !resumePlaybackAlert else { // will trigger UI invalidation - and screen becomes unresponsive
                return
            }
            progress.bufferProgress = streamer.torrentStatus.totalProgress
        }
    }
    
    deinit {
        if let observer = torrentStatusChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func playOnAppear() {
        guard mediaplayer.state == .stopped || mediaplayer.state == .opening else { return }
        
        if startPosition > 0.0 {
            isLoading = false
            resumePlaybackAlert = true
        } else {
            // delay a little bit as it seems that vlcplayer sometimes for downloaded items will dismiss without requesting content from gcdwebserver
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                self.mediaplayer.play()
            })
        }
    }
    
    func play(resumePlayback:Bool = false) {
        if resumePlayback {
            self.resumePlayback = resumePlayback
        }
        isLoading = true
        mediaplayer.play()
    }
    
    func stop() {
        mediaplayer.stop()
        idleWorkItem?.cancel()
    }
    
    func playandPause() {
        if isLoading {
            return
        }
        
        #if os(tvOS)
        self.clickGesture()
        #else
        isPlaying ? mediaplayer.pause() : mediaplayer.play()
        #endif
    }
    
    func fastForward() {
        if progress.isScrubbing {
            progress.scrubbingProgress += 0.01
            positionSliderDidDrag()
        } else {
            mediaplayer.jumpForward(30)
        }
        
    }
    
    func rewind() {
        if progress.isScrubbing {
            progress.scrubbingProgress -= 0.01
            positionSliderDidDrag()
        } else {
            mediaplayer.jumpBackward(30)
        }
    }
    
    func fastForwardHeld(_ starded: Bool) {
        if starded {
            progress.hint = .fastForward
            if mediaplayer.rate == 1.0 {
                mediaplayer.fastForward(atRate: 20.0)
            }
        } else {
            progress.hint = .none
            mediaplayer.rate = 1.0
            resetIdleTimer()
        }
    }
    
    func rewindHeld(_ starded: Bool) {
        if starded {
            progress.hint = .rewind
            if mediaplayer.rate == 1.0 {
                mediaplayer.rewind(atRate: 20.0)
            }
        } else {
            progress.hint = .none
            mediaplayer.rate = 1.0
            resetIdleTimer()
        }
    }
    
    func clickGesture() {
        if progress.isScrubbing {
            endScrubbing()

            // seek to desired position
            if mediaplayer.isSeekable && progress.progress != progress.scrubbingProgress {
                let streamDuration = nowPlaying.streamDuration
                let time = NSNumber(value: progress.scrubbingProgress * streamDuration)
                mediaplayer.time = VLCTime(number: time)
                // Force a progress change rather than waiting for VLCKit's delegate call to.
                progress.progress = progress.scrubbingProgress
                progress.elapsedTime = progress.scrubbingTime
            }
        } else {
            startScrubbing()
        }
    }
    
    func handlePositionSliderDrag(offset: Float) {
        guard showControls && progress.isScrubbing else {
            return
        }
        
        progress.scrubbingProgress += offset
        progress.scrubbingProgress = max(0, progress.scrubbingProgress)
        positionSliderDidDrag()
    }
    
    func positionSliderDidDrag() {
        let streamDuration = nowPlaying.streamDuration
        let time = NSNumber(value: progress.scrubbingProgress * streamDuration)
        let remainingTime = NSNumber(value: time.floatValue - streamDuration)
        progress.remainingTime = VLCTime(number: remainingTime).stringValue
        progress.scrubbingTime = VLCTime(number: time).stringValue
        workItem?.cancel()
        let percentage = progress.scrubbingProgress
        workItem = DispatchWorkItem { [weak self] in
            if let image = self?.nowPlaying.screenshotAtTime(time) {
                self?.progress.screenshot = image
            } else {
                self?.nowPlaying.vlcScreenshotAtPercentage(percentage, completion: { image in
                    self?.progress.screenshot = image
                })
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem!)
    }
    
    func toggleControlsVisible() {
        showControls.toggle()
        progress.hint = .none
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.resetIdleTimer()
        }
        #if os(macOS)
        if showControls == false {
            NSCursor.setHiddenUntilMouseMoves(true)
        }
        #endif
    }

    func endScrubbing() {
        mediaplayer.willPlay ? mediaplayer.play() : ()
        resetIdleTimer()
        progress.isScrubbing = false
        progress.hint = .none
//        showControls = false
    }
    
    func startScrubbing() {
        mediaplayer.canPause ? mediaplayer.pause() : ()
//        !isLoading ? toggleControlsVisible() : ()
        progress.isScrubbing = true
        progress.scrubbingProgress = progress.progress
        showControls = true
        progress.screenshot = nil
        
        if let image = nowPlaying.screenshot(at: progress.progress) {
            progress.screenshot = image
        } else {
            let percentage = progress.scrubbingProgress
            self.nowPlaying.vlcScreenshotAtPercentage(percentage, completion: { image in
                self.progress.screenshot = image
            })
        }
    }

    
    func saveMediaProgress(status: Trakt.WatchedStatus) {
        if let movie = media as? Movie {
            WatchedlistManager<Movie>.movie.setCurrentProgress(progress.progress, for: movie.id, with: status)
        } else if let episode = media as? Episode {
            WatchedlistManager<Episode>.episode.setCurrentProgress(progress.progress, for: episode.id, with: status)
        }
    }
    
    func resetIdleTimer() {
        idleWorkItem?.cancel()
        idleWorkItem = DispatchWorkItem() { [weak self] in
            guard let self = self else {
                return
            }
            
            if self.showControls && self.mediaplayer.isPlaying && !self.progress.isScrubbing && !self.progress.isBuffering && self.mediaplayer.rate == 1.0
                //&& self.movieView.isDescendant(of: self.view) // If paused, scrubbing, fast forwarding, loading or mirroring, cancel work Item so UI doesn't disappear
            {
                self.toggleControlsVisible()
            }
        }
        
        #if os(tvOS)
        let delay: TimeInterval = 3
        #else
        let delay: TimeInterval = 10
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: idleWorkItem!)
    }
    
    func didFinishPlaying() {
        mediaplayer.delegate = nil
        mediaplayer.stop()
        
        nowPlaying.removeRemoteCommandCenterHandlers()
//        endReceivingScreenNotifications()
        
        streamer.cancelStreamingAndDeleteData(Session.removeCacheOnPlayerExit)
        
        saveMediaProgress(status: .finished)
        NotificationCenter.default.removeObserver(self, name: .PTTorrentStatusDidChange, object: nil)
        
        dismiss?()
    }
    
    @Published var videoAspectRatio: SwiftUI.ContentMode = .fit
    func switchVideoDimensions() {
        #if os(iOS)
        resetIdleTimer()
        if mediaplayer.videoCropGeometry == nil // Change to aspect to scale to fill
        {
            let screen =  UIScreen.screens.count > 1 ? UIScreen.screens[1] : UIScreen.main
            let size = screen.bounds.size
            mediaplayer.videoCropGeometry = UnsafeMutablePointer<Int8>(mutating: (size.vlcAspectRatio as NSString).utf8String)
//            screenshotImageView!.contentMode = .scaleAspectFill
        } else // Change aspect ratio to scale to fit
        {
            mediaplayer.videoAspectRatio = nil
            mediaplayer.videoCropGeometry = nil
//            screenshotImageView!.contentMode = .scaleAspectFit
        }
        #endif
    }
}

extension PlayerViewModel: VLCMediaPlayerDelegate {
    
    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        if isLoading {
            isLoading = false

            nowPlaying.addRemoteCommandCenterHandlers()
//            beginReceivingScreenNotifications()
            nowPlaying.configureNowPlayingInfo()

            resetIdleTimer()
        } else {
            nowPlaying.configureNowPlayingPositions()
        }
        
        if resumePlayback && mediaplayer.isSeekable {
            let streamDuration = nowPlaying.streamDuration
            resumePlayback = streamDuration == 0 // check if the current stream length is available if not retry to go to previous position
            if resumePlayback == false {
                let time = NSNumber(value: startPosition * streamDuration)
                mediaplayer.time = VLCTime(number: time)
            }
        }
        
        isPlaying = true
        
        progress.isBuffering = false
        progress.remainingTime = mediaplayer.remainingTime?.stringValue ?? ""
        progress.elapsedTime = mediaplayer.time.stringValue
        progress.progress = mediaplayer.position
        
        let remaining = mediaplayer.remainingTime.flatMap({ Int($0.intValue / 1000) })
        if let remaining = remaining, mediaplayer.position > 0.9, remaining >= -ShowUpNextDuration {
            if progress.showUpNext == false && progress.showUpNextProgress == 0 {
                progress.showUpNext = true
                progress.showUpNextProgress = 1.0
            } else {
                progress.showUpNextProgress = CGFloat(CGFloat(-remaining) / CGFloat(ShowUpNextDuration))
            }
        } else {
            progress.showUpNext = false
        }
    }
    
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        nowPlaying.configureNowPlayingPositions()
        resetIdleTimer()
        progress.isBuffering = false
        switch mediaplayer.state {
        case .error:
            fallthrough
        case .ended:
            fallthrough
        case .stopped:
            let mediaEndedOnStart = mediaplayer.position == 0 // workaround
            if !mediaEndedOnStart {
                didFinishPlaying()
            }
        case .paused:
            saveMediaProgress(status: .paused)
            isPlaying = false
        case .playing:
            isPlaying = true
            saveMediaProgress(status: .watching)
        case .buffering:
            progress.isBuffering = true
        case .opening:
            break
        case .esAdded:
            break
        @unknown default:
            break
        }
    }
}
