import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store

    @State private var step = 0
    @State private var selectedDaily: Set<GoalDraft> = Set(Self.dailyTemplates.prefix(5))
    @State private var challengeTitle = String(localized: "Change my life")
    @State private var challengeDays = 90

    private let lastStep = 4

    static var dailyTemplates: [GoalDraft] {
        [
            GoalDraft(title: String(localized: "Workout"), note: String(localized: "At least 45 minutes"), activity: .fitness),
            GoalDraft(title: String(localized: "Drink water"), note: String(localized: "2 liters"), activity: .hydration, targetValue: 2, unit: "L"),
            GoalDraft(title: String(localized: "Read"), note: String(localized: "At least 20 minutes"), activity: .reading, targetValue: 20, unit: "min"),
            GoalDraft(title: String(localized: "Meditate"), note: String(localized: "At least 10 minutes"), activity: .meditation, targetValue: 10, unit: "min"),
            GoalDraft(title: String(localized: "Walk 10k steps"), note: String(localized: "Move every day"), activity: .mindfulness),
            GoalDraft(title: String(localized: "Journal"), note: String(localized: "Three grateful things"), activity: .journal),
            GoalDraft(title: String(localized: "Sleep early"), note: String(localized: "Before 23:30"), activity: .sleep),
            GoalDraft(title: String(localized: "Eat clean"), note: String(localized: "No junk food"), activity: .nutrition),
        ]
    }

    var body: some View {
        ZStack {
            AppBackground()

            TabView(selection: $step) {
                WelcomeScreen().tag(0)
                HeatmapScreen().tag(1)
                PrivacyScreen().tag(2)
                HabitsScreen(templates: Self.dailyTemplates, selection: $selectedDaily).tag(3)
                PlanScreen(title: $challengeTitle, days: $challengeDays).tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.snappy, value: step)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        Haptics.tap()
                        store.skipOnboarding()
                    } label: {
                        Text("Skip")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifeGridTheme.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Skip onboarding"))
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)

                Spacer()
                controls
            }
            .zIndex(1)
        }
        .preferredColorScheme(.dark)
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 7) {
                ForEach(0 ... lastStep, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? store.accent : Color.white.opacity(0.18))
                        .frame(width: index == step ? 22 : 7, height: 7)
                        .animation(.snappy, value: step)
                }
            }

            HStack(spacing: 12) {
                if step > 0 {
                    Button {
                        Haptics.tap()
                        withAnimation(.snappy) { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(Circle().stroke(LifeGridTheme.stroke, lineWidth: 1))
                            )
                    }
                    .buttonStyle(PressableScale())
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .accessibilityLabel(Text("Back"))
                }

                Button {
                    Haptics.tap()
                    if step < lastStep {
                        withAnimation(.snappy) { step += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(step < lastStep ? "Continue" : "Start")
                            .font(.headline.weight(.bold))
                        Image(systemName: step < lastStep ? "arrow.right" : "checkmark")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [store.accent, store.accent.opacity(0.82)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    )
                    .overlay(
                        Capsule().stroke(.white.opacity(0.18), lineWidth: 0.8)
                    )
                    .shadow(color: store.accent.opacity(0.45), radius: 16, y: 7)
                }
                .buttonStyle(PressableScale())
            }
            .animation(.snappy, value: step)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
    }

    private func finish() {
        store.completeOnboarding(
            dailyDrafts: Array(selectedDaily),
            onceDrafts: [],
            planTitle: challengeTitle,
            planSubtitle: String(localized: "\(challengeDays)-day challenge"),
            planDays: challengeDays
        )
    }
}

// MARK: - Screens

private struct WelcomeScreen: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Image("AppLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 136, height: 136)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: LifeGridTheme.green.opacity(0.35), radius: 30, y: 12)
                .scaleEffect(appear ? 1 : 0.82)
                .opacity(appear ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appear)
            VStack(spacing: 12) {
                Text("LifeGrid")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                Text("Build better days, one square at a time.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LifeGridTheme.secondary)
                    .padding(.horizontal, 30)
            }
            Spacer()
            Spacer()
        }
        .onAppear { appear = true }
    }
}

private struct HeatmapScreen: View {
    var body: some View {
        OnboardingScaffold(
            icon: "square.grid.3x3.fill",
            title: "See your momentum",
            message: "Every habit you check off fills a square. Watch your streaks grow like a contribution graph."
        ) {
            AnimatedHeatmapHero(compact: true)
        }
    }
}

private struct PrivacyScreen: View {
    var body: some View {
        OnboardingScaffold(
            icon: "lock.shield.fill",
            title: "Private by design",
            message: "No account, no cloud, no tracking. Everything you log stays on this device — always."
        ) {
            EmptyView()
        }
    }
}

