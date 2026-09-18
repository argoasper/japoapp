import Foundation

/// Finds a real photo — and, when needed, a real article link — for a place
/// straight from Wikipedia, using only public MediaWiki endpoints (no API
/// key, works from any device with internet access).
///
/// Only about half the places in the itinerary come with a curated Wikipedia
/// link (`Place.wiki`). So this doesn't just resolve the curated link:
/// whenever there's no link, or the curated link doesn't yield a photo, it
/// falls back to searching Wikipedia live by the place's name (and, if that
/// finds nothing, by name + city). Live-search candidates are checked
/// against the article's own coordinates before being accepted, so a generic
/// name (e.g. "Parc Maruyama") can't silently show the photo of an unrelated
/// place somewhere else in the world.
enum WikipediaImageFetcher {
    struct Lookup {
        let photoURL: URL?
        let articleURL: URL?
        /// True when this result came from an unverified live search rather
        /// than the curated `wiki` link — the UI shows a small "cerca
        /// automàtica" hint in that case.
        let fromLiveSearch: Bool
    }

    private static let userAgent = "JapoTrip-iOS/1.0 (viatge personal, sense API key)"
    private static let requestTimeout: TimeInterval = 6

    // Japan's bounding box, generously padded (covers Okinawa to the Kurils
    // in latitude terms; longitude covers the whole archipelago). Used to
    // reject a live-search match that's clearly the wrong place.
    private static let japanLatRange = 24.0...46.0
    private static let japanLngRange = 122.0...146.5

    /// Main entry point: resolves the best photo + article link for a place.
    /// - `wiki`: the curated Wikipedia URL from the data, if any.
    /// - `name` / `cityName`: used as a live search fallback.
    static func lookup(wiki: String?, name: String, cityName: String) async -> Lookup {
        var photo: URL?
        var article: URL? = wiki.flatMap(URL.init(string:))

        if let wiki, let fromCurated = await summary(forPageURL: wiki) {
            photo = fromCurated.photoURL
            if article == nil { article = fromCurated.articleURL }
        }

        if photo != nil && article != nil {
            return Lookup(photoURL: photo, articleURL: article, fromLiveSearch: false)
        }

        if let found = await search(name: name, cityHint: cityName) {
            photo = photo ?? found.photoURL
            article = article ?? found.articleURL
        }

        return Lookup(photoURL: photo, articleURL: article, fromLiveSearch: wiki == nil)
    }

    // MARK: - Curated link → page summary (has full-resolution "originalimage")

    private struct Summary: Decodable {
        struct ImageInfo: Decodable { let source: String }
        let originalimage: ImageInfo?
        let thumbnail: ImageInfo?
    }

    /// Extracts (language, page title) from a wikipedia.org URL such as
    /// "https://en.wikipedia.org/wiki/Fushimi_Inari-taisha".
    private static func pageInfo(from wikiURLString: String) -> (lang: String, title: String)? {
        guard let url = URL(string: wikiURLString), let host = url.host else { return nil }
        let lang = host.split(separator: ".").first.map(String.init) ?? "en"
        // `lastPathComponent` can hand back the title still percent-encoded
        // (e.g. "Sens%C5%8D-ji"). Decode it first so `summary(forPageURL:)`
        // re-encodes it exactly once — otherwise accented titles could get
        // double-encoded and the API call would 404.
        let rawTitle = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        guard !rawTitle.isEmpty else { return nil }
        return (lang, rawTitle)
    }

    private static func summary(forPageURL wikiURLString: String) async -> Lookup? {
        guard let info = pageInfo(from: wikiURLString),
              let encodedTitle = info.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let apiURL = URL(string: "https://\(info.lang).wikipedia.org/api/rest_v1/page/summary/\(encodedTitle)") else {
            return nil
        }
        var request = URLRequest(url: apiURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = requestTimeout
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(Summary.self, from: data)
            let photo = (decoded.originalimage ?? decoded.thumbnail).flatMap { URL(string: $0.source) }
            return Lookup(photoURL: photo, articleURL: URL(string: wikiURLString), fromLiveSearch: false)
        } catch {
            return nil
        }
    }

