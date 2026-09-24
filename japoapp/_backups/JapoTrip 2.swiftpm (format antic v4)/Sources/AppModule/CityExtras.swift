import Foundation
import SwiftUI
import UIKit

/// Small, hand-picked extras for the home screen tiles: the city's name in
/// Japanese and a representative landscape photo. Kept separate from
/// `data.json` since it's fixed metadata for just the 10 cities/zones,
/// not part of the place-by-place itinerary data.
struct CityExtra {
    let nameJa: String
    /// Bundled asset name (e.g. "city-tokyo"), used first so the home screen
    /// and city headers show a real photo even with no connectivity — this
    /// is the very first thing the app shows, and it used to be blank
    /// offline. Falls back to the remote Wikimedia URL when the asset isn't
    /// present in the bundle (e.g. before it's been added in Xcode).
    let localAssetName: String
    let photoURL: URL?
}

enum CityExtras {
    static let byId: [String: CityExtra] = [
        "tokyo": CityExtra(
            nameJa: "東京",
            localAssetName: "city-tokyo",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Tokyo_Tower_and_around_Skyscrapers.jpg?width=1200")
        ),
        "kyoto": CityExtra(
            nameJa: "京都",
            localAssetName: "city-kyoto",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/FushimiInariTorii.jpg?width=1200")
        ),
        "osaka": CityExtra(
            nameJa: "大阪",
            localAssetName: "city-osaka",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Osaka_Castle_2.jpg?width=1200")
        ),
        "nikko": CityExtra(
            nameJa: "日光",
            localAssetName: "city-nikko",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Nikko_toshogu_shrine.jpg?width=1200")
        ),
        "kamakura": CityExtra(
            nameJa: "鎌倉",
            localAssetName: "city-kamakura",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/The_Great_Buddha_of_Kamakura.jpg?width=1200")
        ),
        "hakone": CityExtra(
            nameJa: "箱根",
            localAssetName: "city-hakone",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Mt._Fuji_from_Hakone.jpg?width=1200")
        ),
        "nara": CityExtra(
            nameJa: "奈良",
            localAssetName: "city-nara",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Nara_deer_lounging_at_Todaiji.jpg?width=1200")
        ),
        "wakayama": CityExtra(
            nameJa: "和歌山",
            localAssetName: "city-wakayama",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Wakayama_Castle19nt3200.jpg?width=1200")
        ),
        "hiroshima": CityExtra(
            nameJa: "広島",
            localAssetName: "city-hiroshima",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/HiroshimaGembakuDome6747.jpg?width=1200")
        ),
        "himeji": CityExtra(
            nameJa: "姫路",
            localAssetName: "city-himeji",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Himeji_Castle_0804_1.jpg?width=1200")
        ),
    ]

    static func nameJa(for cityId: String) -> String { byId[cityId]?.nameJa ?? "" }
    static func photoURL(for cityId: String) -> URL? { byId[cityId]?.photoURL }
    static func localAssetName(for cityId: String) -> String? { byId[cityId]?.localAssetName }
}

/// Shows a city's hero photo: the bundled asset when present (works with no
/// connectivity, and is what makes the home screen usable the moment the app
/// launches in Japan), otherwise the remote Wikimedia Commons photo.
struct CityHeroImage: View {
    let cityId: String
    /// The city's own accent color (from `CityInfo.color`), used only for
    /// the gradient placeholder shown before a photo loads or when neither
    /// the bundled asset nor the network is available.
    var tint: Color = Color(hex: "#8C332B")

    private var hasLocalAsset: Bool {
        guard let name = CityExtras.localAssetName(for: cityId) else { return false }
        return UIImage(named: name) != nil
    }

    var body: some View {
        if hasLocalAsset, let name = CityExtras.localAssetName(for: cityId) {
            Image(name)
                .resizable()
                .scaledToFill()
        } else {
            AsyncImage(url: CityExtras.photoURL(for: cityId), transaction: Transaction(animation: .easeOut(duration: 0.3))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    LinearGradient(
                        colors: [tint.opacity(0.55), tint.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                @unknown default:
                    tint.opacity(0.3)
                }
            }
        }
    }
}
