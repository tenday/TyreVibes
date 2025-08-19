// PlateScraper.swift
// TyreVibes
//
// NOTE IMPORTANTI:
// - Verifica i Termini di Servizio del sito prima di effettuare scraping.
// - Considera un proxy/server intermedio per evitare CORS e per rispettare rate limit.
// - Il parsing HTML è fragile: la struttura del sito può cambiare.
// - Questa implementazione tenta più strategie: JSON-LD, script con JSON, tabelle chiave/valore, fallback su <title>.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif


public struct PlateData: Codable, Hashable {
    public var plate: String
    public var make: String?
    public var model: String?
    public var version: String?
    public var year: String?
    public var month: String?
    public var color: String?
    public var fuel: String?
    public var powerKW: String?
    public var displacementCC: String?
    public var registrationDate: String?
    public var vin: String?
    public var extra: [String: String] = [:]
}

public enum PlateScraperError: Error, LocalizedError, Equatable {
    case invalidPlate
    case badURL
    case network(Error?)
    case emptyResponse
    case parseFailed

    public var errorDescription: String? {
        switch self {
        case .invalidPlate: return "Targa non valida."
        case .badURL: return "URL non valido."
        case .network(let e): return "Errore di rete: \(e?.localizedDescription ?? "sconosciuto")."
        case .emptyResponse: return "Risposta vuota dal server."
        case .parseFailed: return "Impossibile analizzare la pagina."
        }
    }

    public static func == (lhs: PlateScraperError, rhs: PlateScraperError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidPlate, .invalidPlate),
             (.badURL, .badURL),
             (.emptyResponse, .emptyResponse),
             (.parseFailed, .parseFailed):
            return true
        case (.network(let e1), .network(let e2)):
            return (e1?.localizedDescription ?? "") == (e2?.localizedDescription ?? "")
        default:
            return false
        }
    }
}

// MARK: - Quattroruote API integration
private struct QRPlateLookup: Decodable { let year: Int; let month: Int; let codmar: Int; let codmor: Int }
private struct QRBrandList: Decodable { let brands: [String:String]; let order: [Int] }
private struct QRModelList: Decodable { let models: [String:String]; let order: [Int] }
private struct QRPowerList: Decodable { let powers: [String:String]; let order: [Int] }

enum PlateReader {
    private static let plateAPIService = PlateAPIService()

    static func urlPlateLookup(targa: String) -> URL? {
        return URL(string: "https://www.quattroruote.it/auto-usate/api/v1/infocar-targa?targa=\(targa.uppercased())")
    }
    static func urlBrandList(year: Int, month: Int) -> URL? {
        return URL(string: "https://www.quattroruote.it/auto-usate/api/v1/brand-list/\(year)/\(month)/1/0")
    }
    static func urlModelList(codmar: Int, year: Int, month: Int) -> URL? {
        return URL(string: "https://www.quattroruote.it/auto-usate/api/v1/model-list/\(codmar)/\(year)/\(month)/1/0")
    }
    /// Ottieni direttamente modello da codmor, senza passare da codmar
    static func urlModelListById(codmor: Int, year: Int, month: Int) -> URL? {
        return URL(string: "https://www.quattroruote.it/auto-usate/api/v1/model-list/\(codmor)/\(year)/\(month)/1/0")
    }
    static func urlPowerList(codmor: Int, year: Int, month: Int) -> URL? {
        return URL(string: "https://www.quattroruote.it/auto-usate/api/v1/power-list/\(codmor)/\(year)/\(month)/1")
    }

