import SwiftUI
import UIKit

extension Color {
    /// Creates a Color from a "#RRGGBB" (or "#RGB") hex string.
    /// Falls back to a neutral gray instead of silently rendering black when
    /// the string isn't a valid color.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, s.allSatisfy({ $0.isHexDigit }) else {
            self.init(uiColor: .systemGray)
            return
        }
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

/// Guarantees Apple's 44x44 pt minimum hit area without changing how big the
/// icon inside actually looks.
struct TapTarget: ViewModifier {
    var size: CGFloat = 44
    func body(content: Content) -> some View {
        content
            .frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
    }
}

extension View {
    func softCard(tint: Color = .primary, cornerRadius: CGFloat = 20) -> some View {
        modifier(SoftCard(tint: tint, cornerRadius: cornerRadius))
    }
    /// Expands the tappable area to at least 44x44 pt (Apple HIG minimum).
    func tapTarget(_ size: CGFloat = 44) -> some View {
        modifier(TapTarget(size: size))
    }
}

// MARK: - Typography
//
// Helvetica Bold is now reserved for titles and emphasis; body copy, captions
// and footnotes use Helvetica regular, so the descriptions (3-5 sentences on
// most places) are actually comfortable to read and the screen has a real
// hierarchy again. `Font.custom(_:size:)` still scales with Dynamic Type.

extension Font {
    /// Helvetica Bold — titles and emphasis.
    static func app(_ size: CGFloat) -> Font { .custom("Helvetica-Bold", size: size) }
    /// Helvetica regular — body copy, captions, everything long-form.
    static func appRegular(_ size: CGFloat) -> Font { .custom("Helvetica", size: size) }
    /// Japanese text: Helvetica has no CJK glyphs, so instead of falling back
    /// silently to a mismatched system face we ask for it explicitly.
    static func appJapanese(_ size: CGFloat) -> Font { .system(size: size, weight: .medium) }

    static var appLargeTitle: Font { .app(34) }
    static var appTitle: Font { .app(28) }
    static var appTitle2: Font { .app(22) }
    static var appTitle3: Font { .app(20) }
    static var appHeadline: Font { .app(17) }

    static var appBody: Font { .appRegular(17) }
    static var appBodyBold: Font { .app(17) }
    static var appSubheadline: Font { .appRegular(15) }
    static var appSubheadlineBold: Font { .app(15) }
    static var appFootnote: Font { .appRegular(13) }
    static var appCaption: Font { .appRegular(12) }
    static var appCaption2: Font { .appRegular(11) }
    static var appCaptionBold: Font { .app(12) }
}

/// Configures UIKit-backed chrome (nav bar titles, segmented control, search
/// field) so the whole app reads consistently.
enum AppAppearance {
    static func configure() {
        if let big = UIFont(name: "Helvetica-Bold", size: 34) {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: big]
        }
        if let small = UIFont(name: "Helvetica-Bold", size: 17) {
            UINavigationBar.appearance().titleTextAttributes = [.font: small]
        }
        if let segFont = UIFont(name: "Helvetica", size: 14) {
            UISegmentedControl.appearance().setTitleTextAttributes([.font: segFont], for: .normal)
        }
        if let segSel = UIFont(name: "Helvetica-Bold", size: 14) {
            UISegmentedControl.appearance().setTitleTextAttributes([.font: segSel], for: .selected)
        }
        if let searchFont = UIFont(name: "Helvetica", size: 17) {
            UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).font = searchFont
        }
    }
}
