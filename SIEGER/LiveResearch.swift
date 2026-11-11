import Foundation
import CryptoKit

enum LiveResearch {
    static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
    static func direct(_ title: String, item: Instrument) -> Bool {
        if item.mappingPending { return false }
        let aliases: [String]
        if let configured = item.newsAliases, !configured.isEmpty { aliases = configured }
        else {
            // Old snapshots without explicit aliases stay conservative for ambiguous names.
            switch normalized(item.name) {
            case "snap": aliases = ["snap inc", "snapchat", "snap shares", "snap stock", "snap aktie"]
            case "sino": aliases = ["sino ag", "sino aktie", "sino shares", "sino stock"]
            case "porsche ag vz": aliases = ["porsche ag"]
            case "porsche se": aliases = ["porsche se", "porsche automobil holding"]
            default: aliases = [item.name]
            }
        }
        let headline = " " + normalized(title) + " "
        return aliases.contains { let name = normalized($0); return name.count >= 3 && headline.contains(" " + name + " ") }
    }
    static func url(_ base: String, query: [URLQueryItem]) throws -> URL {
        guard var parts = URLComponents(string: base) else { throw ResearchError.message("Ungültige Datenadresse.") }
        parts.queryItems = query
        guard let value = parts.url else { throw ResearchError.message("Ungültige Datenadresse.") }
        return value
    }
    static func quotes(_ items: [Instrument]) async throws -> [String: Quote] {
        let expected = Dictionary(items.compactMap { item -> (String, Instrument)? in
            guard !item.mappingPending, let symbol=item.marketSymbol else { return nil }
            return (symbol.uppercased(),item)
        }, uniquingKeysWith: { first, _ in first })
        let address = try url("https://query2.finance.yahoo.com/v7/finance/spark", query: [
            URLQueryItem(name:"symbols",value:expected.keys.sorted().joined(separator:",")),
            URLQueryItem(name:"range",value:"1d"),URLQueryItem(name:"interval",value:"1m")])
        let data = try await PublicHTTP.get(address)
        guard let root=try JSONSerialization.jsonObject(with:data) as? [String:Any],
              let spark=root["spark"] as? [String:Any],let results=spark["result"] as? [[String:Any]] else {
            throw ResearchError.message("Gebündelter Kursabruf fehlgeschlagen.")
        }
        var output: [String:Quote] = [:]
        for result in results {
            guard let symbol=(result["symbol"] as? String)?.uppercased(),let item=expected[symbol],
                  let response=(result["response"] as? [[String:Any]])?.first,
                  let meta=response["meta"] as? [String:Any],(meta["symbol"] as? String)?.uppercased()==symbol,
                  let currency=meta["currency"] as? String else { continue }
            let factor: Double
            if currency=="GBp" && item.currency=="GBP" { factor=0.01 }
            else if currency==item.currency { factor=1 }
            else { continue }
            var price=(meta["regularMarketPrice"] as? NSNumber)?.doubleValue
            var stamp=(meta["regularMarketTime"] as? NSNumber)?.doubleValue
            if let timestamps=response["timestamp"] as? [Double],let indicators=response["indicators"] as? [String:Any],
               let values=(indicators["quote"] as? [[String:Any]])?.first?["close"] as? [Any] {
                for index in timestamps.indices.reversed() where index<values.count {
                    if let value=values[index] as? NSNumber,value.doubleValue.isFinite,value.doubleValue>0 {
                        price=value.doubleValue;stamp=timestamps[index];break
                    }
                }
            }
            guard let price,price.isFinite,price>0,let stamp else { continue }
            let previous=(meta["chartPreviousClose"] as? NSNumber)?.doubleValue ?? (meta["previousClose"] as? NSNumber)?.doubleValue
            let change=previous.flatMap { $0>0 ? (price/$0-1)*100 : nil }
            let quote=Quote(price:price*factor,timestamp:stamp,changePct:change,source:"Yahoo Finance (inoffiziell)",stale:false,
                fetchedAt:ISO8601DateFormatter().string(from:Date()),refreshError:nil)
            for match in items where match.marketSymbol?.uppercased()==symbol && match.currency==item.currency { output[match.id]=quote }
        }
        return output
    }
    static func market(_ item: Instrument) async throws -> (Quote, [Bar]) {
        guard !item.mappingPending, let symbol = item.marketSymbol,
              symbol.range(of: "^[A-Za-z0-9.^=_-]{1,32}$", options: .regularExpression) != nil else {
            throw ResearchError.message("Kurssymbol oder Wertpapierzuordnung noch offen.")
        }
        let address = try url("https://query2.finance.yahoo.com/v8/finance/chart/" + symbol,
            query: [URLQueryItem(name: "period1", value: "-2208988800"),
                    URLQueryItem(name: "period2", value: String(Int(Date().timeIntervalSince1970))),
                    URLQueryItem(name: "interval", value: "1d"), URLQueryItem(name: "includePrePost", value: "false")])
        let data = try await PublicHTTP.get(address)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = root["chart"] as? [String: Any],
              let result = (chart["result"] as? [[String: Any]])?.first,
              let meta = result["meta"] as? [String: Any],
              (meta["symbol"] as? String)?.uppercased() == symbol.uppercased(),
              let currency = meta["currency"] as? String,
              let timestamps = result["timestamp"] as? [Double],
              let indicators = result["indicators"] as? [String: Any],
              let raw = (indicators["quote"] as? [[String: Any]])?.first?["close"] as? [Any] else {
            throw ResearchError.message("Keine eindeutig zugeordneten Tageskurse erhalten.")
        }
        if let interval = meta["dataGranularity"] as? String, interval != "1d" {
            throw ResearchError.message("Anbieter lieferte keine Tagesdaten.")
        }
        let factor: Double
        if currency == "GBp" && item.currency == "GBP" { factor = 0.01 }
        else if currency == item.currency { factor = 1 }
        else { throw ResearchError.message("Kurswährung passt nicht zur Watchlist; keine automatische Umrechnung.") }
        let adjusted = (indicators["adjclose"] as? [[String: Any]])?.first?["adjclose"] as? [Any]
        let timezone = TimeZone(identifier: meta["exchangeTimezoneName"] as? String ?? "UTC") ?? TimeZone(secondsFromGMT: (meta["gmtoffset"] as? Int) ?? 0)!
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        var values: [(String, Double)] = []
        for (index, stamp) in timestamps.enumerated() where index < raw.count {
            let day = formatter.string(from: Date(timeIntervalSince1970: stamp))
            guard day < today, let close = raw[index] as? NSNumber else { continue }
            var value = close.doubleValue
            if let adjusted, index < adjusted.count, let number = adjusted[index] as? NSNumber { value = number.doubleValue }
            value *= factor
            guard value.isFinite, value > 0 else { continue }
            guard values.last?.0 != day else { continue }
            values.append((day, value))
        }
        guard !values.isEmpty else { throw ResearchError.message("Keine abgeschlossenen Tageskerzen verfügbar.") }
        var bars: [Bar] = []
        for index in max(0, values.count-260)..<values.count {
            func average(_ length: Int) -> Double? {
                guard index+1 >= length else { return nil }
                return values[(index-length+1)...index].reduce(0) { $0+$1.1 } / Double(length)
            }
            bars.append(Bar(date: values[index].0, close: values[index].1, gd20: average(20), gd50: average(50), gd200: average(200)))
        }
        guard let price = (meta["regularMarketPrice"] as? NSNumber)?.doubleValue,
              price.isFinite, price > 0, let timestamp = (meta["regularMarketTime"] as? NSNumber)?.doubleValue else {
            throw ResearchError.message("Aktueller Kurs oder Kurszeit fehlt.")
        }
        // previousClose is used only when explicitly provided for the prior trading day.
        let previous = (meta["previousClose"] as? NSNumber)?.doubleValue
        let change = previous.flatMap { $0 > 0 ? (price/$0-1)*100 : nil }
        return (Quote(price: price*factor, timestamp: timestamp, changePct: change, source: "Yahoo Finance (inoffiziell)", stale: false,
                      fetchedAt: ISO8601DateFormatter().string(from: Date()), refreshError: nil), bars)
    }
    static func news(_ item: Instrument) async throws -> ([NewsArticle], [NewsArticle], [String]) {
        var rows: [NewsArticle] = [], warnings: [String] = []
        var successes = 0
        if let symbol = item.marketSymbol, !item.mappingPending {
            do {
                let address = try url("https://feeds.finance.yahoo.com/rss/2.0/headline", query: [URLQueryItem(name: "s", value: symbol), URLQueryItem(name: "region", value: "US"), URLQueryItem(name: "lang", value: "en-US")])
                rows = try RSSReader.read(await PublicHTTP.get(address, maximum: 2_000_000), source: "Yahoo Finance RSS")
                successes += 1
            } catch { warnings.append("Yahoo Finance RSS: " + error.localizedDescription) }
        }
        if !rows.contains(where: { direct($0.title, item: item) }) {
            do {
                let query = "\"" + item.name.replacingOccurrences(of: "\"", with: "") + "\" (Aktie OR Aktien OR Börse OR stock OR earnings)"
                let address = try url("https://news.google.com/rss/search", query: [URLQueryItem(name: "q", value: query), URLQueryItem(name: "hl", value: "de"), URLQueryItem(name: "gl", value: "DE"), URLQueryItem(name: "ceid", value: "DE:de")])
                rows += try RSSReader.read(await PublicHTTP.get(address, maximum: 2_000_000), source: "Google News RSS – Namenssuche")
                successes += 1
            } catch { warnings.append("Google News RSS: " + error.localizedDescription) }
        }
        guard successes > 0 else { throw ResearchError.message(warnings.joined(separator: "; ")) }
        var seen: Set<String> = []
        let unique = rows.filter { seen.insert($0.id).inserted }
        return (unique.filter { direct($0.title, item: item) }, unique.filter { !direct($0.title, item: item) }, warnings)
    }
}

