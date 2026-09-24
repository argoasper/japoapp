import SwiftUI
import UIKit

struct PlaceDetailSheet: View {
    let place: Place
    @EnvironmentObject var store: DataStore
    @StateObject private var reader = SpeechReader()
    @State private var showDescription = false
    @State private var wikiPhotoURL: URL?
    @State private var wikiArticleURL: URL?
    @Environment(\.dismiss) private var dismiss

    private var isVisited: Bool { store.isVisited(place.id) }
    private var tint: Color { Color(hex: place.cityColor) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Real photo from Wikipedia, shown wide at the top so
                    // it's easy to eyeball whether it's the right spot. Uses
                    // the curated wiki link when there is one, otherwise a
                    // live search by name (most places, e.g. all of Osaka
                    // and Kyoto, have no curated link). Only appears once
                    // (if) something is actually found.
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
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        badges

                        Text(place.name)
                            .font(.appTitle)

                        if !place.day.isEmpty {
                            Text(place.day)
                                .font(.appSubheadline)
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
                            }
                            if !place.duration.isEmpty {
                                InfoRow(icon: "hourglass", label: "Durada", value: place.duration)
                            }
                            if !place.notes.isEmpty {
                                InfoRow(icon: "lightbulb", label: "Consell", value: place.notes)
                            }
                        }

                        HStack(spacing: 10) {
                            BigMapButton(kind: .apple, urlString: place.apple)
                            BigMapButton(kind: .google, urlString: place.google)
                        }
                        .padding(.top, 4)

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
            let lookup = await WikipediaImageFetcher.lookup(wiki: place.wiki, name: place.name, cityName: place.cityName)
            wikiPhotoURL = lookup.photoURL
            wikiArticleURL = lookup.articleURL
        }
        .onDisappear { reader.stop() }
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

            if place.priority == "alta" {
                Label("Imprescindible", systemImage: "star.fill")
                    .font(.appCaption)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.22))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var descriptionBlock: some View {
        if showDescription {
            VStack(alignment: .leading, spacing: 10) {
                Text(place.desc)
                    .font(.appBody)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                Button {
                    if reader.isSpeaking { reader.stop() } else { reader.speak(place.desc) }
                } label: {
                    Label(reader.isSpeaking ? "Atura la lectura" : "Torna a llegir en veu alta",
                          systemImage: reader.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .tint(tint)
            }
        } else {
            Button {
                withAnimation(.snappy) { showDescription = true }
                reader.speak(place.desc)
            } label: {
                Label("Llegir la descripció", systemImage: "text.book.closed.fill")
                    .font(.appSubheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
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

    var body: some View {
        Button {
            guard let urlString, let url = URL(string: urlString) else { return }
            UIApplication.shared.open(url)
        } label: {
            MapBrandIcon(kind: kind, size: 40)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(urlString == nil)
        .opacity(urlString == nil ? 0.35 : 1)
        .accessibilityLabel(kind.label)
    }
}
