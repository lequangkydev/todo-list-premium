import AppIntents
import SwiftUI
import UserNotifications
import WidgetKit

// MARK: - Data written by the app (Dart `WidgetSnapshot`)

struct Snapshot: Decodable {
    struct Item: Decodable, Identifiable {
        let id: String
        let title: String
        let time: String?
        let p: Int
        let late: Bool
    }

    struct Labels: Decodable {
        let title: String
        let date: String
        let empty: String
        let allDone: String
        let add: String
        let check: String
        let left: [String: String]
        let done: [String: String]
    }

    let open: Int
    let done: Int
    let rtl: Bool
    let items: [Item]
    let l: Labels

    var leftLabel: String { l.left["\(open)"] ?? "" }
    var doneLabel: String { l.done["\(done)"] ?? "" }
}

enum Store {
    static let snapshotKey = "today_snapshot"
    static let pendingKey = "pending_done"

    static var defaults: UserDefaults? {
        let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String
        return UserDefaults(suiteName: group ?? "group.com.vtn.todolist")
    }

    static func load() -> Snapshot? {
        guard let json = defaults?.string(forKey: snapshotKey),
              let data = json.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    /// Ticked on the widget: drop the row now and remember it for the app,
    /// which completes it the next time it runs. Returns its reminders' ids.
    static func markDone(_ id: String) -> [Int] {
        guard let defaults,
              let json = defaults.string(forKey: snapshotKey),
              var root = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let items = root["items"] as? [[String: Any]],
              let item = items.first(where: { $0["id"] as? String == id })
        else { return [] }
        root["items"] = items.filter { $0["id"] as? String != id }
        root["open"] = max(0, (root["open"] as? Int ?? 1) - 1)
        root["done"] = (root["done"] as? Int ?? 0) + 1
        if let data = try? JSONSerialization.data(withJSONObject: root),
           let updated = String(data: data, encoding: .utf8) {
            defaults.set(updated, forKey: snapshotKey)
        }
        var pending = (try? JSONSerialization.jsonObject(
            with: Data((defaults.string(forKey: pendingKey) ?? "[]").utf8)
        ) as? [String]) ?? []
        if !pending.contains(id) { pending.append(id) }
        if let data = try? JSONSerialization.data(withJSONObject: pending) {
            defaults.set(String(data: data, encoding: .utf8), forKey: pendingKey)
        }
        // "nids" since a task can have several reminders; "nid" before that
        if let ids = item["nids"] as? [Int] { return ids }
        return (item["nid"] as? Int).map { [$0] } ?? []
    }
}

// MARK: - Interaction

struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.complete"
    static var isDiscoverable = false

    @Parameter(title: "widget.task") var taskId: String

    init() {}

    init(taskId: String) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        let ids = Store.markDone(taskId)
        if !ids.isEmpty {
            // Its reminders shouldn't ring for a task that's done
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ids.map { "\($0)" })
        }
        return .result()
    }
}

// MARK: - Timeline

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now, snapshot: Store.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        // The app pushes changes; also look again after midnight
        let midnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400 + 60)
        completion(Timeline(entries: [TodayEntry(date: .now, snapshot: Store.load())], policy: .after(midnight)))
    }
}

// MARK: - Colours (the app's tokens, light / dark)

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    static let card = Color(light: 0xFFFFFF, dark: 0x152321)
    static let brand = Color(light: 0x0F766E, dark: 0x5EEAD4)
    static let brandSoft = Color(light: 0xD7F5EE, dark: 0x1B3A36)
    static let ink = Color(light: 0x134E4A, dark: 0xE6F2F0)
    static let muted = Color(light: 0x475569, dark: 0xA3B8B5)
    static let ring = Color(light: 0x64748B, dark: 0x7B918E)

    static func priority(_ p: Int) -> Color {
        switch p {
        case 1: return Color(light: 0x2563EB, dark: 0x60A5FA)
        case 2: return Color(light: 0x92590A, dark: 0xFBBF24)
        case 3: return Color(light: 0xC2410C, dark: 0xFB923C)
        default: return .ring
        }
    }
}

private func link(_ path: String) -> URL {
    URL(string: "todolist://\(path)\(path.contains("?") ? "&" : "?")homeWidget")!
}

