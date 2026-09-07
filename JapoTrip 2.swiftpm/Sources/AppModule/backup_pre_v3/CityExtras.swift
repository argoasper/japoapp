import Foundation

/// Small, hand-picked extras for the home screen tiles: the city's name in
/// Japanese and a representative landscape photo. Kept separate from
/// `data.json` since it's fixed metadata for just the 10 cities/zones,
/// not part of the place-by-place itinerary data.
struct CityExtra {
    let nameJa: String
    let photoURL: URL?
}

enum CityExtras {
    static let byId: [String: CityExtra] = [
        "tokyo": CityExtra(
            nameJa: "東京",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Tokyo_Tower_and_around_Skyscrapers.jpg?width=1200")
        ),
        "kyoto": CityExtra(
            nameJa: "京都",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/FushimiInariTorii.jpg?width=1200")
        ),
        "osaka": CityExtra(
            nameJa: "大阪",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Osaka_Castle_2.jpg?width=1200")
        ),
        "nikko": CityExtra(
            nameJa: "日光",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Nikko_toshogu_shrine.jpg?width=1200")
        ),
        "kamakura": CityExtra(
            nameJa: "鎌倉",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/The_Great_Buddha_of_Kamakura.jpg?width=1200")
        ),
        "hakone": CityExtra(
            nameJa: "箱根",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Mt._Fuji_from_Hakone.jpg?width=1200")
        ),
        "nara": CityExtra(
            nameJa: "奈良",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Nara_deer_lounging_at_Todaiji.jpg?width=1200")
        ),
        "wakayama": CityExtra(
            nameJa: "和歌山",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Wakayama_Castle19nt3200.jpg?width=1200")
        ),
        "hiroshima": CityExtra(
            nameJa: "広島",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/HiroshimaGembakuDome6747.jpg?width=1200")
        ),
        "himeji": CityExtra(
            nameJa: "姫路",
            photoURL: URL(string: "https://commons.wikimedia.org/wiki/Special:FilePath/Himeji_Castle_0804_1.jpg?width=1200")
        ),
    ]

    static func nameJa(for cityId: String) -> String { byId[cityId]?.nameJa ?? "" }
    static func photoURL(for cityId: String) -> URL? { byId[cityId]?.photoURL }
}
