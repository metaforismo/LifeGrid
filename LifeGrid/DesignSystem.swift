import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Theme tokens

enum LifeGridTheme {
    // Surfaces
    static let background = Color(red: 0.01, green: 0.01, blue: 0.012)
    static let elevatedBackground = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let cardFill = Color.white.opacity(0.05)
    static let panel = Color.white.opacity(0.07)
    static let panelStrong = Color.white.opacity(0.115)
    static let field = Color.white.opacity(0.06)
    static let stroke = Color.white.opacity(0.10)

    // Text
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.66)
    static let muted = Color.white.opacity(0.36)

    // Accents (tuned to the mockup)
    static let green = Color(red: 0.45, green: 0.93, blue: 0.43)
    static let purple = Color(red: 0.68, green: 0.42, blue: 1.0)
    static let violetSoft = Color(red: 0.48, green: 0.31, blue: 0.78)
    static let successSurface = Color(red: 0.18, green: 0.35, blue: 0.20)
    static let violetSurface = Color(red: 0.20, green: 0.13, blue: 0.30)

    // Radii
    static let cardRadius: CGFloat = 22
    static let rowRadius: CGFloat = 16
    static let fieldRadius: CGFloat = 14

    /// Gradient used by the headline 90-day plan card.
    static let planGradient = LinearGradient(
        colors: [
            Color(red: 0.22, green: 0.12, blue: 0.34),
            Color(red: 0.12, green: 0.08, blue: 0.20),
            Color(red: 0.05, green: 0.04, blue: 0.08),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Accent-tinted version of the plan-card gradient.
    static func planGradient(_ accent: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(0.32),
                accent.opacity(0.12),
                Color(red: 0.05, green: 0.04, blue: 0.08),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum LGSpacing {
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 22
}

// MARK: - Haptics

@MainActor
enum Haptics {
    /// Toggled from Settings; when false all feedback is suppressed.
    static var enabled = true

    static func success() {
        guard enabled else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func tap() {
        guard enabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func soft() {
        guard enabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
}

// MARK: - Panels & glass

struct PanelModifier: ViewModifier {
    var radius: CGFloat = LifeGridTheme.cardRadius
    var interactive = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(LifeGridTheme.cardFill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(LifeGridTheme.stroke, lineWidth: 0.7)
                )
                .glassEffect(
                    .regular.tint(Color.white.opacity(0.04)).interactive(interactive),
                    in: .rect(cornerRadius: radius)
                )
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(LifeGridTheme.stroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}

extension View {
    func lifePanel(radius: CGFloat = LifeGridTheme.cardRadius, interactive: Bool = false) -> some View {
        modifier(PanelModifier(radius: radius, interactive: interactive))
    }

    func liquidGlassButton(prominent: Bool = false) -> some View {
        modifier(LiquidGlassButtonModifier(prominent: prominent))
    }
}

struct LiquidGlassButtonModifier: ViewModifier {
    var prominent: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            if prominent {
                content.buttonStyle(.borderedProminent)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Background

struct AppBackground: View {
    var body: some View {
        ZStack {
            LifeGridTheme.background
            LinearGradient(
                colors: [
                    Color.white.opacity(0.035),
                    Color.clear,
                    LifeGridTheme.violetSoft.opacity(0.08),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Reusable components

struct CircularProgressView: View {
    var progress: Double
    var tint: Color
    var lineWidth: CGFloat = 8
    var showsLabel = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy, value: progress)
            if showsLabel {
                Text("\(Int(progress * 100))%")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Progress \(Int(progress * 100)) percent"))
    }
}

/// Capsule filter chip used in Stats and Goals.
struct Chip: View {
    var title: String
    var systemImage: String?
    var isSelected: Bool
    var tint: Color

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(isSelected ? .black : LifeGridTheme.secondary)
        .background(isSelected ? tint : LifeGridTheme.panel, in: Capsule())
    }
}

struct EmptyStateView: View {
    @Environment(AppStore.self) private var store
    var symbol: String
    var title: LocalizedStringKey
    var message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(LifeGridTheme.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(LifeGridTheme.primary)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(LifeGridTheme.secondary)
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .liquidGlassButton(prominent: true)
                .tint(store.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .lifePanel()
    }
}

struct SectionHeader: View {
    var title: LocalizedStringKey
    var trailing: String?
    var tint: Color = LifeGridTheme.primary

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
        .padding(.horizontal, LGSpacing.l)
        .accessibilityElement(children: .combine)
    }
}
