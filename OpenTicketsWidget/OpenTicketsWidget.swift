import WidgetKit
import SwiftUI
import Foundation

// MARK: - Entry
struct OpenTicketsEntry: TimelineEntry {
    let date: Date
    let openCount: Int
    let lastUpdated: Date?
}

// MARK: - Provider
struct OpenTicketsProvider: TimelineProvider {
    private enum Keys {
        static let lastCount = "OpenTicketsWidget.lastCount"
        static let lastUpdated = "OpenTicketsWidget.lastUpdated"
        static let apiBase = "APIClient.baseURL"
        static let apiKey = "APIClient.apiKey"
    }

    func placeholder(in context: Context) -> OpenTicketsEntry {
        OpenTicketsEntry(date: Date(), openCount: 3, lastUpdated: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (OpenTicketsEntry) -> Void) {
        fetchOpenCount { count, updated in
            completion(OpenTicketsEntry(date: Date(), openCount: count, lastUpdated: updated))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OpenTicketsEntry>) -> Void) {
        fetchOpenCount { count, updated in
            let entry = OpenTicketsEntry(date: Date(), openCount: count, lastUpdated: updated)
            // Refresh every 15 minutes; the app will also trigger reloads on changes.
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
            let timeline = Timeline(entries: [entry], policy: .after(next))
            completion(timeline)
        }
    }

    // MARK: Networking
    private func fetchOpenCount(completion: @escaping (Int, Date?) -> Void) {
        let suite = UserDefaults(suiteName: SharedAppConstants.appGroupSuite) ?? .standard

        // Keys mirror APIClient.Defaults
        let baseURLString = suite.string(forKey: Keys.apiBase) ?? "https://tracker.turnernet.co"
        let apiKey = suite.string(forKey: Keys.apiKey)

        guard let baseURL = URL(string: baseURLString), baseURL.scheme == "https" else {
            completion(self.cachedCount(from: suite), self.cachedDate(from: suite))
            return
        }

        let path = baseURL.appendingPathComponent("api/v1/tickets")
        var req = URLRequest(url: path)
        req.httpMethod = "GET"
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 10
        if let apiKey, !apiKey.isEmpty {
            req.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        URLSession.shared.dataTask(with: req) { data, response, error in
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode)
            else {
                completion(self.cachedCount(from: suite), self.cachedDate(from: suite))
                return
            }

            let count = self.countOpenTickets(data: data)
            if let count {
                suite.set(count, forKey: Keys.lastCount)
                suite.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdated)
                completion(count, Date())
            } else {
                completion(self.cachedCount(from: suite), self.cachedDate(from: suite))
            }
        }.resume()
    }

    private func countOpenTickets(data: Data?) -> Int? {
        guard let data else { return nil }
        // Accept either a raw array of ticket objects or an envelope with an `items` array.
        if let arr = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
            return countOpen(in: arr)
        }
        if let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let items = dict["items"] as? [[String: Any]] {
            return countOpen(in: items)
        }
        return nil
    }

    private func countOpen(in items: [[String: Any]]) -> Int {
        items.reduce(0) { acc, item in
            let done = isCompletedValue(item["completed"])
            return acc + (done ? 0 : 1)
        }
    }

    private func isCompletedValue(_ value: Any?) -> Bool {
        guard let value else { return false }
        if let b = value as? Bool { return b }
        if let i = value as? Int { return i != 0 }
        if let s = value as? String {
            let lower = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let intVal = Int(lower) { return intVal != 0 }
            return lower == "true" || lower == "yes"
        }
        return false
    }

    private func cachedCount(from suite: UserDefaults) -> Int {
        suite.integer(forKey: Keys.lastCount)
    }

    private func cachedDate(from suite: UserDefaults) -> Date? {
        let ts = suite.double(forKey: Keys.lastUpdated)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }
}

// MARK: - View
struct OpenTicketsWidgetEntryView: View {
    var entry: OpenTicketsProvider.Entry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(.background)
            VStack(alignment: .leading, spacing: 6) {
                Text("Open Tickets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(entry.openCount)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                    Spacer()
                }
                if let updated = entry.lastUpdated {
                    Text("Updated " + updated.formatted(date: .omitted, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        // Deep link into the app; ensure the app handles this URL if you want custom behavior
        .widgetURL(URL(string: "vipdashboard://tickets"))
    }
}

// MARK: - Widget
struct OpenTicketsWidget: Widget {
    let kind: String = SharedAppConstants.openTicketsWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OpenTicketsProvider()) { entry in
            OpenTicketsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Open Tickets")
        .description("Shows the number of open tickets and keeps it up to date.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

#Preview(as: .systemSmall) {
    OpenTicketsWidget()
} timeline: {
    OpenTicketsEntry(date: .now, openCount: 3, lastUpdated: .now)
}