// MARK: - Views

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private var maxRows: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 3
        default: return 8
        }
    }

    var body: some View {
        content
            .environment(\.layoutDirection, entry.snapshot?.rtl == true ? .rightToLeft : .leftToRight)
            .widgetURL(link("today"))
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("\(entry.snapshot?.open ?? 0)").font(.title2.weight(.bold))
                    Image(systemName: "checklist").font(.caption2)
                }
            }
            .accessibilityLabel(entry.snapshot?.leftLabel ?? "")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.snapshot?.leftLabel ?? String(localized: "widget.today.name"))
                    .font(.headline)
                    .widgetAccentable()
                ForEach((entry.snapshot?.items ?? []).prefix(2)) { item in
                    Text(item.title).font(.caption).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Text(entry.snapshot?.leftLabel ?? String(localized: "widget.today.name"))
        default:
            list
        }
    }

    private var list: some View {
        let snapshot = entry.snapshot
        let items = Array((snapshot?.items ?? []).prefix(maxRows))
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(snapshot?.l.title ?? String(localized: "widget.today.name"))
                        .font(.headline)
                        .foregroundStyle(Color.brand)
                    if let left = snapshot?.leftLabel, !left.isEmpty {
                        Text(left).font(.caption).foregroundStyle(Color.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                Link(destination: link("quickadd")) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.brand)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.brandSoft))
                }
                .accessibilityLabel(snapshot?.l.add ?? String(localized: "widget.quickadd.name"))
            }
            if items.isEmpty {
                Spacer(minLength: 0)
                Text(emptyText(snapshot))
                    .font(.subheadline)
                    .foregroundStyle(Color.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            } else {
                ForEach(items) { item in row(item, check: snapshot?.l.check ?? "") }
                Spacer(minLength: 0)
            }
        }
    }

    private func emptyText(_ snapshot: Snapshot?) -> String {
        guard let snapshot else { return String(localized: "widget.today.description") }
        return snapshot.done > 0 ? snapshot.l.allDone : snapshot.l.empty
    }

    private func row(_ item: Snapshot.Item, check: String) -> some View {
        HStack(spacing: 8) {
            Button(intent: CompleteTaskIntent(taskId: item.id)) {
                Image(systemName: "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.priority(item.p))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(check): \(item.title)")
            Link(destination: link("task?id=\(item.id)")) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(.subheadline)
                        .foregroundStyle(item.late ? Color.muted : Color.ink)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    if let time = item.time, family != .systemSmall {
                        Text(time).font(.caption).foregroundStyle(Color.muted)
                    }
                }
            }
        }
    }
}

struct QuickAddView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        let label = entry.snapshot?.l.add ?? String(localized: "widget.quickadd.name")
        Group {
            if family == .accessoryCircular {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "plus").font(.title2.weight(.semibold))
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.card)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.brand))
                    Text(label).font(.subheadline.weight(.medium)).foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .accessibilityLabel(label)
        .widgetURL(link("quickadd"))
    }
}

// MARK: - Widgets

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.card }
        }
        .configurationDisplayName(String(localized: "widget.today.name"))
        .description(String(localized: "widget.today.description"))
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

struct QuickAddWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickAddWidget", provider: TodayProvider()) { entry in
            QuickAddView(entry: entry)
                .containerBackground(for: .widget) { Color.card }
        }
        .configurationDisplayName(String(localized: "widget.quickadd.name"))
        .description(String(localized: "widget.quickadd.name"))
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

// MARK: - Lunar calendar

/// One day of the table the app writes (Dart `LunarWidgetSnapshot`): every
/// label already translated. The widget only looks up today's row.
struct LunarDay: Decodable {
    let d: Int
    let w: String
    let m: String
    let l: String
    let f: String?
    let y: String?
}

struct LunarTable: Decodable {
    let title: String
    let days: [String: LunarDay]

    static let key = "lunar_snapshot"

    static func load() -> LunarTable? {
        guard let json = Store.defaults?.string(forKey: key),
              let data = json.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(LunarTable.self, from: data)
    }

    /// `yyyy-MM-dd`, as the app writes its keys
    static func keyFor(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

struct LunarEntry: TimelineEntry {
    let date: Date
    let day: LunarDay?
    let title: String?
}

struct LunarProvider: TimelineProvider {
    private func entry(for date: Date, in table: LunarTable?) -> LunarEntry {
        LunarEntry(date: date, day: table?.days[LunarTable.keyFor(date)], title: table?.title)
    }

    func placeholder(in context: Context) -> LunarEntry {
        LunarEntry(date: .now, day: nil, title: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (LunarEntry) -> Void) {
        completion(entry(for: .now, in: LunarTable.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LunarEntry>) -> Void) {
        // One entry per day for the coming week, each from its midnight, so
        // the date turns over without the app running
        let table = LunarTable.load()
        let today = Calendar.current.startOfDay(for: .now)
        var entries = [entry(for: .now, in: table)]
        for offset in 1...7 {
            if let day = Calendar.current.date(byAdding: .day, value: offset, to: today) {
                entries.append(entry(for: day, in: table))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct LunarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LunarEntry

    private var solarDay: String {
        "\(entry.day?.d ?? Calendar.current.component(.day, from: entry.date))"
    }

    private var fallback: String {
        entry.title ?? String(localized: "widget.lunar.name")
    }

    var body: some View {
        content.widgetURL(link("today"))
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryInline:
            Text(entry.day?.l ?? fallback)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.day?.l ?? fallback)
                    .font(.headline)
                    .widgetAccentable()
                if let extra = entry.day?.f ?? entry.day?.y {
                    Text(extra).font(.caption).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(spacing: 2) {
                if let day = entry.day {
                    Text(day.w).font(.caption).foregroundStyle(Color.muted).lineLimit(1)
                    Text(solarDay)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.brand)
                    Text(day.m).font(.caption).foregroundStyle(Color.muted).lineLimit(1)
                    Text(day.l)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let festival = day.f {
                        Text(festival)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.priority(3))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else if let year = day.y {
                        Text(year).font(.caption2).foregroundStyle(Color.muted).lineLimit(1)
                    }
                } else {
                    // The app hasn't written the table yet: the date, and
                    // what opening the app will add
                    Text(solarDay)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.brand)
                    Text(fallback).font(.caption).foregroundStyle(Color.muted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct LunarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LunarWidget", provider: LunarProvider()) { entry in
            LunarWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.card }
        }
        .configurationDisplayName(String(localized: "widget.lunar.name"))
        .description(String(localized: "widget.lunar.name"))
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct TodoWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        QuickAddWidget()
        LunarWidget()
    }
}
