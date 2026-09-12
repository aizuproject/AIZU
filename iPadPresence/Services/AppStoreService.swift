import Foundation

struct StoreApp: Decodable, Identifiable, Sendable {
    let trackId: Int64
    let trackName: String
    let artistName: String?
    let artworkUrl512: URL?
    let artworkUrl100: URL?
    let trackViewUrl: URL?
    var id: Int64 { trackId }
    func application(country: String) -> PresenceApp {
        PresenceApp(name: trackName, developer: artistName ?? "App Store", appStoreID: trackId,
             storefront: country, artworkURL: artworkUrl512 ?? artworkUrl100, storeURL: trackViewUrl, details: L("앱 사용 중"))
    }
}

actor AppStoreService {
    static let shared = AppStoreService()
    private struct Response: Decodable { let results: [StoreApp] }
    private var cache: [String: (Date, [StoreApp])] = [:]

    func search(_ query: String, country: String) async throws -> [StoreApp] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        let key = country + ":" + term.lowercased()
        if let cached = cache[key], cached.0.timeIntervalSinceNow > -3600 { return cached.1 }
        var url = URLComponents(string: "https://itunes.apple.com/search")!
        url.queryItems = [URLQueryItem(name: "term", value: term), URLQueryItem(name: "country", value: country),
                          URLQueryItem(name: "entity", value: "software"), URLQueryItem(name: "limit", value: "20")]
        if let match = term.firstMatch(of: /id([0-9]+)/) {
            url.path = "/lookup"
            url.queryItems = [URLQueryItem(name: "id", value: String(match.1)), URLQueryItem(name: "country", value: country)]
        }
        var request = URLRequest(url: url.url!, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw PresenceFailure.message("App Store 검색을 불러오지 못했습니다. 잠시 후 다시 시도하거나 직접 등록해 주세요.")
        }
        let results = try JSONDecoder().decode(Response.self, from: data).results
        if cache.count > 40 { cache.removeAll() }
        cache[key] = (.now, results)
        return results
    }
}
