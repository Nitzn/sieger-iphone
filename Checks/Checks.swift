import Foundation

@main
struct Checks {
    static func main() async throws {
        let fixture = Data("""
        {"schema_version":1,"exported_at":"2026-11-11T10:00:00Z","instruments":[
        {"id":"nike","name":"Nike B","currency":"USD","market_symbol":"NKE","mapping_pending":false,
        "news_aliases":["Nike"],"quote":{},"chart":[],"news":[],"uncertain_news":[],"news_source_errors":[]}]}
        """.utf8)
        let snapshot = try SnapshotIO.decode(fixture)
        let item = snapshot.instruments[0]
        assert(item.marketSymbol == "NKE")
        let freshQuote = Quote(price: 123, timestamp: 1_000, changePct: 1, source: "Test", stale: false, fetchedAt: "2026-11-11T10:00:00Z", refreshError: nil)
        let failedQuote = freshQuote.failed("offline")
        assert(failedQuote.price == 123 && failedQuote.timestamp == 1_000 && failedQuote.stale == true && failedQuote.refreshError == "offline")
        assert(LiveResearch.direct("NIKE reports quarterly results",item:item))
        assert(!LiveResearch.direct("Hyatt names new CEO",item:item))
        assert(isOlder("2020-01-01T00:00:00Z",than:900))
        assert(isOlder(nil,than:900))
        let roundtrip = try SnapshotIO.decode(SnapshotIO.encode(snapshot))
        assert(roundtrip.instruments[0].name == "Nike B")
        let rss = Data("""
        <rss><channel><item><title><![CDATA[Nike &amp; quarterly results]]></title><link>https://example.org/a</link>
        <pubDate>Wed, 11 Nov 2026 10:00:00 GMT</pubDate><source>Original publisher</source></item></channel></rss>
        """.utf8)
        let rows = try RSSReader.read(rss,source:"Test")
        assert(rows.count == 1 && rows[0].publisher == "Original publisher" && rows[0].date != nil)
        let empty = try RSSReader.read(Data("<rss><channel/></rss>".utf8),source:"Test")
        assert(empty.isEmpty)
        do { _ = try RSSReader.read(Data("<!DOCTYPE rss><rss><channel/></rss>".utf8),source:"Test"); fatalError("DTD accepted") }
        catch { }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath:file.path,contents:Data())
        defer { try? FileManager.default.removeItem(at:file) }
        let handle=try FileHandle(forWritingTo:file)
        try handle.truncate(atOffset:UInt64(SnapshotIO.maximumBytes+1));try handle.close()
        do { _=try SnapshotIO.readFile(file);fatalError("Oversized import accepted") } catch { }
        print("OK: Snapshotformat, Roundtrip, Newszuordnung, Zeitstempel, RSS und Importgrößenlimit.")
    }
}
