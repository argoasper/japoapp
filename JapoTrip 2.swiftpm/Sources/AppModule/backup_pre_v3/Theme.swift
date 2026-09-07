import SwiftUI
import UIKit

extension Color {
    /// Creates a Color from a "#RRGGBB" hex string.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/// Shared, soft/pastel card styling helpers so every screen feels consistent.
struct SoftCard: ViewModifier {
    var tint: Color = .primary
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.12), lineWidth: 1)
            )
    }
}

extension View {
    func softCard(tint: Color = .primary, cornerRadius: CGFloat = 20) -> some View {
        modifier(SoftCard(tint: tint, cornerRadius: cornerRadius))
    }
}

// MARK: - Typography (prova: Helvetica Bold)

extension Font {
    /// Helvetica Bold at an arbitrary size — the app's default text style.
    /// (Prova temporal: abans era Helvetica Light — canviar "Helvetica-Bold"
    /// per "Helvetica-Light" aquí per tornar enrere.)
    static func app(_ size: CGFloat) -> Font { .custom("Helvetica-Bold", size: size) }
    /// Helvetica (regular) — usada només en algun detall petit on tot en negreta
    /// resultaria massa carregat.
    static func appRegular(_ size: CGFloat) -> Font { .custom("Helvetica", size: size) }

    static var appLargeTitle: Font { .app(34) }
    static var appTitle: Font { .app(28) }
    static var appTitle2: Font { .app(22) }
    static var appTitle3: Font { .app(20) }
    static var appHeadline: Font { .app(17) }
    static var appBody: Font { .app(17) }
    static var appSubheadline: Font { .app(15) }
    static var appFootnote: Font { .app(13) }
    static var appCaption: Font { .app(12) }
    static var appCaption2: Font { .app(11) }
}

/// Configures UIKit-backed chrome (nav bar titles, segmented control, search
/// field) to use Helvetica Light too, so the whole app — not just SwiftUI
/// Text views — reads consistently.
enum AppAppearance {
    static func configure() {
        if let big = UIFont(name: "Helvetica-Bold", size: 34) {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: big]
        }
        if let small = UIFont(name: "Helvetica-Bold", size: 17) {
            UINavigationBar.appearance().titleTextAttributes = [.font: small]
        }
        if let segFont = UIFont(name: "Helvetica-Bold", size: 14) {
            UISegmentedControl.appearance().setTitleTextAttributes([.font: segFont], for: .normal)
        }
        if let searchFont = UIFont(name: "Helvetica-Bold", size: 17) {
            UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).font = searchFont
        }
    }
}