    // MARK: - Live name search (used when there's no curated link, or it has no photo)

    private struct SearchResponse: Decodable {
        struct Page: Decodable {
            struct Thumbnail: Decodable { let url: String }
            let key: String
            let thumbnail: Thumbnail?
        }
        let pages: [Page]
    }

    private static func search(name: String, cityHint: String) async -> Lookup? {
        // Prefer whichever query actually yields a *validated* photo — a
        // bare-name search can match an unrelated page with no image or in
        // the wrong country, and we'd wrongly settle for that instead of
        // trying the city-qualified query, which is usually the right one.
        if let first = await searchOnce(query: name), first.photoURL != nil { return first }
        if let second = await searchOnce(query: "\(name) \(cityHint)"), second.photoURL != nil { return second }
        // Neither query found a *photo*, but a validated article link (even
        // without a photo) is still better than nothing.
        let first = await searchOnce(query: name)
        if first?.articleURL != nil { return first }
        return await searchOnce(query: "\(name) \(cityHint)")
    }

    /// Requests up to 5 candidates (not just the top hit) and returns the
    /// first one whose own coordinates place it inside Japan. Rejects a
    /// candidate with no coordinates at all, rather than trusting a bare name
    /// match blindly.
    private static func searchOnce(query: String) async -> Lookup? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://en.wikipedia.org/w/rest.php/v1/search/page?q=\(encoded)&limit=5") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = requestTimeout
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
            for page in decoded.pages.prefix(5) {
                guard await isInJapan(pageKey: page.key) else { continue }
                let article = URL(string: "https://en.wikipedia.org/wiki/\(page.key)")
                let photo = page.thumbnail.flatMap { widenThumbnail($0.url) }
                return Lookup(photoURL: photo, articleURL: article, fromLiveSearch: true)
            }
            return nil
        } catch {
            return nil
        }
    }

    /// Looks up a page's own coordinates via the classic MediaWiki action API
    /// (the REST search endpoint doesn't return coordinates) and checks them
    /// against Japan's bounding box.
    private static func isInJapan(pageKey: String) async -> Bool {
        struct CoordResponse: Decodable {
            struct Query: Decodable { let pages: [String: Page] }
            struct Page: Decodable { let coordinates: [Coord]? }
            struct Coord: Decodable { let lat: Double; let lon: Double }
            let query: Query
        }
        guard let encoded = pageKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://en.wikipedia.org/w/api.php?action=query&prop=coordinates&titles=\(encoded)&format=json") else {
            return true // can't check — don't block on a network hiccup, the name match is still our best guess
        }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = requestTimeout
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(CoordResponse.self, from: data)
            guard let coord = decoded.query.pages.values.first?.coordinates?.first else {
                // No coordinates on the article at all (common for a shopping
                // street, a shrine sub-building, etc.) — allow it rather than
                // discarding a perfectly good match for lack of a lat/lng.
                return true
            }
            return japanLatRange.contains(coord.lat) && japanLngRange.contains(coord.lon)
        } catch {
            return true
        }
    }

    /// Wikipedia thumbnail URLs encode the requested width in the path
    /// (".../thumb/a/ab/File.jpg/220px-File.jpg"); the search endpoint only
    /// offers a small one, so bump it to a wide size for the detail banner.
    private static func widenThumbnail(_ urlString: String, to width: Int = 1200) -> URL? {
        var s = urlString.hasPrefix("//") ? "https:" + urlString : urlString
        if let regex = try? NSRegularExpression(pattern: #"/\d+px-"#) {
            let range = NSRange(s.startIndex..., in: s)
            if let match = regex.matches(in: s, range: range).last {
                s = (s as NSString).replacingCharacters(in: match.range, with: "/\(width)px-")
            }
        }
        return URL(string: s)
    }
}
