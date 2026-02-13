//
//  YoutubeApi.swift
//  PopcornTime
//
//  Created by Alexandru Tudose on 04.08.2021.
//  Copyright © 2021 PopcornTime. All rights reserved.
//

import Foundation

// https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/youtube.py
class YoutubeApi {
    struct Video: Decodable {
        struct Streaming: Decodable {
            struct Format: Decodable {
                var url: URL?
                var mimeType: String?
                var qualityLabel: String? // only for video tracks
                var width: Int?
            }
            var formats: [Format]?
            var adaptiveFormats: [Format]?
            var hlsManifestUrl: URL?
        }

        var streamingData: Streaming?
    }

    /// Returns a playable URL for the given YouTube video ID.
    /// Tries IOS client first (returns HLS with adaptive quality), falls back to ANDROID (works in EU without consent).
    class func getVideo(id: String) async throws -> Video {
        // Try IOS client first - returns HLS manifest with adaptive quality (up to 1080p+)
        if let video = try? await fetchVideo(id: id, client: .ios),
           video.streamingData != nil {
            return video
        }

        // Fallback to ANDROID client - works in EU without consent issues
        return try await fetchVideo(id: id, client: .android)
    }

    /// Best playable URL from video response - prefers HLS, then best combined format
    /// Note: adaptive format URLs require YouTube-specific headers and won't play in AVPlayer directly
    class func bestPlayableURL(from video: Video) -> URL? {
        guard let streaming = video.streamingData else { return nil }

        // Prefer HLS manifest (works directly with AVPlayer, adaptive quality up to 1080p+)
        if let hls = streaming.hlsManifestUrl {
            return hls
        }

        // Fallback to best combined format (has both video+audio, playable without special headers)
        if let format = streaming.formats?
            .filter({ $0.url != nil })
            .max(by: { ($0.width ?? 0) < ($1.width ?? 0) }) {
            return format.url
        }

        return nil
    }

    // MARK: - Private

    private enum Client {
        case android, ios
    }

    private class func fetchVideo(id: String, client: Client) async throws -> Video {
        let body: String
        let userAgent: String

        switch client {
        case .android:
            userAgent = "com.google.android.youtube/19.02.39 (Linux; U; Android 14) gzip"
            body = """
            {
              "context": {
                "client": {
                  "clientName": "ANDROID",
                  "clientVersion": "19.02.39",
                  "androidSdkVersion": 34,
                  "hl": "en"
                }
              },
              "videoId": "\(id)",
              "contentCheckOk": true,
              "racyCheckOk": true
            }
            """
        case .ios:
            userAgent = "com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X;)"
            body = """
            {
              "context": {
                "client": {
                  "clientName": "IOS",
                  "clientVersion": "19.29.1",
                  "deviceModel": "iPhone16,2",
                  "userAgent": "\(userAgent)",
                  "hl": "en"
                }
              },
              "videoId": "\(id)"
            }
            """
        }

        let url = URL(string: "https://www.youtube.com/youtubei/v1/player")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let video = try JSONDecoder().decode(Video.self, from: data)
    
        return video
    }
}