    @available(iOS 15.0, macOS 12.0, *)
    static func fetchPlateSummary(targa: String) async throws -> PlateData {
        // 1) Check our custom DB first
        do {
            if let existingPlate = try await plateAPIService.checkPlate(plateNumber: targa) {
                print("Plate found in custom DB. Returning cached data.")
                return existingPlate
            }
        } catch {
            // If checking our DB fails, we log the error and proceed to external services.
            print("Failed to check custom DB: \(error.localizedDescription)")
        }

        // 2) Lookup plate -> year, month, codmar (brand), codmor (model)
        guard let lookupURL = urlPlateLookup(targa: targa) else { throw PlateScraperError.badURL }
        let lookup: QRPlateLookup
        do {
            lookup = try await getJSON(url: lookupURL)
        } catch {
            // Se lookup fallisce, fallback subito a motointegrator
            return try await PlateScraper.scrapePlateData(for: targa)
        }

        do {
            // 2) Brand list to resolve brand name
            var makeName: String? = nil
            if let brandURL = urlBrandList(year: lookup.year, month: lookup.month) {
                let brands: QRBrandList = try await getJSON(url: brandURL)
                makeName = brands.brands[String(lookup.codmar)]
            }

            // 3) Model list to resolve model name
            var modelName: String? = nil
            if let modelURL = urlModelList(codmar: lookup.codmar, year: lookup.year, month: lookup.month) {
                let models: QRModelList = try await getJSON(url: modelURL)
                modelName = models.models[String(lookup.codmor)]
            }

            // 4) Power list to resolve fuel kind (optional)
            var fuelName: String? = nil
            if let powerURL = urlPowerList(codmor: lookup.codmor, year: lookup.year, month: lookup.month) {
                let powers: QRPowerList = try await getJSON(url: powerURL)
                // pick first in order if exists, otherwise any value
                if let first = powers.order.first { fuelName = powers.powers[String(first)] }
            }
            // Se makeName e modelName sono entrambi nil, fallback a motointegrator
            if makeName == nil && modelName == nil {
                return try await PlateScraper.scrapePlateData(for: targa)
            }

            var result = PlateData(plate: targa.uppercased(), make: makeName, model: modelName, version: nil, year: String(lookup.year), month: String(lookup.month), color: nil, fuel: fuelName, powerKW: try await PlateScraper.scrapePowerKW(for: targa.uppercased()), displacementCC: nil, registrationDate: nil, vin: nil, extra: [:])
            // Attach raw codes for debugging/extra
            result.extra["qr_codmar"] = String(lookup.codmar)
            result.extra["qr_codmor"] = String(lookup.codmor)
            result.extra["qr_month"] = String(lookup.month)
            return result
        } catch {
            // Se errore di emptyResponse o parseFailed, fallback a motointegrator
            if let plateError = error as? PlateScraperError {
                if plateError == .emptyResponse || plateError == .parseFailed {
                    return try await PlateScraper.scrapePlateData(for: targa)
                }
            }
            throw error
        }
    }

    @available(iOS 15.0, macOS 12.0, *)
    static func getJSON<T: Decodable>(url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.1 Safari/537.36", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw PlateScraperError.network(NSError(domain: "HTTP", code: http.statusCode))
        }
        do { return try JSONDecoder().decode(T.self, from: data) } catch {
            // Some endpoints return JS objects with unquoted keys, fallback to permissive parse (naive)
            throw PlateScraperError.parseFailed
        }
    }
}

public enum PlateScraper {
    @available(iOS 15.0, macOS 12.0, *)
    public static func scrapeViaQuattroruote(plate: String) async throws -> PlateData {
        return try await PlateReader.fetchPlateSummary(targa: plate)
    }

