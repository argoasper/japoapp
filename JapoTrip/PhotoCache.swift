import Foundation

/// A small on-disk cache so a place's Wikipedia photo/article lookup only
/// ever has to hit the network once, and so the user can explicitly
/// pre-download everything before losing connectivity (the itinerary is
/// meant to be used inside Japan, often offline).
///
/// Two layers:
/// - `lookupCache`: the resolved photo/article URLs per place id (cheap,
///   always saved once resolved).
/// - image bytes on disk per place id, saved only when the user taps
///   "Prepara per sense connexió" — that's what makes a photo actually show
///   up with airplane mode on, since HTTP cache headers alone can't be
///   relied on for that.
actor PhotoCache {
    static let shared = PhotoCache()

    struct CachedLookup: Codable {
        let photoURLString: String?
        let articleURLString: String?
        let fromLiveSearch: Bool
    }

    private var lookups: [String: CachedLookup] = [:]
    private let lookupsFileURL: URL
    private let imagesDirURL: URL
    private var didLoad = false

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("JapoTripPhotoCache", isDirectory: true)
        lookupsFileURL = dir.appendingPathComponent("lookups.json")
        imagesDirURL = dir.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDirURL, withIntermediateDirectories: true)
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if let data = try? Data(contentsOf: lookupsFileURL),
           let decoded = try? JSONDecoder().decode([String: CachedLookup].self, from: data) {
            lookups = decoded
        }
    }

    private func persistLookups() {
        guard let data = try? JSONEncoder().encode(lookups) else { return }
        try? data.write(to: lookupsFileURL, options: .atomic)
    }

    // MARK: - Lookups (URLs only)

    func cachedLookup(for placeId: String) -> WikipediaImageFetcher.Lookup? {
        loadIfNeeded()
        guard let entry = lookups[placeId] else { return nil }
        return WikipediaImageFetcher.Lookup(
            photoURL: entry.photoURLString.flatMap(URL.init(string:)),
            articleURL: entry.articleURLString.flatMap(URL.init(string:)),
            fromLiveSearch: entry.fromLiveSearch
        )
    }

    func store(_ lookup: WikipediaImageFetcher.Lookup, for placeId: String) {
        loadIfNeeded()
        lookups[placeId] = CachedLookup(
            photoURLString: lookup.photoURL?.absoluteString,
            articleURLString: lookup.articleURL?.absoluteString,
            fromLiveSearch: lookup.fromLiveSearch
        )
        persistLookups()
    }

    // MARK: - Image bytes (only populated by explicit pre-download)

    private func imageFileURL(for placeId: String) -> URL {
        imagesDirURL.appendingPathComponent(placeId.replacingOccurrences(of: "/", with: "_"))
    }

    /// A local file:// URL for this place's photo, if it was pre-downloaded.
    func cachedImageURL(for placeId: String) -> URL? {
        let url = imageFileURL(for: placeId)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func storeImageData(_ data: Data, for placeId: String) {
        try? data.write(to: imageFileURL(for: placeId), options: .atomic)
    }

    /// How many of the given places already have a pre-downloaded photo on disk.
    func downloadedCount(of placeIds: [String]) -> Int {
        placeIds.reduce(0) { $0 + (cachedImageURL(for: $1) != nil ? 1 : 0) }
    }
}

/// Walks the whole itinerary once, resolving and saving each place's photo so
/// the app has something to show with no connectivity. Used by the
/// "Prepara per sense connexió" button on the home screen.
enum OfflinePreparer {
    struct Progress {
        var done: Int
        var total: Int
    }

    static func prepare(places: [Place], onProgress: @escaping @Sendable (Progress) -> Void) async {
        let total = places.count
        var done = 0
        // A handful at a time — enough to be fast, not so many that we hammer
        // Wikipedia's API or the device radio.
        let chunkSize = 5
        var index = 0
        while index < places.count {
            let chunk = Array(places[index..<min(index + chunkSize, places.count)])
            await withTaskGroup(of: Void.self) { group in
                for place in chunk {
                    group.addTask {
                        await prepareOne(place)
                    }
                }
            }
            index += chunkSize
            done += chunk.count
            onProgress(Progress(done: done, total: total))
        }
    }

    private static func prepareOne(_ place: Place) async {
        let cached = await PhotoCache.shared.cachedLookup(for: place.id)
        let lookup: WikipediaImageFetcher.Lookup
        if let cached {
            lookup = cached
        } else {
            lookup = await WikipediaImageFetcher.lookup(wiki: place.wiki, name: place.name, cityName: place.cityName)
            await PhotoCache.shared.store(lookup, for: place.id)
        }
        guard let photoURL = lookup.photoURL else { return }
        if await PhotoCache.shared.cachedImageURL(for: place.id) != nil { return }
        guard let (data, _) = try? await URLSession.shared.data(from: photoURL) else { return }
        await PhotoCache.shared.storeImageData(data, for: place.id)
    }
}
