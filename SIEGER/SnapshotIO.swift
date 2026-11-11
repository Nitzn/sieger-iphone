import Foundation

enum ResearchError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

enum SnapshotIO {
    static let maximumBytes = 20_000_000

    static func readFile(_ url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maximumBytes else { throw ResearchError.message("Datei ist größer als 20 MB.") }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        // Bound the actual read too, in case a file grows after checking its size.
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else { throw ResearchError.message("Datei ist größer als 20 MB.") }
        return data
    }

    static func decode(_ data: Data) throws -> Snapshot {
        guard data.count <= maximumBytes else { throw ResearchError.message("Datei ist größer als 20 MB.") }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let value = try decoder.decode(Snapshot.self, from: data)
        guard value.schemaVersion == 1 else { throw ResearchError.message("Unbekanntes Datenformat.") }
        guard Set(value.instruments.map(\.id)).count == value.instruments.count else { throw ResearchError.message("Doppelte Wertpapier-IDs.") }
        for item in value.instruments {
            guard Set(item.chart.map(\.id)).count == item.chart.count,
                  Set(item.news.map(\.id)).count == item.news.count,
                  Set(item.uncertainNews.map(\.id)).count == item.uncertainNews.count else {
                throw ResearchError.message("Doppelte Datenpunkte oder Nachrichten-IDs.")
            }
            guard item.chart.allSatisfy({ $0.close.isFinite && $0.close > 0 }),
                  item.quote.price.map({ $0.isFinite && $0 > 0 }) ?? true else {
                throw ResearchError.message("Ungültige Kursdaten.")
            }
        }
        return value
    }

    static func encode(_ value: Snapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(value)
    }
}

final class HTTPSOnly: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url?.scheme?.lowercased() == "https" ? request : nil)
    }
}

enum PublicHTTP {
    static func get(_ url: URL, maximum: Int = SnapshotIO.maximumBytes) async throws -> Data {
        guard url.scheme?.lowercased() == "https", url.host != nil, url.user == nil, url.password == nil else {
            throw ResearchError.message("Eine gültige HTTPS-Adresse wird benötigt.")
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 90
        let session = URLSession(configuration: configuration, delegate: HTTPSOnly(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 SIEGER-Research/0.4", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.url?.scheme?.lowercased() == "https" else {
            throw ResearchError.message("Datenquelle antwortet nicht erfolgreich über HTTPS.")
        }
        guard response.expectedContentLength <= maximum else { throw ResearchError.message("Datenantwort ist zu groß.") }
        var data = Data()
        data.reserveCapacity(min(maximum, 256_000))
        for try await byte in bytes {
            guard data.count < maximum else { throw ResearchError.message("Datenantwort ist zu groß.") }
            data.append(byte)
        }
        return data
    }
}
