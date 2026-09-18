import SwiftUI
import UIKit

struct PlaceDetailSheet: View {
    let place: Place
    @EnvironmentObject var store: DataStore
    @StateObject private var reader = SpeechReader()
    @State private var descriptionExpanded = false
    @State private var wikiPhotoURL: URL?
    @State private var wikiArticleURL: URL?
    @State private var photoFromLiveSearch = false
    @State private var mapChoice: MapChoice?
    @Environment(\.dismiss) private var dismiss

    private var isVisited: Bool { store.isVisited(place.id) }
    private var tint: Color { Color(hex: place.cityColor) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Real photo from Wikipedia (or, once pre-downloaded, from
                    // the on-disk cache so it still shows with no
                    // connectivity), shown wide at the top so it's easy to
                    // eyeball whether it's the right spot.
                    if let wikiPhotoURL {
                        AsyncImage(url: wikiPhotoURL, transaction: Transaction(animation: .easeOut(duration: 0.3))) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Color(uiColor: .tertiarySystemGroupedBackground)
                            }
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .overlay(alignment: .bottomTrailing) {
                            if photoFromLiveSearch {
                                Text("Foto trobada per cerca automàtica")
                                    .font(.appCaption2)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(.black.opacity(0.55))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .padding(8)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        badges

                        Text(place.name)
                            .font(.appTitle)

                        if !place.zone.isEmpty {
                            Label(place.zone, systemImage: "mappin.and.ellipse")
                                .font(.appCaption)
                                .foregroundStyle(.secondary)
                        }

                        descriptionBlock

                        Divider()

                        VStack(alignment: .leading, spacing: 14) {
                            if !place.address.isEmpty {
                                InfoRow(icon: "mappin.and.ellipse", label: "Adreça", value: place.address)
                            }
                            if !place.hours.isEmpty {
                                InfoRow(icon: "clock", label: "Horari", value: place.hours)
                            } else {
                                InfoRow(icon: "clock", label: "Horari", value: "No confirmat — comprova'l abans d'anar-hi")
                            }
                            if !place.duration.isEmpty {
                                InfoRow(icon: "hourglass", label: "Durada", value: place.duration)
                            }
                            if !place.notes.isEmpty {
                                InfoRow(icon: "lightbulb", label: "Consell", value: place.notes)
                            }
                        }

                        HStack(spacing: 10) {
                            BigMapButton(kind: .google, urlString: place.google, prominent: true)
                            BigMapButton(kind: .apple, urlString: place.apple, prominent: false)
                        }
                        .padding(.top, 4)

                        Button {
                            mapChoice = MapChoice(title: "Com anar a \(place.name)",
                                                  google: MapLinks.googleDirections(to: place),
                                                  apple: MapLinks.appleDirections(to: place))
                        } label: {
                            Label("Com anar-hi des d'on soc (a peu)", systemImage: "figure.walk")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(tint)

                        if let wikiArticleURL {
                            Link(destination: wikiArticleURL) {
                                Label("Més informació a la Viquipèdia", systemImage: "book.closed")
                            }
                            .font(.appSubheadline)
                        }

                        Button {
                            withAnimation(.snappy) { store.toggleVisited(place.id) }
                        } label: {
                            Label(isVisited ? "Marcat com a vist" : "Marcar com a vist",
                                  systemImage: isVisited ? "checkmark.circle.fill" : "circle")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .tint(isVisited ? .green : .secondary)
                        .padding(.top, 6)
                    }
                    .padding(20)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tanca") {
                        reader.stop()
                        dismiss()
                    }
                }
            }
        }
        .task {
            if let cached = await PhotoCache.shared.cachedLookup(for: place.id) {
                apply(cached)
            } else {
                let lookup = await WikipediaImageFetcher.lookup(wiki: place.wiki, name: place.name, cityName: place.cityName)
                await PhotoCache.shared.store(lookup, for: place.id)
                apply(lookup)
            }
            // Prefer a pre-downloaded local copy (guarantees it shows with no
            // connectivity) over the remote URL, when one exists.
            if let localURL = await PhotoCache.shared.cachedImageURL(for: place.id) {
                wikiPhotoURL = localURL
            }
        }
        .onDisappear { reader.stop() }
        .mapChoiceDialog($mapChoice)
    }

    private func apply(_ lookup: WikipediaImageFetcher.Lookup) {
        wikiPhotoURL = lookup.photoURL
        wikiArticleURL = lookup.articleURL
        photoFromLiveSearch = lookup.fromLiveSearch
    }

    private var badges: some View {
        HStack(spacing: 8) {
            Text("\(place.cityIcon) \(place.cityName)")
                .font(.appCaption)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(tint.opacity(0.16))
                .foregroundStyle(tint)
                .clipShape(Capsule())

            if let meta = store.appData.catMeta[place.cats.first ?? ""] {
                Text("\(meta.icon) \(meta.label)")
                    .font(.appCaption)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .clipShape(Capsule())
            }

            if let label = place.priorityLabel {
                Label(label, systemImage: place.isMustSee ? "star.fill" : "flag.fill")
                    .font(.appCaption)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background((place.isMustSee ? Color.yellow : tint).opacity(0.20))
                    .foregroundStyle(place.isMustSee ? .orange : tint)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var descriptionBlock: some View {
        // The description is the single most valuable piece of content in
        // the app — it's shown by default (a short excerpt, expandable),
        // never hidden behind a tap the way it used to be.
        VStack(alignment: .leading, spacing: 10) {
            Text(place.desc)
                .font(.appBody)
                .lineLimit(descriptionExpanded ? nil : 5)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                if !descriptionExpanded {
                    Button("Llegeix-ne més") {
                        withAnimation(.snappy) { descriptionExpanded = true }
                    }
                    .font(.appSubheadlineBold)
                }
                Button {
                    if reader.isSpeaking { reader.stop() } else { reader.speak(place.desc) }
                } label: {
                    Label(reader.isSpeaking ? "Atura" : "Escolta la descripció",
                          systemImage: reader.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                        .font(.appSubheadline)
                }
                .tint(tint)
            }
        }
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.appCaption).foregroundStyle(.secondary)
                Text(value).font(.appSubheadline)
            }
        }
    }
}

struct BigMapButton: View {
    let kind: MapKind
    let urlString: String?
    var prominent: Bool = false

    var body: some View {
        Button {
            guard let urlString, let url = URL(string: urlString) else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 8) {
                MapBrandIcon(kind: kind, size: 26)
                Text(kind.label)
                    .font(.appSubheadlineBold)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(prominent ? Color.accentColor.opacity(0.12) : Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(urlString == nil)
        .opacity(urlString == nil ? 0.35 : 1)
        .accessibilityLabel("Com anar-hi amb \(kind.label)")
    }
}
