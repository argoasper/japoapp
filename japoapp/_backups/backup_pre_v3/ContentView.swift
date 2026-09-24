import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var store: DataStore
    @State private var draggingCityId: String?

    private let columns = [GridItem(.adaptive(minimum: 158, maximum: 240), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.cityOrder, id: \.self) { cityId in
                            if let info = store.cityInfo(cityId) {
                                NavigationLink(value: cityId) {
                                    CityTile(
                                        info: info,
                                        total: store.places(for: cityId).count,
                                        visited: store.visitedCount(for: cityId)
                                    )
                                }
                                .buttonStyle(.plain)
                                .opacity(draggingCityId == cityId ? 0.4 : 1)
                                .draggable(cityId) {
                                    CityTile(
                                        info: info,
                                        total: store.places(for: cityId).count,
                                        visited: store.visitedCount(for: cityId)
                                    )
                                    .frame(width: 170)
                                    .onAppear { draggingCityId = cityId }
                                }
                                .dropDestination(for: String.self) { items, _ in
                                    defer { draggingCityId = nil }
                                    guard let dragged = items.first, dragged != cityId,
                                          let from = store.cityOrder.firstIndex(of: dragged),
                                          let to = store.cityOrder.firstIndex(of: cityId) else { return false }
                                    withAnimation(.snappy) { store.moveCity(from: from, to: to) }
                                    return true
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            // Catch-all: if a city-tile drag is released over empty space
            // (outside every tile's own `.dropDestination`), no per-tile
            // closure ever fires and `draggingCityId` stayed stuck forever,
            // permanently dimming that tile to 40% opacity. This guarantees
            // the flag always resets, wherever the drop lands.
            .dropDestination(for: String.self) { _, _ in
                draggingCityId = nil
                return false
            }
            .navigationDestination(for: String.self) { cityId in
                CityDetailView(cityId: cityId)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("⛩️ Japó 2026")
                .font(.appLargeTitle)
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.appSubheadline)
                Text("\(store.totalVisited) de \(store.totalPlaces) llocs visitats")
                    .font(.appSubheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Mantén premuda una caixa i arrossega-la per reordenar-la")
                .font(.appCaption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }
}

struct CityTile: View {
    let info: CityInfo
    let total: Int
    let visited: Int

    private var tint: Color { Color(hex: info.color) }
    private var progress: Double { total == 0 ? 0 : Double(visited) / Double(total) }
    private var nameJa: String { CityExtras.nameJa(for: info.id) }
    private var photoURL: URL? { CityExtras.photoURL(for: info.id) }

    private let tileHeight: CGFloat = 172

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Background photo, dimmed with a scrim so the name reads
                // well over it regardless of how bright the photo is.
                AsyncImage(url: photoURL, transaction: Transaction(animation: .easeOut(duration: 0.3))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .opacity(0.88)
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
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                // Dark scrim: lighter at the top, stronger toward the bottom
                // where the name sits, so the photo stays visible but the
                // text is always legible.
                LinearGradient(
                    colors: [.black.opacity(0.10), .black.opacity(0.32), .black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)

                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 14)

                    Text(info.name)
                        .font(.app(26))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    if !nameJa.isEmpty {
                        Text(nameJa)
                            .font(.appFootnote)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.bottom, 10)
                    }

                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(.white).frame(width: max(0, geo.size.width - 32) * progress)
                    }
                    .frame(height: 6)
                }
                .padding(16)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
        }
        .frame(height: tileHeight)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}
