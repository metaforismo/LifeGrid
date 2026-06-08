import SwiftUI
import WidgetKit

// MARK: - Timeline

struct LifeGridEntry: TimelineEntry {
    let date: Date
    let summary: TodaySummary
}

struct LifeGridProvider: TimelineProvider {
    func placeholder(in context: Context) -> LifeGridEntry {
        LifeGridEntry(date: .now, summary: .make(from: nil))
    }

    func getSnapshot(in context: Context, completion: @escaping (LifeGridEntry) -> Void) {
        completion(LifeGridEntry(date: .now, summary: .make(from: SharedStore.loadSnapshot())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LifeGridEntry>) -> Void) {
        let entry = LifeGridEntry(date: .now, summary: .make(from: SharedStore.loadSnapshot()))
        // Refresh hourly so the widget reflects the latest check-ins.
        let next = Calendar.autoupdatingCurrent.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

private let widgetGreen = Color(red: 0.45, green: 0.93, blue: 0.43)

struct LifeGridWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: LifeGridEntry

    var body: some View {
        Group {
            if family == .systemSmall {
                smallBody
            } else {
                mediumBody
            }
        }
        .containerBackground(for: .widget) {
            Color(red: 0.02, green: 0.02, blue: 0.03)
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer()
            HStack {
                Spacer()
                ring(size: 92)
                Spacer()
            }
            Spacer()
        }
    }

    private var mediumBody: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer()
                Text(progressText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            ring(size: 78)
                .frame(width: 78)
            heatmap
        }
    }

    // MARK: pieces

    private var header: some View {
        Text("LifeGrid")
            .font(.caption.weight(.bold))
            .foregroundStyle(entry.summary.accent.color)
    }

    private var progressText: String {
        entry.summary.total == 0 ? "No habits today" : "\(entry.summary.completed) of \(entry.summary.total) done"
    }

    private func ring(size: CGFloat) -> some View {
        ZStack {
            Circle().stroke(entry.summary.accent.color.opacity(0.2), lineWidth: 9)
            Circle()
                .trim(from: 0, to: max(0.001, entry.summary.fraction))
                .stroke(entry.summary.accent.color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(entry.summary.completed)/\(entry.summary.total)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
    }

    private var heatmap: some View {
        let counts = entry.summary.heatCounts
        let columns = stride(from: 0, to: counts.count, by: 7).map {
            Array(counts[$0 ..< min($0 + 7, counts.count)])
        }
        return HStack(spacing: 3) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                VStack(spacing: 3) {
                    ForEach(Array(column.enumerated()), id: \.offset) { _, count in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(color(for: count))
                            .frame(width: 11, height: 11)
                    }
                }
            }
        }
    }

    private func color(for count: Int) -> Color {
        switch count {
        case 0: Color.white.opacity(0.08)
        case 1: widgetGreen.opacity(0.35)
        case 2: widgetGreen.opacity(0.62)
        default: widgetGreen
        }
    }
}

// MARK: - Widget

struct LifeGridWidget: Widget {
    let kind = "LifeGridWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LifeGridProvider()) { entry in
            LifeGridWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Your habit progress for today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct LifeGridWidgetBundle: WidgetBundle {
    var body: some Widget {
        LifeGridWidget()
    }
}