final class RSSReader: NSObject, XMLParserDelegate {
    var rows: [NewsArticle] = []
    var fields: [String: String] = [:]
    var element = ""
    var inside = false
    var hasRSS = false
    var hasChannel = false
    var source = ""
    static func read(_ data: Data, source: String) throws -> [NewsArticle] {
        let upper = String(decoding: data, as: UTF8.self).uppercased()
        guard !upper.contains("<!DOCTYPE"), !upper.contains("<!ENTITY") else { throw ResearchError.message("Nicht unterstütztes RSS-Format.") }
        let reader = RSSReader(); reader.source = source
        let parser = XMLParser(data: data); parser.delegate = reader; parser.shouldResolveExternalEntities = false
        guard parser.parse(), reader.hasRSS, reader.hasChannel else { throw ResearchError.message("Ungültiger Nachrichtenfeed.") }
        return Array(reader.rows.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }.prefix(150))
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "rss" { hasRSS = true }
        if elementName == "channel" { hasChannel = true }
        if elementName == "item" { inside = true; fields = [:] }
        element = elementName
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if inside { fields[element, default: ""] += string } }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) { if inside { fields[element, default: ""] += String(decoding: CDATABlock, as: UTF8.self) } }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard elementName == "item" else { return }
        inside = false
        let title = fields["title", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        let url = fields["link", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let link = URL(string: url), ["https", "http"].contains(link.scheme?.lowercased() ?? ""), link.host != nil else { return }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let date = formatter.date(from: fields["pubDate", default: ""])
        let identity = SHA256.hash(data: Data((url + "|" + title).utf8)).prefix(10).map { String(format: "%02x", $0) }.joined()
        rows.append(NewsArticle(id: identity, title: title, url: url, publisher: fields["source"] ?? source,
            publishedAt: date.map { ISO8601DateFormatter().string(from: $0) }, attribution: nil, attributionReason: nil))
    }
}
