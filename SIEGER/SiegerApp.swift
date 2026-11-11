import SwiftUI
import Charts
import UniformTypeIdentifiers

@MainActor
final class ResearchStore: ObservableObject {
    @Published var snapshot: Snapshot?
    @Published var error: String?
    @Published var loading = false
    @Published var updating: Set<String> = []
    @Published var endpoint = UserDefaults.standard.string(forKey: "snapshotURL") ?? ""
    private let cache = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("research.json")

    init() {
        if FileManager.default.fileExists(atPath: cache.path) {
            do { snapshot = try SnapshotIO.decode(SnapshotIO.readFile(cache)) } catch { self.error = "Gespeicherte Daten konnten nicht gelesen werden." }
        } else if let bootstrap = Bundle.main.url(forResource: "Bootstrap", withExtension: "json") {
            do { snapshot = try SnapshotIO.decode(SnapshotIO.readFile(bootstrap)) } catch { self.error = "Startdaten konnten nicht gelesen werden." }
        }
    }
    func accept(_ data: Data) throws {
        let value = try SnapshotIO.decode(data)
        try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: cache, options: [.atomic, .completeFileProtection])
        snapshot = value
        error = nil
    }
    func importFile(_ url: URL) {
        guard !loading, updating.isEmpty else { error="Bitte den laufenden Abruf vor dem Import abwarten."; return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do { try accept(SnapshotIO.readFile(url)) } catch { self.error = error.localizedDescription }
    }
    func refreshInstrument(_ identity: String) async {
        guard !loading, !updating.contains(identity), let original = snapshot?.instruments.first(where: { $0.id == identity }) else { return }
        updating.insert(identity)
        defer { updating.remove(identity) }
        var updated = original
        var errors: [String] = []
        if !original.mappingPending {
            do {
                let (quote, bars) = try await LiveResearch.market(original)
                updated.quote = quote; updated.chart = bars
                updated.historyFetchedAt = ISO8601DateFormatter().string(from: Date())
                updated.historyStale = false; updated.historyError = nil
            } catch {
                updated.historyStale = true; updated.historyError = error.localizedDescription
                updated.quote = original.quote.failed(error.localizedDescription)
                errors.append(error.localizedDescription)
            }
        }
        do {
            let (direct, uncertain, warnings) = try await LiveResearch.news(original)
            updated.news = direct; updated.uncertainNews = uncertain; updated.newsSourceErrors = warnings
            updated.newsFetchedAt = ISO8601DateFormatter().string(from: Date())
            updated.newsStale = false; updated.newsError = nil
        } catch {
            updated.newsStale = true; updated.newsError = error.localizedDescription
            errors.append(error.localizedDescription)
        }
        guard var current = snapshot, let index = current.instruments.firstIndex(where: {
            $0.id == identity && $0.name == original.name && $0.marketSymbol == original.marketSymbol && $0.currency == original.currency
        }) else { return }
        current.instruments[index] = updated
        current.exportedAt = ISO8601DateFormatter().string(from: Date())
        do { try accept(SnapshotIO.encode(current)); if !errors.isEmpty { self.error = errors.joined(separator: " · ") } }
        catch { self.error = error.localizedDescription }
    }
    func refreshWatchlist() async {
        guard !loading, updating.isEmpty, let initial=snapshot else { return }
        loading=true
        defer { loading=false }
        let ready=initial.instruments.filter { !$0.mappingPending && $0.marketSymbol != nil }
        var failures: [String] = []
        for offset in stride(from:0,to:ready.count,by:20) {
            let batch=Array(ready[offset..<min(offset+20,ready.count)])
            var values: [String:Quote] = [:]
            var failure: String?
            do { values=try await LiveResearch.quotes(batch) }
            catch { failure=error.localizedDescription;failures.append(error.localizedDescription) }
            guard var current=snapshot else { return }
            for original in batch {
                guard let index=current.instruments.firstIndex(where: { $0.id==original.id && $0.marketSymbol==original.marketSymbol && $0.currency==original.currency }) else { continue }
                current.instruments[index].quote=values[original.id] ?? current.instruments[index].quote.failed(failure ?? "Keine aktuelle Kursantwort für diesen Wert.")
            }
            current.exportedAt=ISO8601DateFormatter().string(from:Date())
            do { try accept(SnapshotIO.encode(current)) } catch { self.error=error.localizedDescription;return }
        }
        if !failures.isEmpty { error=failures.joined(separator:" · ") }
    }
    func refresh() async {
        guard !loading, updating.isEmpty else { return }
        guard let url = URL(string: endpoint), url.scheme?.lowercased() == "https", url.host != nil, url.user == nil, url.password == nil else {
            error = "Bitte eine HTTPS-Adresse für die freigegebenen Recherchedaten eintragen oder eine Datei importieren."
            return
        }
        loading = true
        defer { loading = false }
        do {
            try accept(await PublicHTTP.get(url))
            UserDefaults.standard.set(url.absoluteString, forKey: "snapshotURL")
        } catch { self.error = "Aktualisierung fehlgeschlagen. Vorhandene Daten bleiben erhalten. " + error.localizedDescription }
    }
}

enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

@main
struct SiegerApp: App {
    @StateObject private var store = ResearchStore()
    var body: some Scene {
        WindowGroup { WatchlistView().environmentObject(store).tint(Color(red: 0.59, green: 0.44, blue: 0.18)) }
    }
}

struct WatchlistView: View {
    @EnvironmentObject private var store: ResearchStore
    @State private var search = ""
    @State private var importing = false
    @State private var settings = false
    var instruments: [Instrument] {
        (store.snapshot?.instruments ?? []).filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationStack {
            List {
                if let error = store.error { Section { Text(error).foregroundStyle(.red) } }
                if let snapshot = store.snapshot {
                    Section {
                        Text("Datenstand gespeichert: \(parseDate(snapshot.exportedAt)?.formatted(date: .abbreviated, time: .shortened) ?? snapshot.exportedAt)")
                        Text("Gespeicherte Recherche · Kurse können verzögert sein").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if store.snapshot == nil {
                    Section("Willkommen bei SIEGER") {
                        Text("Importiere deine SIEGER-Recherchedaten oder verbinde eine HTTPS-Datenquelle. Danach stehen Watchlist, Tagescharts und News bereit.")
                        Button("Recherchedaten importieren") { importing = true }
                    }
                }
                Section("Watchlist · \(instruments.count)") {
                    ForEach(instruments) { item in
                        NavigationLink { InstrumentView(initialItem: item) } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name).font(.headline)
                                    Text(item.mappingPending ? "Zuordnung offen" : (item.marketSymbol ?? "Kein Kurssymbol")).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    if let price = item.quote.price { Text("\(price.formatted(.number.precision(.fractionLength(2)))) \(item.currency)") }
                                    if let change = item.quote.changePct { Text(String(format: "%+.2f %%", change)).foregroundStyle(change >= 0 ? .green : .red).font(.caption) }
                                    if isOlder(item.quote.fetchedAt, than: 900) || item.quote.stale == true { Text("Gespeichert").font(.caption2).foregroundStyle(.secondary) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("SIEGER")
            .searchable(text: $search, prompt: "Wert suchen")
            .refreshable { await store.refreshWatchlist() }
            .toolbar { Button { settings = true } label: { Label("Datenquelle", systemImage: "gearshape") } }
            .sheet(isPresented: $settings) {
                NavigationStack {
                    Form {
                        Section("Datenquelle") {
                            TextField("https://…/research.json", text: $store.endpoint).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                            Text("Nur eine bewusst freigegebene Adresse für öffentliche Recherchedaten verwenden. Der Dienst ist noch nicht eingerichtet.").font(.caption)
                            Button(store.loading ? "Lädt …" : "Jetzt aktualisieren") { Task { await store.refresh() } }.disabled(store.loading)
                            Button("JSON-Datei importieren") { settings = false; importing = true }
                        }
                        Section("Betrieb") { Text("Im geöffneten Wert lädt „Aktualisieren“ öffentliche Kurse und News direkt vom Anbieter. Die Watchlist wird einmal importiert. Ein eigener Server ist dafür nicht erforderlich. Öffentliche Daten können verzögert oder vorübergehend nicht verfügbar sein.") }
                    }
                    .navigationTitle("Recherchedaten")
                    .toolbar { Button("Fertig") { settings = false } }
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url): store.importFile(url)
                case .failure(let error): store.error = error.localizedDescription
                }
            }
        }
    }
}

struct InstrumentView: View {
    let initialItem: Instrument
    @EnvironmentObject private var store: ResearchStore
    var item: Instrument { store.snapshot?.instruments.first(where: { $0.id == initialItem.id }) ?? initialItem }
    @State private var uncertain = false
    @State private var period = "Heute"
    private var articles: [NewsArticle] {
        let now = Date()
        return (uncertain ? item.uncertainNews : item.news).filter { article in
            if period == "Alle" { return true }
            guard let date = article.date, date <= now else { return false }
            return period == "Heute" ? Calendar.current.isDateInToday(date) : date >= now.addingTimeInterval(-7*86400)
        }.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }
    var body: some View {
        List {
            Section("Kurs · \(item.currency)") {
                if let stamp = item.quote.timestamp {
                    Text("Kurszeit: \(Date(timeIntervalSince1970: stamp).formatted())").font(.caption)
                }
                Text(item.quote.source ?? "Keine Kursquelle verfügbar").font(.caption).foregroundStyle(.secondary)
                if isOlder(item.quote.fetchedAt, than: 900) { Text("Kursabruf älter als 15 Minuten oder Abrufzeit unbekannt.").font(.caption).foregroundStyle(.orange) }
                if item.quote.stale == true { Text("Gespeicherter Kursstand · letzter Abruf fehlgeschlagen").foregroundStyle(.orange) }
                if let error = item.quote.refreshError { Text(error).foregroundStyle(.orange) }
                if item.mappingPending { Text("Wertpapierzuordnung offen; kein eindeutig zugeordneter Chart.") }
                else if item.chart.isEmpty { Text("Keine Tageshistorie vorhanden.") }
                else {
                    Chart(item.chart) { bar in
                        LineMark(x: .value("Tag", bar.date), y: .value("Kurs", bar.close)).foregroundStyle(by: .value("Linie", "Kurs"))
                        if let value = bar.gd20 { LineMark(x: .value("Tag", bar.date), y: .value("GD20", value)).foregroundStyle(by: .value("Linie", "GD20")) }
                        if let value = bar.gd50 { LineMark(x: .value("Tag", bar.date), y: .value("GD50", value)).foregroundStyle(by: .value("Linie", "GD50")) }
                        if let value = bar.gd200 { LineMark(x: .value("Tag", bar.date), y: .value("GD200", value)).foregroundStyle(by: .value("Linie", "GD200")) }
                    }
                    .chartXAxis(.hidden).frame(height: 240)
                    Text("\(item.chart.first?.date ?? "") bis \(item.chart.last?.date ?? "") · bis zu 260 abgeschlossene Handelstage").font(.caption).foregroundStyle(.secondary)
                    Text("Historienabruf: \(parseDate(item.historyFetchedAt)?.formatted() ?? "unbekannt")").font(.caption)
                }
                if item.historyStale == true || isOlder(item.historyFetchedAt, than: 43200) { Text("Tageshistorie ist als veraltet markiert oder älter als 12 Stunden.").font(.caption).foregroundStyle(.orange) }
                if let error = item.historyError { Text(error).foregroundStyle(.orange).font(.caption) }
            }
            Section("Nachrichten") {
                Picker("Zeitraum", selection: $period) { ForEach(["Heute", "7 Tage", "Alle"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                Toggle("Unklare Feedtreffer", isOn: $uncertain)
                Text(uncertain ? "Diese Treffer haben keine eindeutige Wertzuordnung." : "Unternehmensname in der Schlagzeile. Artikelinhalt separat prüfen.").font(.caption).foregroundStyle(.secondary)
                Text("Abruf: \(parseDate(item.newsFetchedAt)?.formatted() ?? "unbekannt")").font(.caption)
                if item.newsStale == true || isOlder(item.newsFetchedAt, than: 900) { Text("Gespeicherte Nachrichten · Abruf veraltet oder fehlgeschlagen.").font(.caption).foregroundStyle(.orange) }
                if let error = item.newsError { Text(error).foregroundStyle(.orange) }
                ForEach(item.newsSourceErrors, id: \.self) { Text($0).foregroundStyle(.orange).font(.caption) }
                if articles.isEmpty { Text("Keine passenden Meldungen im gespeicherten Stand.").foregroundStyle(.secondary) }
                ForEach(articles) { article in
                    VStack(alignment: .leading, spacing: 6) {
                        if let url = article.link { Link(article.title, destination: url) } else { Text(article.title) }
                        Text("\(article.publisher ?? "Quelle unbekannt") · \(article.date?.formatted() ?? "Datum unbekannt")").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refreshInstrument(item.id) }
        .toolbar {
            Button(store.updating.contains(item.id) ? "Lädt …" : "Aktualisieren") { Task { await store.refreshInstrument(item.id) } }
                .disabled(store.loading || store.updating.contains(item.id))
        }
    }
}