private struct HabitsScreen: View {
    @Environment(AppStore.self) private var store
    var templates: [GoalDraft]
    @Binding var selection: Set<GoalDraft>

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pick your daily habits")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("Choose the things you want to check off every day. You can change these any time.")
                    .font(.body)
                    .foregroundStyle(LifeGridTheme.secondary)
                HStack {
                    Text("\(selection.count) selected")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifeGridTheme.green)
                        .contentTransition(.numericText())
                    Spacer()
                    Button {
                        Haptics.soft()
                        if selection.count == templates.count {
                            selection.removeAll()
                        } else {
                            selection = Set(templates)
                        }
                    } label: {
                        Text(selection.count == templates.count ? "Clear" : "Select all")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(store.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 22)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(templates, id: \.self) { draft in
                        let isSelected = selection.contains(draft)
                        Button {
                            Haptics.soft()
                            if isSelected { selection.remove(draft) } else { selection.insert(draft) }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: LifeGridTheme.fieldRadius, style: .continuous)
                                        .fill(isSelected ? LifeGridTheme.green.opacity(0.16) : LifeGridTheme.field)
                                    Image(systemName: draft.activity.symbol)
                                        .foregroundStyle(isSelected ? LifeGridTheme.green : LifeGridTheme.secondary)
                                }
                                .frame(width: 44, height: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(draft.title).font(.headline).foregroundStyle(.white)
                                    Text(draft.note).font(.caption).foregroundStyle(LifeGridTheme.secondary)
                                }
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(isSelected ? LifeGridTheme.green : LifeGridTheme.muted)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: LifeGridTheme.rowRadius, style: .continuous)
                                    .fill(isSelected ? LifeGridTheme.green.opacity(0.08) : Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: LifeGridTheme.rowRadius, style: .continuous)
                                    .stroke(isSelected ? LifeGridTheme.green.opacity(0.7) : LifeGridTheme.stroke)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 140)
            }
        }
        .padding(.top, 70)
    }
}

private struct PlanScreen: View {
    @Environment(AppStore.self) private var store
    @Binding var title: String
    @Binding var days: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Name your challenge")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("Set one focused goal to anchor your habits. The classic is 90 days.")
                    .font(.body)
                    .foregroundStyle(LifeGridTheme.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Goal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifeGridTheme.secondary)
                TextField(String(localized: "Change my life"), text: $title)
                    .padding(14)
                    .background(LifeGridTheme.field, in: RoundedRectangle(cornerRadius: LifeGridTheme.fieldRadius, style: .continuous))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 10) {
                ForEach([30, 60, 90], id: \.self) { value in
                    Button {
                        Haptics.soft()
                        days = value
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(value)").font(.title2.weight(.bold))
                            Text("days").font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(OnboardingTileStyle(isSelected: days == value, tint: store.accent))
                }
            }

            Stepper(value: $days, in: 7 ... 365, step: 1) {
                HStack {
                    Text("Length").foregroundStyle(.white)
                    Spacer()
                    Text("\(days) days").foregroundStyle(store.accent)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 70)
        .padding(.bottom, 120)
    }
}

// MARK: - Shared building blocks

private struct OnboardingScaffold<Accessory: View>: View {
    var icon: String
    var title: LocalizedStringKey
    var message: LocalizedStringKey
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            accessory()
            Image(systemName: icon)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(LifeGridTheme.green)
            VStack(spacing: 12) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text(message)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LifeGridTheme.secondary)
            }
            .padding(.horizontal, 30)
            Spacer()
            Spacer()
        }
    }
}

private struct AnimatedHeatmapHero: View {
    var compact = false
    @State private var on = false

    private var rows: Int { compact ? 6 : 7 }
    private var cols: Int { compact ? 14 : 11 }
    private var size: CGFloat { compact ? 16 : 20 }

    var body: some View {
        VStack(spacing: 5) {
            ForEach(0 ..< rows, id: \.self) { r in
                HStack(spacing: 5) {
                    ForEach(0 ..< cols, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(color(level: (r * 5 + c * 3) % 4))
                            .frame(width: size, height: size)
                            .opacity(on ? 1 : 0.06)
                            .animation(.easeOut(duration: 0.5).delay(Double(r + c) * 0.04), value: on)
                    }
                }
            }
        }
        .onAppear { on = true }
    }

    private func color(level: Int) -> Color {
        switch level {
        case 0: Color.white.opacity(0.08)
        case 1: LifeGridTheme.green.opacity(0.35)
        case 2: LifeGridTheme.green.opacity(0.62)
        default: LifeGridTheme.green
        }
    }
}

/// Subtle press-down scale used by the onboarding call-to-action buttons.
struct PressableScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct OnboardingTileStyle: ButtonStyle {
    var isSelected: Bool
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(isSelected ? tint.opacity(0.16) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: LifeGridTheme.fieldRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LifeGridTheme.fieldRadius, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.82) : LifeGridTheme.stroke)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
