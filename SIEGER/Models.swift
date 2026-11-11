import Foundation

struct Snapshot: Codable {
    let schemaVersion: Int
    var exportedAt: String
    var instruments: [Instrument]
}

struct Instrument: Codable, Identifiable {
    let id: String
    let name: String
    let currency: String
    let marketSymbol: String?
    let mappingPending: Bool
    let newsAliases: [String]?
    var quote: Quote
    var chart: [Bar]
    var historyFetchedAt: String?
    var historyStale: Bool?
    var historyError: String?
    var news: [NewsArticle]
    var uncertainNews: [NewsArticle]
    var newsFetchedAt: String?
    var newsStale: Bool?
    var newsError: String?
    var newsSourceErrors: [String]
}

struct Quote: Codable {
    let price: Double?
    let timestamp: Double?
    let changePct: Double?
    let source: String?
    let stale: Bool?
    let fetchedAt: String?
    let refreshError: String?
    func failed(_ message: String) -> Quote {
        Quote(price: price, timestamp: timestamp, changePct: changePct, source: source, stale: true,
              fetchedAt: fetchedAt, refreshError: message)
    }
}

struct Bar: Codable, Identifiable {
    var id: String { date }
    let date: String
    let close: Double
    let gd20: Double?
    let gd50: Double?
    let gd200: Double?
}

struct NewsArticle: Codable, Identifiable {
    let id: String
    let title: String
    let url: String
    let publisher: String?
    let publishedAt: String?
    let attribution: String?
    let attributionReason: String?
    var date: Date? { parseDate(publishedAt) }
    var link: URL? {
        guard let value = URL(string: url), ["https", "http"].contains(value.scheme?.lowercased() ?? ""), value.host != nil else { return nil }
        return value
    }
}

func isOlder(_ stamp: String?, than interval: TimeInterval, now: Date = Date()) -> Bool {
    guard let date = parseDate(stamp) else { return true }
    return date > now.addingTimeInterval(60) || now.timeIntervalSince(date) > interval
}

func parseDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
}
