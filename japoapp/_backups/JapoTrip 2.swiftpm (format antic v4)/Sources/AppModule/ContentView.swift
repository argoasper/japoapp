import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var store: DataStore
    @State private var draggingCityId: String?
    @State private var searchText = ""
    @State private var selectedPlace: Place?
    @State private var showProgress = false
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportDocument: BackupDocument?
    @State private var importMessage: String?
    @State private var offlinePrepInProgress = false
    @State private var offlinePrepDone = 0
    @State private var offlinePrepTotal = 0

    private let columns = [GridItem(.adaptive(minimum: 158, maximum: 240), spacing: 16)]

    private var searchResults: [Place] {
        guard !searchText.isEmpty else { return [] }
        let q = SearchText.normalize(searchText)
        return store.allPlaces.filter { SearchText.normalize($0.searchSource).contains(q) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !searchText.isEmpty {
                    searchResultsList
                } else {
                    homeGrid
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .searchable(text: $searchText, prompt: "Cerca un lloc a tot el viatge…")
            .navigationDestination(for: String.self) { cityId in
                CityDetailView(cityId: cityId)
            }
            .navigationDestination(for: CityScreen.self) { screen in
                switch screen {
                case .places(let city, let mode): CityPlacesListView(cityId: city, mode: mode)
                case .routes(let city): CityRoutesView(cityId: city)
                case .transports(let city): TransportsView(cityId: city)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    toolsMenu
                }
            }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailSheet(place: place)
            }
            .sheet(isPresented: $showProgress) {
                ProgressScreen()
            }
            .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json, defaultFilename: "japotrip-progres") { _ in }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert("Importació", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
                Button("D'acord", role: .cancel) { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
        }
    }

    // MARK: - Home grid

    private var homeGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if offlinePrepInProgress {
                    offlinePrepBanner
                        .padding(.horizontal)
                }

                if let error = store.loadError {
                    Text(error)
                        .font(.appSubheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

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
                            .accessibilityLabel("\(info.name), \(store.visitedCount(for: cityId)) de \(store.places(for: cityId).count) llocs visitats")
                            .draggable(cityId) {
                                CityDragPreview(info: info)
                                    .frame(width: 170, height: 60)
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
        // Catch-all: if a city-tile drag is released over empty space
        // (outside every tile's own `.dropDestination`), no per-tile
        // closure ever fires and `draggingCityId` stayed stuck forever,
        // permanently dimming that tile to 40% opacity. This guarantees
        // the flag always resets, wherever the drop lands.
        .dropDestination(for: String.self) { _, _ in
            draggingCityId = nil
            return false
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
            Label("Mantén premuda una caixa i arrossega-la per reordenar-la", systemImage: "hand.draw")
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    // MARK: - Global search results

    private var searchResultsList: some View {
        List {
            if searchResults.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Cap resultat per \"\(searchText)\"")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowSeparator(.hidden)
            } else {
                ForEach(searchResults) { place in
                    Button {
                        selectedPlace = place
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.name)
                                    .font(.appSubheadlineBold)
                                    .foregroundStyle(.primary)
                                Text("\(place.cityIcon) \(place.cityName)" + (store.appData.catMeta[place.cats.first ?? ""].map { " · \($0.label)" } ?? ""))
                                    .font(.appCaption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if store.isVisited(place.id) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Tools menu

    private var toolsMenu: some View {
        Menu {
            Button {
                showProgress = true
            } label: {
                Label("Progrés del viatge", systemImage: "chart.bar.fill")
            }
            Button {
                startOfflinePrep()
            } label: {
                Label("Prepara per sense connexió", systemImage: "arrow.down.circle")
            }
            .disabled(offlinePrepInProgress)
            Divider()
            Button {
                exportDocument = store.exportBackupData().map(BackupDocument.init)
                showExporter = true
            } label: {
                Label("Exporta el progrés (còpia de seguretat)", systemImage: "square.and.arrow.up")
            }
            Button {
                showImporter = true
            } label: {
                Label("Importa el progrés", systemImage: "square.and.arrow.down")
            }
            Divider()
            Button {
                withAnimation(.snappy) { store.resetCityOrder() }
            } label: {
                Label("Restaura l'ordre de les ciutats", systemImage: "arrow.counterclockwise")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var offlinePrepBanner: some View {
        HStack(spacing: 10) {
            ProgressView(value: offlinePrepTotal == 0 ? 0 : Double(offlinePrepDone) / Double(offlinePrepTotal))
            Text("\(offlinePrepDone)/\(offlinePrepTotal)")
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func startOfflinePrep() {
        guard !offlinePrepInProgress else { return }
        offlinePrepInProgress = true
        offlinePrepDone = 0
        offlinePrepTotal = store.allPlaces.count
        let places = store.allPlaces
        Task {
            await OfflinePreparer.prepare(places: places) { progress in
                Task { @MainActor in
                    offlinePrepDone = progress.done
                    offlinePrepTotal = progress.total
                }
            }
            await MainActor.run { offlinePrepInProgress = false }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure:
            importMessage = "No s'ha pogut llegir el fitxer."
        case .success(let url):
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                importMessage = "No s'ha pogut llegir el fitxer."
                return
            }
            let count = store.importBackupData(data)
            importMessage = count > 0
                ? "S'han afegit \(count) llocs visitats nous des de la còpia."
                : "El fitxer no tenia cap lloc nou per afegir."
        }
    }
}

/// Lightweight stand-in shown while dragging a city tile: just the color and
/// name, no photo. The real `CityTile` used to be reused here, which forced
/// a second, redundant network fetch of the same 1200px photo on every drag.
struct CityDragPreview: View {
    let info: CityInfo

    var body: some View {
        HStack(spacing: 8) {
            Text(info.icon)
            Text(info.name).font(.appSubheadlineBold)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(hex: info.color))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct CityTile: View {
    let info: CityInfo
    let total: Int
    let visited: Int

    private var progress: Double { total == 0 ? 0 : Double(visited) / Double(total) }
    private var nameJa: String { CityExtras.nameJa(for: info.id) }
    private var tint: Color { Color(hex: info.color) }

    @ScaledMetric(relativeTo: .title2) private var tileHeight: CGFloat = 172

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                CityHeroImage(cityId: info.id, tint: tint)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .opacity(0.88)

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
                            .font(.appJapanese(13))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.bottom, 10)
                    }

                    ProgressBar(progress: progress, tint: .white)
                        .frame(height: 6)
                }
                .padding(16)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
        }
        .frame(minHeight: tileHeight)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}