    public static func scrapeViaQuattroruote(plate: String, completion: @escaping (Result<PlateData, Error>) -> Void) {
        if #available(iOS 15.0, macOS 12.0, *) {
            Task { do { let res = try await PlateReader.fetchPlateSummary(targa: plate); completion(.success(res)) } catch { completion(.failure(error)) } }
        } else {
            completion(.failure(PlateScraperError.network(NSError(domain: "Requires iOS 15+", code: -999))))
        }
    }
    private static func searchURL(for plate: String) -> URL? {
        var comps = URLComponents(string: "https://www.motointegrator.it/veicoli/select-vehicle-by-license-plate/")
        comps?.queryItems = [
            .init(name: "license_plate_number", value: plate),
        ]
        return comps?.url
    }

    // MARK: - Public API (async/await)
    @available(iOS 15.0, macOS 12.0, *)
    public static func scrapePlateData(for plate: String) async throws -> PlateData {
        let cleaned = plate.uppercased().replacingOccurrences(of: " ", with: "")
        guard cleaned.count >= 5 else { throw PlateScraperError.invalidPlate }
        guard let url = searchURL(for: cleaned) else { throw PlateScraperError.badURL }

        let (data, _) = try await fetch(url: url)
        // Try to parse as JSON first
        if let plateData = parseJSONData(data: data, plate: cleaned) {
            return plateData
        }
        // Fallback to HTML
        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw PlateScraperError.emptyResponse
        }
        if let parsed = parse(html: html, plate: cleaned) { return parsed }
        throw PlateScraperError.parseFailed
    }

    /// Estrae solo la potenza (powerKW) da Motointegrator
    @available(iOS 15.0, macOS 12.0, *)
    public static func scrapePowerKW(for plate: String) async throws -> String? {
        let cleaned = plate.uppercased().replacingOccurrences(of: " ", with: "")
        guard cleaned.count >= 5 else { throw PlateScraperError.invalidPlate }
        guard let url = searchURL(for: cleaned) else { throw PlateScraperError.badURL }

        let (data, _) = try await fetch(url: url)

        // Try parse JSON first
        if let plateData = parseJSONData(data: data, plate: cleaned) {
            return plateData.powerKW
        }

        // Fallback to HTML
        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw PlateScraperError.emptyResponse
        }
        if let parsed = parse(html: html, plate: cleaned) {
            return parsed.powerKW
        }
        throw PlateScraperError.parseFailed
    }

    // MARK: - Public API (completion)
    public static func scrapePlateData(for plate: String, completion: @escaping (Result<PlateData, Error>) -> Void) {
        if #available(iOS 15.0, macOS 12.0, *) {
            Task {
                do {
                    let data = try await scrapePlateData(for: plate)
                    completion(.success(data))
                } catch {
                    completion(.failure(error))
                }
            }
        } else {
            // Fallback legacy: semplice URLSession dataTask
            guard let url = searchURL(for: plate) else { completion(.failure(PlateScraperError.badURL)); return }
            fetchLegacy(url: url) { result in
                switch result {
                case .success(let data):
                    // Try to parse as JSON first
                    if let plateData = parseJSONData(data: data, plate: plate) {
                        completion(.success(plateData))
                        return
                    }
                    // Fallback to HTML
                    guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
                        completion(.failure(PlateScraperError.emptyResponse)); return
                    }
                    if let parsed = parse(html: html, plate: plate) {
                        completion(.success(parsed))
                    } else {
                        completion(.failure(PlateScraperError.parseFailed))
                    }
                case .failure(let e):
                    completion(.failure(e))
                }
            }
        }
    }

    // MARK: - Networking
    @available(iOS 15.0, macOS 12.0, *)
    private static func fetch(url: URL) async throws -> (Data, URLResponse) {
        let maxRetries = 3
        let cookieStorage = HTTPCookieStorage.shared
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = cookieStorage
        let session = URLSession(configuration: config)
        let bootstrapURL = URL(string: "https://www.motointegrator.it/")!
        for attempt in 0..<maxRetries {
            // 1. Bootstrap request to get cookies
            var bootstrapReq = URLRequest(url: bootstrapURL)
            bootstrapReq.timeoutInterval = 10
            bootstrapReq.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.1 Safari/537.36", forHTTPHeaderField: "User-Agent")
            bootstrapReq.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            bootstrapReq.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            bootstrapReq.setValue("keep-alive", forHTTPHeaderField: "Connection")
            _ = try? await session.data(for: bootstrapReq)

            // 2. Real request
            var req = URLRequest(url: url)
            req.timeoutInterval = 20
            req.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.1 Safari/537.36", forHTTPHeaderField: "User-Agent")
            req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            req.setValue("keep-alive", forHTTPHeaderField: "Connection")
            do {
                return try await session.data(for: req)
            } catch {
                let nsError = error as NSError
                if (nsError.domain == NSURLErrorDomain) && (nsError.code == NSURLErrorNetworkConnectionLost || nsError.code == NSURLErrorCannotConnectToHost) && attempt < maxRetries - 1 {
                    print("Connessione persa, ritento... (\(attempt + 1))")
                    continue
                }
                throw error
            }
        }
        throw PlateScraperError.network(nil) // Should not reach here
    }

    private static func fetchLegacy(url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        let maxRetries = 3
        let cookieStorage = HTTPCookieStorage.shared
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = cookieStorage
        let session = URLSession(configuration: config)
        let bootstrapURL = URL(string: "https://www.motointegrator.it/")!
        func attempt(_ tries: Int) {
            // 1. Bootstrap request to get cookies
            var bootstrapReq = URLRequest(url: bootstrapURL)
            bootstrapReq.timeoutInterval = 10
            bootstrapReq.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.1 Safari/537.36", forHTTPHeaderField: "User-Agent")
            bootstrapReq.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            bootstrapReq.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            bootstrapReq.setValue("keep-alive", forHTTPHeaderField: "Connection")
            session.dataTask(with: bootstrapReq) { _, _, _ in
                // 2. Real request
                var req = URLRequest(url: url)
                req.timeoutInterval = 20
                req.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.1 Safari/537.36", forHTTPHeaderField: "User-Agent")
                req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
                req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
                req.setValue("keep-alive", forHTTPHeaderField: "Connection")
                session.dataTask(with: req) { data, _, error in
                    if let error = error as NSError? {
                        if (error.domain == NSURLErrorDomain) && (error.code == NSURLErrorNetworkConnectionLost || error.code == NSURLErrorCannotConnectToHost) && tries < maxRetries - 1 {
                            print("Connessione persa, ritento... (\(tries + 1))")
                            attempt(tries + 1)
                            return
                        }
                        completion(.failure(PlateScraperError.network(error)))
                        return
                    }
                    guard let data = data else { completion(.failure(PlateScraperError.emptyResponse)); return }
                    completion(.success(data))
                }.resume()
            }.resume()
        }
        attempt(0)
    }

    // MARK: - Parsing
    /// Prova più strategie per estrarre i dati.
    private static func parse(html: String, plate: String) -> PlateData? {
        // 1) JSON-LD
        if let ld = extractJSONLD(html: html), let parsed = parseJSONLD(ld, plate: plate) {
            return parsed
        }
        // 2) JSON in <script> (es. Nuxt/Next data)
        if let json = extractInlineJSON(html: html), let parsed = parseInlineJSON(json, plate: plate) {
            return parsed
        }
        // 3) Tabelle chiave/valore
        if let kv = extractKeyValuePairs(html: html) {
            return PlateData(
                plate: plate,
                make: kv["marca"] ?? kv["brand"],
                model: kv["modello"] ?? kv["model"],
                version: kv["versione"] ?? kv["version"],
                year: kv["anno"] ?? kv["year"],
                month: kv["mese"] ?? kv["month"],
                color: kv["colore"] ?? kv["color"],
                fuel: kv["alimentazione"] ?? kv["fuel"],
                powerKW: kv["potenza (kw)"] ?? kv["kw"] ?? kv["potenza"],
                displacementCC: kv["cilindrata"] ?? kv["cc"],
                registrationDate: kv["immatricolazione"] ?? kv["first registration"],
                vin: kv["vin"],
                extra: kv
            )
        }
        // 4) Fallback: usa <title>
        if let title = extractTitle(html: html) {
            return PlateData(plate: plate, make: nil, model: title, version: nil, year: nil, color: nil, fuel: nil, powerKW: nil, displacementCC: nil, registrationDate: nil, vin: nil, extra: ["title": title])
        }
        return nil
    }

    // MARK: - Heuristics extractors (no external deps)
    private static func extractTitle(html: String) -> String? {
        guard let range = html.range(of: "<title>", options: .caseInsensitive),
              let end = html.range(of: "</title>", options: .caseInsensitive, range: range.upperBound..<html.endIndex) else { return nil }
        return String(html[range.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Estrae blocchi JSON-LD da tag <script type="application/ld+json">
    private static func extractJSONLD(html: String) -> [Any]? {
        var results: [Any] = []
        let pattern = "<script[^>]*type=\\\"application/ld+json\\\"[^>]*>([\\s\\S]*?)</script>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let ns = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for m in matches {
                if m.numberOfRanges >= 2 {
                    let jsonStr = ns.substring(with: m.range(at: 1))
                    if let data = jsonStr.data(using: .utf8),
                       let obj = try? JSONSerialization.jsonObject(with: data, options: []) {
                        results.append(obj)
                    }
                }
            }
        }
        return results.isEmpty ? nil : results
    }

    /// Cerca JSON inline in <script> che contenga parole chiave tipo "vehicle" "marca" etc.
    private static func extractInlineJSON(html: String) -> Any? {
        let pattern = "<script[^>]*>([\\s\\S]*?)</script>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        for m in matches {
            if m.numberOfRanges >= 2 {
                let scriptBody = ns.substring(with: m.range(at: 1))
                // Heuristic: estrai il primo oggetto JSON grande
                if let jsonRange = scriptBody.range(of: "\\{[\\s\\S]*\\}", options: .regularExpression) {
                    let jsonStr = String(scriptBody[jsonRange])
                    if let data = jsonStr.data(using: .utf8),
                       let obj = try? JSONSerialization.jsonObject(with: data, options: []) {
                        // Valida che sembri rilevante
                        let s = scriptBody.lowercased()
                        if s.contains("vehicle") || s.contains("marca") || s.contains("modello") || s.contains("targa") {
                            return obj
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Estrae coppie chiave:valore da semplici tabelle HTML
    private static func extractKeyValuePairs(html: String) -> [String: String]? {
        // Cerca pattern tipo <tr><th>Chiave</th><td>Valore</td></tr>
        let rowPattern = "<tr[^>]*>[\\s\\S]*?</tr>"
        guard let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: [.caseInsensitive]) else { return nil }
        let ns = html as NSString
        var map: [String: String] = [:]
        let matches = rowRegex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        for m in matches {
            let row = ns.substring(with: m.range)
            let th = innerText(ofFirstTag: "th", in: row) ?? innerText(ofFirstTag: "dt", in: row)
            let td = innerText(ofFirstTag: "td", in: row) ?? innerText(ofFirstTag: "dd", in: row)
            if let k = th, let v = td {
                let key = normalizeKey(k)
                map[key] = v.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return map.isEmpty ? nil : map
    }

    private static func innerText(ofFirstTag tag: String, in html: String) -> String? {
        let pattern = "<\(tag)[^>]*>([\\s\\S]*?)</\(tag)>"
            .replacingOccurrences(of: "(tag)", with: tag)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges >= 2 else { return nil }
        let raw = ns.substring(with: match.range(at: 1))
        return stripHTML(raw)
    }

    private static func stripHTML(_ s: String) -> String {
        var str = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        str = str.replacingOccurrences(of: "&nbsp;", with: " ")
        str = str.replacingOccurrences(of: "&amp;", with: "&")
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeKey(_ s: String) -> String {
        return s.lowercased()
            .replacingOccurrences(of: "å", with: "a")
            .replacingOccurrences(of: "é", with: "e")
            .replacingOccurrences(of: "è", with: "e")
            .replacingOccurrences(of: "à", with: "a")
            .replacingOccurrences(of: "ì", with: "i")
            .replacingOccurrences(of: "ò", with: "o")
            .replacingOccurrences(of: "ù", with: "u")
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Parsers for JSON shapes
    private static func parseJSONLD(_ objects: [Any], plate: String) -> PlateData? {
        // Cerca oggetti con @type Vehicle o Product
        for obj in objects {
            if let dict = obj as? [String: Any] {
                if let type = dict["@type"] as? String, type.lowercased().contains("vehicle") || type.lowercased().contains("product") {
                    var data = PlateData(plate: plate)
                    if let brand = (dict["brand"] as? [String: Any])?["name"] as? String { data.make = brand }
                    if let model = dict["model"] as? String { data.model = model }
                    if let color = dict["color"] as? String { data.color = color }
                    if let prodDate = dict["productionDate"] as? String { data.year = prodDate }
                    return data
                }
            }
        }
        return nil
    }

    private static func parseInlineJSON(_ obj: Any, plate: String) -> PlateData? {
        // Heuristica su strutture comuni (Nuxt, Next, ecc.)
        if let dict = obj as? [String: Any] {
            // prova alcune chiavi tipiche
            let lower = dict.reduce(into: [String: Any]()) { $0[$1.key.lowercased()] = $1.value }
            let maybeVehicle = (lower["vehicle"] ?? lower["car"] ?? lower["auto"] ?? lower["veicolo"]) as Any?
            if let v = maybeVehicle as? [String: Any] {
                var data = PlateData(plate: plate)
                data.make = (v["make"] ?? v["marca"]) as? String
                data.model = (v["model"] ?? v["modello"]) as? String
                data.color = (v["color"] ?? v["colore"]) as? String
                data.year = (v["year"] ?? v["anno"]) as? String
                data.month = (v["month"] ?? v["mese"]) as? String
                data.vin = v["vin"] as? String
                return data
            }
        }
        return nil
    }
}

    // MARK: - JSON direct parser
    /// Attempts to parse a Data as a dictionary and map to PlateData fields.
private func parseJSONData(data: Data, plate: String) -> PlateData? {
    guard let jsonObj = try? JSONSerialization.jsonObject(with: data, options: []) else { return nil }
    guard let dict = jsonObj as? [String: Any] else { return nil }

    // --- Custom logic for "user_vehicle" dictionary ---
    if let userVehicle = dict["user_vehicle"] as? [String: Any] {
        let fullName = userVehicle["full_name"] as? String
        let yearInt = userVehicle["year"] as? Int
        let year: String? = (yearInt != nil && yearInt! > 0) ? String(yearInt!) : nil
        let monthInt = userVehicle["month"] as? Int
        let month: String? = (monthInt != nil && monthInt! > 0 && monthInt! < 13) ? String(monthInt!) : nil
        let vin = (userVehicle["vin"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let registration = userVehicle["registration"] as? String
        let vehicleData = userVehicle["vehicle_data"] as? String
        var decodedData: [String: Any] = [:]
        if let vehicleData = vehicleData, !vehicleData.isEmpty {
            let parts = vehicleData.components(separatedBy: ":")
            if let base64 = parts.first, let data = Data(base64Encoded: base64) {
                if let obj = try? JSONSerialization.jsonObject(with: data, options: []),
                   let dict = obj as? [String: Any] {
                    decodedData = dict
                }
            }
        }
        var extra: [String: String] = [:]
        for (k, v) in decodedData {
            extra[k] = String(describing: v)
        }
        let model = fullName?
            .components(separatedBy: "(")
            .first?
            .components(separatedBy: " ")
            .dropFirst()
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let make = fullName?.components(separatedBy: " ").first
        let power = fullName?.components(separatedBy: "potenza:").dropFirst().joined(separator: " ")
        var result = PlateData(
            plate: registration ?? plate,
            make: make,
            model: model,
            version: nil,
            year: year,
            month: month,
            color: nil,
            fuel: nil,
            powerKW: power,
            displacementCC: nil,
            registrationDate: nil,
            vin: vin,
            extra: extra
        )
        // Recupera make/model da Quattroruote se presenti gli identificativi
        if let manIdStr = extra["manufacturer_id"],
           let modIdStr = extra["model_id"],
           let manId = Int(manIdStr),
           let modId = Int(modIdStr),
           let yearStr = extra["year"],
           let yearInt = Int(yearStr), yearInt > 0 {

            if #available(iOS 15.0, macOS 12.0, *) {
                Task {
                    if let brandURL = PlateReader.urlBrandList(year: yearInt, month: 1) {
                        if let brands: QRBrandList = try? await PlateReader.getJSON(url: brandURL) {
                            result.make = brands.brands[String(manId)] ?? result.make
                        }
                    }
                    if let modelURL = PlateReader.urlModelList(codmar: manId, year: yearInt, month: 1) {
                        if let models: QRModelList = try? await PlateReader.getJSON(url: modelURL) {
                            result.model = models.models[String(modId)] ?? result.model
                        }
                    }
                }
            }
        }
        return result
    }

    // --- Fallback to flat dictionary mapping ---
    let make = (dict["make"] ?? dict["marca"]) as? String
    let model = (dict["model"] ?? dict["modello"]) as? String
    let version = dict["version"] as? String
    let year = (dict["year"] ?? dict["anno"]) as? String
    let month = (dict["month"] ?? dict["mese"]) as? String
    let color = (dict["color"] ?? dict["colore"]) as? String
    let fuel = (dict["fuel"] ?? dict["alimentazione"]) as? String
    let powerKW = (dict["kw"] ?? dict["potenza"]) as? String
    let displacementCC = (dict["cc"] ?? dict["cilindrata"]) as? String
    let registrationDate = (dict["firstRegistration"] ?? dict["immatricolazione"]) as? String
    let vin = dict["vin"] as? String
    // Convert all fields to string for extra
    var extra: [String: String] = [:]
    for (k, v) in dict {
        extra[k] = String(describing: v)
    }
    // At least one key field must be present (make/model/year/vin) to consider this valid
    if make != nil || model != nil || year != nil || vin != nil {
        return PlateData(
            plate: plate,
            make: make,
            model: model,
            version: version,
            year: year,
            month: month,
            color: color,
            fuel: fuel,
            powerKW: powerKW,
            displacementCC: displacementCC,
            registrationDate: registrationDate,
            vin: vin,
            extra: extra
        )
    }
    return nil
}
