import Foundation
import ObjectMapper

/// Response wrapper for OpenSubtitles API v1
private struct SubtitlesResponse: Mappable {
    var data: [Subtitle] = []
    var totalPages: Int = 0
    var totalCount: Int = 0
    var page: Int = 1
    
    init?(map: Map) {
        mapping(map: map)
    }
    
    mutating func mapping(map: Map) {
        data <- map["data"]
        totalPages <- map["total_pages"]
        totalCount <- map["total_count"]
        page <- map["page"]
    }
}

open class SubtitlesApi {
    
    /// Creates new instance of SubtitlesManager class
    public static let shared = SubtitlesApi()
    
    /// OpenSubtitles authentication token storage
    private var bearerToken: String? {
        get { UserDefaults.standard.string(forKey: "OpenSubtitlesBearerToken") }
        set { UserDefaults.standard.set(newValue, forKey: "OpenSubtitlesBearerToken") }
    }
    
    /// Check if user is logged in to OpenSubtitles
    public var isLoggedIn: Bool {
        return bearerToken != nil
    }
    
    let client = HttpClient(config: .init(serverURL: OpenSubtitles.base, configuration: {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpAdditionalHeaders = OpenSubtitles.defaultHeaders
        return configuration
    }()))
    
    /**
     Load subtitles from API. Use episode or ImdbId not both. Using ImdbId rewards better results.
     
     - Parameter episode:       The show episode.
     - Parameter imdbId:        The Imdb identification code of the episode or movie.
     - Parameter limit:         The limit of subtitles to fetch as a `String`. Defaults to 500.
     - Parameter videoFilePath: The path of the video for subtitle retrieval `URL`. Defaults to nil.
     */
    open func search(_ episode: Episode? = nil, imdbId: String? = nil, preferredLang: String? = nil, videoFilePath: URL? = nil, limit: String = "500") async throws -> Dictionary<String, [Subtitle]> {
        let params = getParams(episode, imdbId: imdbId, preferredLang: preferredLang, videoFilePath: videoFilePath, limit: limit)
        let path = OpenSubtitles.subtitles
        
        // Use responseMappable with the response wrapper
        let response: SubtitlesResponse = try await client.request(.get, path: path, parameters: params).responseMapable()
        let subtitles = response.data
        
        var allSubtitles = Dictionary<String, [Subtitle]>()
        for subtitle in subtitles {
            let language = subtitle.language
            var languageSubtitles = allSubtitles[language]
            if languageSubtitles == nil {
                languageSubtitles = [Subtitle]()
            }
            languageSubtitles?.append(subtitle)
            allSubtitles[language] = languageSubtitles
        }
        
        return self.removeDuplicates(sourceSubtitles: allSubtitles)
    }
    
    /**
     Download subtitle file using OpenSubtitles API v1 download endpoint
     
     - Parameter fileId: The file ID from subtitle search results
     - Returns: The actual download URL returned by the API
     
     Note: This method requires authentication. For now, it will attempt the download
     with just the API key. Full authentication support needs to be implemented.
     */
    open func downloadSubtitle(fileId: Int) async throws -> String {
        let path = OpenSubtitles.download
        let params = ["file_id": fileId]
        
        // Create a client with proper headers for download requests
        let downloadClient = HttpClient(config: .init(serverURL: OpenSubtitles.base, configuration: {
            let configuration = URLSessionConfiguration.default
            configuration.httpCookieAcceptPolicy = .never
            configuration.httpShouldSetCookies = false
            configuration.timeoutIntervalForResource = 30
            
            // Use authenticated headers if logged in, otherwise default headers
            if let token = self.bearerToken {
                configuration.httpAdditionalHeaders = OpenSubtitles.authenticatedHeaders(with: token)
            } else {
                configuration.httpAdditionalHeaders = OpenSubtitles.defaultHeaders
            }
            
            return configuration
        }()))
        
        // Make POST request to download endpoint
        let link: String = try await downloadClient.request(.post, path: path, parameters: params).responseDecode(keyPath: "link")
        
        return link
    }
    
    /**
     Login to OpenSubtitles API v1
     
     - Parameter username: OpenSubtitles username
     - Parameter password: OpenSubtitles password
     - Returns: Success status
     */
    public func login(username: String, password: String) async throws -> Bool {
        let path = OpenSubtitles.login
        let params = [
            "username": username,
            "password": password
        ]
        
        let token: String = try await client.request(.post, path: path, parameters: params).responseDecode(keyPath: "token")
        
        // Store the bearer token
        self.bearerToken = token
        
        return true
    }
    
    /**
     Logout from OpenSubtitles API v1
     */
    public func logout() async throws {
        guard let token = bearerToken else { return }
        
        let path = OpenSubtitles.logout
        
        // Create authenticated client for logout
        let logoutClient = HttpClient(config: .init(serverURL: OpenSubtitles.base, configuration: {
            let configuration = URLSessionConfiguration.default
            configuration.httpCookieAcceptPolicy = .never
            configuration.httpShouldSetCookies = false
            configuration.timeoutIntervalForResource = 30
            configuration.httpAdditionalHeaders = OpenSubtitles.authenticatedHeaders(with: token)
            return configuration
        }()))
        
        // Clear stored token
        self.bearerToken = nil
        
        // Make logout request
        _ = try await logoutClient.request(.delete, path: path).responseData()
    }
    
    /**
     Remove duplicates from subtitles
     
     - Parameter sourceSubtitles:   The subtitles that may contain duplicate subtitles arranged per language in a Dictionary
     - Returns: A new dictionary with the duplicate subtitles removed
     */
    
    private func removeDuplicates(sourceSubtitles: Dictionary<String, [Subtitle]>) -> Dictionary<String, [Subtitle]> {
        var subtitlesWithoutDuplicates = Dictionary<String, [Subtitle]>()
        
        for (languageName, languageSubtitles) in sourceSubtitles {
            var seenSubtitles = Set<String>()
            var uniqueSubtitles = [Subtitle]()
            for subtitle in languageSubtitles {
                if !seenSubtitles.contains(subtitle.name) {
                    uniqueSubtitles.append(subtitle)
                    seenSubtitles.insert(subtitle.name)
                }
            }
            subtitlesWithoutDuplicates[languageName] = uniqueSubtitles
        }
        
        return subtitlesWithoutDuplicates
    }
    
    private func getParams(_ episode: Episode? = nil, imdbId: String? = nil, preferredLang: String? = nil, videoFilePath: URL? = nil, limit: String = "500") -> [String:Any] {
        var params = [String:Any]()
        
        if let videoFilePath = videoFilePath {
            let videohash = OpenSubtitlesHash.hashFor(videoFilePath)
            params["moviehash"] = videohash.fileHash
            params["moviebytesize"] = videohash.fileSize
        } else if let imdbId = imdbId {
            // Remove 'tt' prefix and leading zeros for API v1
            let cleanId = imdbId.replacingOccurrences(of: "tt", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "0"))
            params["imdb_id"] = cleanId
        } else if let episode = episode {
            params["episode_number"] = String(episode.episode)
            params["query"] = episode.title
            params["season_number"] = String(episode.season)
        }
        
        // Use 'languages' parameter for API v1 (comma-separated)
        if let preferredLang = preferredLang {
            params["languages"] = preferredLang
        } else {
            params["languages"] = "all"
        }
        
        return params
    }
}
