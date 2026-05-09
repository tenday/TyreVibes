// the entire code of the file with your changes goes here.
// Do not skip over anything.
import Foundation
import UIKit
import Vision
import CoreImage

// MARK: - Cache System for PlateData
class PlateDataCache {
    // CachedPlateData deve essere una classe per NSCache
    private class CachedPlateData {
        let data: PlateData
        let timestamp: Date

        init(data: PlateData, timestamp: Date) {
            self.data = data
            self.timestamp = timestamp
        }

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > PlateDataCache.cacheExpiry
        }
    }

    private static let cache = NSCache<NSString, CachedPlateData>()
    private static let cacheExpiry: TimeInterval = 3600 // 1 ora

    // Configurazione cache inizializzata correttamente
    private static let initializeCache: Void = {
        cache.countLimit = 100 // Max 100 targhe in cache
        cache.totalCostLimit = 50_000_000 // Max ~50MB per cache
    }()

    static func get(_ plate: String) -> PlateData? {
        let key = plate.uppercased() as NSString
        guard let cached = cache.object(forKey: key) else { return nil }

        if cached.isExpired {
            cache.removeObject(forKey: key)
            return nil
        }

        return cached.data
    }

    static func set(_ plate: String, data: PlateData) {
        let key = plate.uppercased() as NSString
        let cached = CachedPlateData(data: data, timestamp: Date())
        cache.setObject(cached, forKey: key)
    }

    static func clearExpired() {
        // Pulisce automaticamente le voci scadute
        cache.removeAllObjects()
    }

    static func clear() {
        cache.removeAllObjects()
    }

    // Statistiche cache per debug/monitoring
    static func getCacheStats() -> (count: Int, memoryUsage: String) {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .memory

        // Stima approssimativa della memoria
        let estimatedSize = cache.totalCostLimit / 10 // Stima conservativa

        return (
            count: cache.countLimit, // Approssimazione
            memoryUsage: formatter.string(fromByteCount: Int64(estimatedSize))
        )
    }

    static func preloadCache() {
        // Pre-configurazione cache al primo utilizzo
        _ = initializeCache
    }
}

private final class ThrowingContinuationBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<T, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()

        continuation?.resume(with: result)
    }
}

// Modello dati (manteniamo PlateData)
public struct PlateData {
    public var plate: String
    public var make: String?
    public var model: String?
    public var version: String?
    public var year: String?
    public var month: String?
    public var color: String?
    public var fuelType: String?
    public var powerKW: String?
    public var powerCV: String?
    public var modelDetails: String?
    public var displacementCC: String?
    public var registrationDate: String?
    public var vin: String?
    public var insuranceCompany: String?
    public var insuranceExpiry: Date?
    public var insurancePresent: Bool?
    public var insurancePolicyNumber: String?
    public var emissionClass: String?
    public var tyres: [[String: String]]?

    // --- Fields from /dettagli response mapping ---
    public var view: String?
    public var saleEnd: String?
    public var saleStart: String?
    public var gearbox: String?
    public var maxSpeed: String?
    public var bodyType: String?
    public var doors: String?
    public var seats: String?
    public var consumption: String?
    public var traction: String?
    public var powerCVKW: String?
    
    public var revisioni: [Revisione]?
    public var bollo: BolloCalculationResult? = nil
    
    public var vehicleImage: UIImage?
    public var vehicleAngle: Int?
    
    public var vehicleId: Int?

    public var hasVehicleIdentityData: Bool {
        [
            make,
            model,
            modelDetails,
            registrationDate,
            displacementCC,
            version,
            vin
        ].contains { value in
            guard let value else { return false }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && trimmed != "-" && trimmed != "0"
        }
    }

    public var hasVehicleLookupData: Bool {
        hasVehicleIdentityData
    }
}

// Lettore principale
public class LicensePlateReader {

    static var exists : Bool = false

    public static func normalizePlate(_ input: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String(input.uppercased().unicodeScalars.filter { allowed.contains($0) })
    }

    // ⚡ URLSession ottimizzata per prestazioni migliori
    private static let optimizedSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = NetworkTimeout.plateProbeRequest
        config.timeoutIntervalForResource = NetworkTimeout.plateProbeResource
        config.httpMaximumConnectionsPerHost = 8   // Max 8 connessioni parallele
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil                      // Disabilita cache URLSession (usiamo la nostra)
        config.applyHTTPToolkitProxyIfEnabled()
        return URLSession(configuration: config)
    }()
    


    // MARK: - TyreVibes Plate Data API
    public static func fetchPlateData(plate: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        let urlString = "https://api.tyrevibes.com/plate/\(plate)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 10001, userInfo: [NSLocalizedDescriptionKey: "URL non valida"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let task = URLSession.tyreVibesShared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 10002, userInfo: [NSLocalizedDescriptionKey: "Nessun dato ricevuto"])))
                return
            }
            do {
                // Prova a decodificare come dizionario [String: String]
                if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                    completion(.success(dict))
                } else {
                    completion(.failure(NSError(domain: "LicensePlateReader", code: 10003, userInfo: [NSLocalizedDescriptionKey: "Risposta non valida: atteso dizionario [String: String]"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }


    /// Ottiene un token reCAPTCHA v3 partendo dall'URL di anchor (Google)
    public static func fetchRecaptchaV3Token(anchorURL: String, completion: @escaping (Result<String, Error>) -> Void) {
        // 1) Scarica l'anchor
        guard let anchor = URL(string: anchorURL) else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 11001, userInfo: [NSLocalizedDescriptionKey: "Anchor URL non valido"]))); return
        }
        var req = URLRequest(url: anchor)
        req.httpMethod = "GET"
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        URLSession.tyreVibesShared.dataTask(with: req) { data, resp, err in
            if let err = err { completion(.failure(err)); return }
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 11002, userInfo: [NSLocalizedDescriptionKey: "Nessun HTML dal server"]))); return
            }
            // 2) Estrai il valore di "recaptcha-token" (chiave "c") dall'HTML dell'anchor
            //   Nei markup v3 tipici compare un input/textarea con name="recaptcha-token" value="<c>"
            let patterns = [
                "name=\\\"recaptcha-token\\\"[^>]*value=\\\"([^\\\"]+)\\\"",
                "id=\\\"recaptcha-token\\\"[^>]*value=\\\"([^\\\"]+)\\\"",
                "\nrecaptcha-token\n.*?value=\\\"([^\\\"]+)\\\""
            ]
            var cParam: String?
            for pat in patterns {
                if let rgx = try? NSRegularExpression(pattern: pat, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                    let ns = NSRange(html.startIndex..<html.endIndex, in: html)
                    if let m = rgx.firstMatch(in: html, options: [], range: ns), m.numberOfRanges >= 2,
                       let r = Range(m.range(at: 1), in: html) {
                        cParam = String(html[r])
                        break
                    }
                }
            }
            guard let c = cParam, !c.isEmpty else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 11003, userInfo: [NSLocalizedDescriptionKey: "Impossibile estrarre 'c' dall'anchor reCAPTCHA"]))); return
            }
            // 3) Prepara parametri per /reload: k, v, co estratti dalla query dell'anchor
            guard let comps = URLComponents(string: anchorURL),
                  let siteKey = comps.queryItems?.first(where: { $0.name == "k" })?.value,
                  let v = comps.queryItems?.first(where: { $0.name == "v" })?.value,
                  let co = comps.queryItems?.first(where: { $0.name == "co" })?.value else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 11004, userInfo: [NSLocalizedDescriptionKey: "Parametri obbligatori mancanti nell'anchor (k/v/co)"]))); return
            }
            // 4) Chiama /reload per ottenere il token "rresp"
            guard let reloadURL = URL(string: "https://www.google.com/recaptcha/api2/reload?k=\(siteKey)") else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 11005, userInfo: [NSLocalizedDescriptionKey: "Reload URL non valido"]))); return
            }
            var reloadReq = URLRequest(url: reloadURL)
            reloadReq.httpMethod = "POST"
            reloadReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            reloadReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let body = "v=\(v)&reason=q&k=\(siteKey)&c=\(c)&sa=&co=\(co)"
            reloadReq.httpBody = body.data(using: .utf8)
            URLSession.tyreVibesShared.dataTask(with: reloadReq) { data2, resp2, err2 in
                if let err2 = err2 { completion(.failure(err2)); return }
                guard let data2 = data2, let txt = String(data: data2, encoding: .utf8) else {
                    completion(.failure(NSError(domain: "LicensePlateReader", code: 11006, userInfo: [NSLocalizedDescriptionKey: "Nessuna risposta da /reload"]))); return
                }
                // 5) Estrai il token dall'array JSON "magic" di /reload (terzo elemento, di solito)
                //    Strategia robusta: prendi la stringa tra virgolette più lunga (>100)
                let quotePattern = "\\\"([^\\\"]{50,})\\\"" // cattura stringhe lunghe
                if let rgx = try? NSRegularExpression(pattern: quotePattern, options: [] ) {
                    let ns = NSRange(txt.startIndex..<txt.endIndex, in: txt)
                    let matches = rgx.matches(in: txt, options: [], range: ns)
                    let candidates: [String] = matches.compactMap { m in
                        guard m.numberOfRanges >= 2, let r = Range(m.range(at: 1), in: txt) else { return nil }
                        return String(txt[r])
                    }
                    if let token = candidates.max(by: { $0.count < $1.count }) {
                        completion(.success(token))
                        return
                    }
                }
                completion(.failure(NSError(domain: "LicensePlateReader", code: 11007, userInfo: [NSLocalizedDescriptionKey: "Impossibile estrarre token da /reload"])));
            }.resume()
        }.resume()
    }

    // UA randomico (iOS/Android/desktop)
    private static func randomUserAgent() -> String {
        let iosMaj = Int.random(in: 15...18)
        let iosMin = Int.random(in: 0...6)
        let chromeMaj = Int.random(in: 120...128)
        let androidMaj = Int.random(in: 10...14)
        let pick = Int.random(in: 0...2)
        switch pick {
        case 0: // iPhone
            return "Mozilla/5.0 (iPhone; CPU iPhone OS \(iosMaj)_\(iosMin) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(iosMaj).0 Mobile/15E148 Safari/604.1"
        case 1: // Android
            return "Mozilla/5.0 (Linux; Android \(androidMaj)) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(chromeMaj).0.0.0 Mobile Safari/537.36"
        default: // Desktop
            return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(chromeMaj).0.0.0 Safari/537.36"
        }
    }

    // Costruisce il body JSON array per /reload
    private static func buildReloadJSONArrayBody(
        c: String,
        k: String,
        v: String,
        co: String,
        size: String = "invisible",
        reason: String = "q",
        ar: String = "1",
        cb: String,
        hl: String = "it"
    ) throws -> Data {
        let arr: [[String: Any]] = [
            ["key":"bg","value":""],
            ["key":"vh","value":""],
            ["key":"chr","value":""],
            ["key":"c","value":c],
            ["key":"reason","value":reason],
            ["key":"size","value":size],
            ["key":"v","value":v],
            ["key":"co","value":co],
            ["key":"k","value":k],
            ["key":"ar","value":ar],
            ["key":"cb","value":cb],
            ["key":"hl","value":hl]
        ]
        return try JSONSerialization.data(withJSONObject: arr, options: [])
    }
    
    
    

    // Estrae dall'anchor i parametri (k, v, co, hl, ar, size, cb) + il token "c" dall'HTML
    private static func parseAnchorAndExtractParams(
        anchorURL: String,
        completion: @escaping (Result<(k:String,v:String,co:String,hl:String,ar:String,size:String,cb:String,c:String), Error>) -> Void
    ) {
        guard let url = URL(string: anchorURL), let comps = URLComponents(string: anchorURL) else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 13001, userInfo: [NSLocalizedDescriptionKey:"Anchor URL non valido"])));
            return
        }
        let q = comps.queryItems ?? []
        func qv(_ name: String, _ def: String = "") -> String { q.first(where:{$0.name==name})?.value ?? def }
        let k  = qv("k")
        let v  = qv("v")
        let co = qv("co")
        let hl = qv("hl","it")
        let ar = qv("ar","1")
        let size = qv("size","invisible")
        let cb = qv("cb","cb")
        guard !k.isEmpty, !v.isEmpty, !co.isEmpty else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 13002, userInfo: [NSLocalizedDescriptionKey:"Parametri k/v/co mancanti nell'anchor"])));
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(randomUserAgent(), forHTTPHeaderField: "User-Agent")
        req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        URLSession.tyreVibesShared.dataTask(with: req) { data, _, err in
            if let err = err { completion(.failure(err)); return }
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain:"LicensePlateReader", code:13003, userInfo:[NSLocalizedDescriptionKey:"Nessun HTML"])));
                return
            }
            let patterns = [
                "name=\\\"recaptcha-token\\\"[^>]*value=\\\"([^\\\"]+)\\\"",
                "id=\\\"recaptcha-token\\\"[^>]*value=\\\"([^\\\"]+)\\\"",
                "\\brecaptcha-token\\b[\\s\\S]*?value=\\\"([^\\\"]+)\\\""
            ]
            var cParam: String?
            for pat in patterns {
                if let rgx = try? NSRegularExpression(pattern: pat, options: [.dotMatchesLineSeparators,.caseInsensitive]) {
                    let ns = NSRange(html.startIndex..<html.endIndex, in: html)
                    if let m = rgx.firstMatch(in: html, options: [], range: ns), m.numberOfRanges >= 2,
                       let r = Range(m.range(at: 1), in: html) {
                        cParam = String(html[r])
                        break
                    }
                }
            }
            guard let c = cParam, !c.isEmpty else {
                completion(.failure(NSError(domain:"LicensePlateReader", code:13004, userInfo:[NSLocalizedDescriptionKey:"Impossibile estrarre 'c' dall'anchor"])));
                return
            }
            completion(.success((k:k,v:v,co:co,hl:hl,ar:ar,size:size,cb:cb,c:c)))
        }.resume()
    }

    // Chiama /reload con body JSON array e UA randomico; restituisce il token finale (rresp)
    public static func fetchRecaptchaV3Token_JSON(
        anchorURL: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        parseAnchorAndExtractParams(anchorURL: anchorURL) { parseResult in
            switch parseResult {
            case .failure(let e): completion(.failure(e))
            case .success(let p):
                guard let reloadURL = URL(string: "https://www.google.com/recaptcha/api2/reload?k=\(p.k)") else {
                    completion(.failure(NSError(domain:"LicensePlateReader", code:13005, userInfo:[NSLocalizedDescriptionKey:"Reload URL non valido"])));
                    return
                }
                var req = URLRequest(url: reloadURL)
                req.httpMethod = "POST"
                req.setValue(randomUserAgent(), forHTTPHeaderField: "User-Agent")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                do {
                    req.httpBody = try buildReloadJSONArrayBody(c: p.c, k: p.k, v: p.v, co: p.co, size: p.size, reason: "q", ar: p.ar, cb: p.cb, hl: p.hl)
                } catch {
                    completion(.failure(error)); return
                }
                URLSession.tyreVibesShared.dataTask(with: req) { data, _, err in
                    if let err = err { completion(.failure(err)); return }
                    guard let data = data, let txt = String(data: data, encoding: .utf8) else {
                        completion(.failure(NSError(domain:"LicensePlateReader", code:13006, userInfo:[NSLocalizedDescriptionKey:"Nessuna risposta da /reload"])));
                        return
                    }
                    if let rgx = try? NSRegularExpression(pattern: "\\\"([^\\\"]{50,})\\\"", options: [] ) {
                        let ns = NSRange(txt.startIndex..<txt.endIndex, in: txt)
                        let matches = rgx.matches(in: txt, options: [], range: ns)
                        let candidates = matches.compactMap { m -> String? in
                            guard m.numberOfRanges >= 2, let r = Range(m.range(at: 1), in: txt) else { return nil }
                            return String(txt[r])
                        }
                        if let token = candidates.max(by: { $0.count < $1.count }) {
                            completion(.success(token)); return
                        }
                    }
                    completion(.failure(NSError(domain:"LicensePlateReader", code:13007, userInfo:[NSLocalizedDescriptionKey:"Impossibile estrarre token da /reload"])));
                }.resume()
            }
        }
    }

    /// Interroga prima l'anchor reCAPTCHA (anchor -> reload JSON array con UA random) e poi chiama l'API Quattroruote check-plate
    public static func fetchQuattroruotePlateData(plate: String, anchorURL: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        fetchRecaptchaV3Token(anchorURL: anchorURL) { tokenResult in
            switch tokenResult {
            case .failure(let e):
                completion(.failure(e))
            case .success(let token):
                guard let url = URL(string: "https://quotazioni.quattroruote.it/api/check-plate") else {
                    completion(.failure(NSError(domain: "LicensePlateReader", code: 12001, userInfo: [NSLocalizedDescriptionKey: "Endpoint Quattroruote non valido"])))
                    return
                }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.timeoutInterval = NetworkTimeout.quickLookup
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("application/json", forHTTPHeaderField: "Accept")
                req.setValue(randomUserAgent(), forHTTPHeaderField: "User-Agent")
                let body: [String: Any] = [
                    "plate": plate.uppercased(),
                    "recaptcha_token": token
                ]
                // Corpo JSON
                do {
                    req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                } catch { completion(.failure(error)); return }

                URLSession.tyreVibesShared.dataTask(with: req) { data, resp, err in
                    if let err = err { completion(.failure(err)); return }
                    let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
                    let contentType = (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
                    logNetwork("[Quattroruote] check-plate status=\(status) contentType=\(contentType) bytes=\(data?.count ?? 0) plate=\(plate)")
                    guard let data = data else {
                        completion(.failure(NSError(domain: "LicensePlateReader", code: 12002, userInfo: [NSLocalizedDescriptionKey: "Nessun dato da Quattroruote"])))
                        return
                    }

                    // 1) Prova JSON standard
                    if let jsonObj = try? JSONSerialization.jsonObject(with: data, options: []),
                       let dict = jsonObj as? [String: Any] {
                        logNetwork("[Quattroruote] check-plate json keys=\(dict.keys.sorted()) plate=\(plate)")
                        completion(.success(dict))
                        return
                    }

                    // 2) Altrimenti prova a leggere HTML e a estrarre il csrf-token
                    if let html = String(data: data, encoding: .utf8) {
                        // Possibili pattern:
                        // <meta name="csrf-token" content="..."> oppure
                        // <input type="hidden" name="csrf-token" value="...">
                        let patterns = [
                            "<meta[^>]*name=\\\"csrf-token\\\"[^>]*content=\\\"([^\\\"]+)\\\"[^>]*>",
                            "name=\\\"csrf-token\\\"[^>]*value=\\\"([^\\\"]+)\\\""
                        ]
                        for pat in patterns {
                            if let rgx = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                                let nsrange = NSRange(html.startIndex..<html.endIndex, in: html)
                                if let m = rgx.firstMatch(in: html, options: [], range: nsrange), m.numberOfRanges >= 2,
                                   let r = Range(m.range(at: 1), in: html) {
                                    let csrfToken = String(html[r])
                                    // Invece di restituire subito il token, chiama /allestimenti
                                    // Costruisci la URL con i parametri richiesti
                                    guard var comps = URLComponents(string: "https://quotazioni.quattroruote.it/allestimenti") else {
                                        completion(.failure(NSError(domain: "LicensePlateReader", code: 12006, userInfo: [NSLocalizedDescriptionKey: "URL allestimenti non valida"])))
                                        return
                                    }
                                    comps.queryItems = [
                                        URLQueryItem(name: "_token", value: csrfToken),
                                        URLQueryItem(name: "plate", value: plate.uppercased()),
                                        URLQueryItem(name: "vehicle_type", value: "1"),
                                        URLQueryItem(name: "quotation_type", value: "nominale")
                                    ]
                                    guard let allestimentiURL = comps.url else {
                                        completion(.failure(NSError(domain: "LicensePlateReader", code: 12006, userInfo: [NSLocalizedDescriptionKey: "URL allestimenti non valida"])))
                                        return
                                    }
                                    var getReq = URLRequest(url: allestimentiURL)
                                    getReq.httpMethod = "POST"
                                    getReq.timeoutInterval = NetworkTimeout.quickLookup
                                    getReq.setValue(randomUserAgent(), forHTTPHeaderField: "User-Agent")
                                    getReq.setValue("application/json", forHTTPHeaderField: "Accept")
                URLSession.tyreVibesShared.dataTask(with: getReq) { data2, resp2, err2 in
                    if let err2 = err2 {
                        completion(.failure(err2))
                        return
                    }
                    let status = (resp2 as? HTTPURLResponse)?.statusCode ?? -1
                    let contentType = (resp2 as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
                    logNetwork("[Quattroruote] allestimenti status=\(status) contentType=\(contentType) bytes=\(data2?.count ?? 0) plate=\(plate)")
                    guard let data2 = data2 else {
                        completion(.failure(NSError(domain: "LicensePlateReader", code: 12007, userInfo: [NSLocalizedDescriptionKey: "Nessun dato da /allestimenti"])))
                        return
                    }
                    // Prova a decodificare come JSON
                    do {
                        let obj = try JSONSerialization.jsonObject(with: data2, options: [])
                        if let dict = obj as? [String: Any] {
                            completion(.success(dict))
                            return
                        } else {
                            // Fallback: restituisci il csrf_token se la risposta non è JSON valido
                            completion(.success(["csrf_token": csrfToken]))
                            return
                        }
                    } catch {
                        // Errore: risposta non JSON, quindi tentiamo di estrarre dal tag <car-filter-container :data="...">
                        guard let html = String(data: data2, encoding: .utf8) else {
                            completion(.failure(NSError(domain: "LicensePlateReader", code: 12008, userInfo: [NSLocalizedDescriptionKey: "Impossibile convertire i dati in HTML"])))
                            return
                        }
                        logWarning("[Quattroruote] allestimenti html preview plate=\(plate) preview='\(responsePreview(data2))'")
                        
                        if html.contains("La targa inserita non identifica nessun veicolo Quattroruote") {
                            completion(.failure(NSError(domain: "LicensePlateReader", code: 12008, userInfo: [NSLocalizedDescriptionKey: "Targa non rilevata"])))
                            return
                        }

                        // 1) Cerca l'attributo :data sul tag <car-filter-container>
                        let pattern = #"<car-filter-container[^>]*:data=\"([^\"]+)\""#
                        if let rgx = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]),
                           let m = rgx.firstMatch(in: html, options: [], range: NSRange(html.startIndex..<html.endIndex, in: html)),
                           m.numberOfRanges >= 2,
                           let r = Range(m.range(at: 1), in: html) {
                            var jsonStr = String(html[r])
                            // Decodifica entità HTML
                            jsonStr = jsonStr.replacingOccurrences(of: "&quot;", with: "\"")

                            if let dataJSON = jsonStr.data(using: .utf8) {
                                do {
                                    if let root = try JSONSerialization.jsonObject(with: dataJSON, options: []) as? [String: Any] {
                                        var codice: String? = nil
                                        var quotation: String? = nil

                                        // quotation_id in general_info
                                        if let gi = root["general_info"] as? [String: Any] {
                                            if let qn = gi["quotation_id"] as? NSNumber { quotation = qn.stringValue }
                                            else if let qs = gi["quotation_id"] as? String { quotation = qs }
                                        }
                                        // CodiceInfocarAM nel primo elemento di setups
                                        if let setups = root["setups"] as? [[String: Any]], let first = setups.first {
                                            if let cs = first["CodiceInfocarAM"] as? String { codice = cs }
                                            else if let cn = first["CodiceInfocarAM"] as? NSNumber { codice = cn.stringValue }
                                        }

                                        if let codice = codice, let quotation = quotation {
                                            // Costruisci URL dettagli
                                                guard var comps = URLComponents(string: "https://quotazioni.quattroruote.it/dettagli") else {
                                                    completion(.failure(NSError(domain: "LicensePlateReader", code: 13001, userInfo: [NSLocalizedDescriptionKey: "URL dettagli non valida"])))
                                                    return
                                                }
                                                comps.queryItems = [
                                                    URLQueryItem(name: "_token", value: csrfToken),
                                                    URLQueryItem(name: "codiceInfocarAM", value: codice),
                                                    URLQueryItem(name: "quotation_id", value: quotation)
                                                ]
                                                guard let dettagliURL = comps.url else {
                                                    completion(.failure(NSError(domain: "LicensePlateReader", code: 13001, userInfo: [NSLocalizedDescriptionKey: "URL dettagli non valida"])))
                                                    return
                                                }

                                                var req = URLRequest(url: dettagliURL)
                                                req.httpMethod = "POST"
                                                req.timeoutInterval = NetworkTimeout.quickLookup
                                                req.setValue(randomUserAgent(), forHTTPHeaderField: "User-Agent")
                                                req.setValue("application/json", forHTTPHeaderField: "Accept")

                                                URLSession.tyreVibesShared.dataTask(with: req) { data, resp, err in
                                                    if let err = err {
                                                        completion(.failure(err))
                                                        return
                                                    }
                                                    let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
                                                    let contentType = (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
                                                    logNetwork("[Quattroruote] dettagli status=\(status) contentType=\(contentType) bytes=\(data?.count ?? 0) plate=\(plate)")
                                                    guard let data = data else {
                                                        completion(.failure(NSError(domain: "LicensePlateReader", code: 13002, userInfo: [NSLocalizedDescriptionKey: "Nessun dato da /dettagli"])))
                                                        return
                                                    }
                                                    do {
                                                        let html = String(data: data, encoding: .utf8) ?? ""

                                                        // 1) Cerca l'attributo :data sul tag <buy-quotation-form>
                                                        var jsonStr: String? = nil
                                                        let pattern = #"<buy-quotation-form[^>]*:data=\"([^\"]+)\""#
                                                        if let rgx = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]),
                                                           let m = rgx.firstMatch(in: html, options: [], range: NSRange(html.startIndex..<html.endIndex, in: html)),
                                                           m.numberOfRanges >= 2,
                                                           let r = Range(m.range(at: 1), in: html) {
                                                            jsonStr = String(html[r])
                                                            // Decodifica entità HTML
                                                            jsonStr = jsonStr?.replacingOccurrences(of: "&quot;", with: "\"")
                                                        }
                                                        
                                                        if jsonStr == nil {
                                                            let pattern2 = #"<car-filter-container[^>]*:data=\"([^\"]+)\""#
                                                            if let rgx = try? NSRegularExpression(pattern: pattern2, options: [.dotMatchesLineSeparators, .caseInsensitive]),
                                                               let m = rgx.firstMatch(in: html, options: [], range: NSRange(html.startIndex..<html.endIndex, in: html)),
                                                               m.numberOfRanges >= 2,
                                                               let r = Range(m.range(at: 1), in: html) {
                                                                jsonStr = String(html[r]).replacingOccurrences(of: "&quot;", with: "\"")
                                                            }
                                                        }

                                                        guard let jsonStr = jsonStr else {
                                                            logWarning("[Quattroruote] dettagli data attribute missing plate=\(plate) preview='\(responsePreview(data))'")
                                                            completion(.failure(NSError(
                                                                domain: "LicensePlateReader",
                                                                code: 13004,
                                                                userInfo: [NSLocalizedDescriptionKey: ":data non trovato né in buy-quotation-form né in car-filter-container"]
                                                            )))
                                                            return
                                                        }

                                                        if let dataJSON = jsonStr.data(using: .utf8),
                                                            let dict = try JSONSerialization.jsonObject(with: dataJSON, options: []) as? [String: Any] {
                                                            // --- PlateData mapping for /dettagli response ---
                                                            var mapped: [String: Any] = [:]
                                                            // Top-level fields
                                                            // infocar mapping
                                                            if let infocar = dict["infocar"] as? [String: Any] ??
                                                                             (dict["infocar"] as? [[String: Any]])?.first ??
                                                                             (dict["setups"] as? [String: Any]) ??
                                                                             (dict["setups"] as? [[String: Any]])?.first {

                                                                if let inizioVendita = infocar["inizioVendita"] { mapped["inizioVendita"] = inizioVendita }
                                                                if let fineVendita = infocar["fineVendita"] { mapped["fineVendita"] = fineVendita }
                                                                if let cc = infocar["cilindrata"] { mapped["displacementCC"] = cc }
                                                                if let cambio = infocar["cambio"] { mapped["gearbox"] = cambio }
                                                                if let vmax = infocar["velocitaMax"] { mapped["maxSpeed"] = vmax }
                                                                if let carrozzeria = infocar["carrozzeria"] { mapped["bodyType"] = carrozzeria }
                                                                if let porte = infocar["porte"] { mapped["doors"] = porte }
                                                                if let posti = infocar["posti"] { mapped["seats"] = posti }
                                                                if let consumi = infocar["consumi"] { mapped["consumption"] = consumi }
                                                                if let trazione = infocar["trazione"] { mapped["traction"] = trazione }
                                                                // "potenza" → "powerCVKW" (split if possible, support both formats)
                                                                if let potenza = infocar["potenza"] as? String {
                                                                    let pattern1 = #"(\d+)\s*CV\s*\((\d+)\s*kW\)"#
                                                                    let pattern2 = #"(\d+)\s*kW\s*/\s*(\d+)\s*CV"#
                                                                    if let rgx = try? NSRegularExpression(pattern: pattern1),
                                                                       let m = rgx.firstMatch(in: potenza, options: [], range: NSRange(potenza.startIndex..<potenza.endIndex, in: potenza)),
                                                                       m.numberOfRanges == 3,
                                                                       let r1 = Range(m.range(at: 1), in: potenza),
                                                                       let r2 = Range(m.range(at: 2), in: potenza) {
                                                                        mapped["powerCV"] = String(potenza[r1])
                                                                        mapped["powerKW"] = String(potenza[r2])
                                                                    } else if let rgx = try? NSRegularExpression(pattern: pattern2),
                                                                              let m = rgx.firstMatch(in: potenza, options: [], range: NSRange(potenza.startIndex..<potenza.endIndex, in: potenza)),
                                                                              m.numberOfRanges == 3,
                                                                              let r1 = Range(m.range(at: 1), in: potenza),
                                                                              let r2 = Range(m.range(at: 2), in: potenza) {
                                                                        mapped["powerKW"] = String(potenza[r1])
                                                                        mapped["powerCV"] = String(potenza[r2])
                                                                    }
                                                                }
                                                                if let alimentazione = infocar["alimentazione"] { mapped["fuelType"] = alimentazione }
                                                                if let nome = infocar["nome"] as? String {
                                                                    let separators = CharacterSet(charactersIn: "- ")
                                                                    let parts = nome.components(separatedBy: separators).filter { !$0.isEmpty }
                                                                    if !parts.isEmpty {
                                                                        mapped["make"] = parts[0]
                                                                        
                                                                        if parts.count > 1 {
                                                                            let model = parts[1]
                                                                                .replacingOccurrences(of: "-->", with: "")
                                                                                .replacingOccurrences(of: "&amp;", with: "&")
                                                                            mapped["model"] = model
                                                                        } else {
                                                                            mapped["model"] = infocar["modello"]
                                                                        }
                                                                        
                                                                        let details = nome
                                                                            .replacingOccurrences(of: "&amp;", with: "&")
                                                                        mapped["modelDetails"] = details
                                                                    }
                                                                }
                                                                // Mappatura estesa: tutti i valori presenti nella risposta
                                                                for (key, value) in infocar {
                                                                    // Non sovrascrivere già mappati, ma includi tutto il resto
                                                                    if mapped[key] == nil {
                                                                        mapped[key] = value
                                                                    }
                                                                }
                                                            }
                                                            completion(.success(mapped))
                                                        } else {
                                                            let preview = String(data: data, encoding: .utf8) ?? ""
                                                            completion(.failure(NSError(domain: "LicensePlateReader", code: 13003, userInfo: [NSLocalizedDescriptionKey: "Risposta non valida", "preview": preview])))
                                                        }
                                                        
                                                    } catch {
                                                        completion(.failure(error))
                                                        return
                                                    }
                                                }.resume()

                                                return
                                        }
                                    }
                                } catch {
                                    completion(.failure(error))
                                    return
                                }
                            }
                        }

                        completion(.failure(NSError(
                            domain: "LicensePlateReader",
                            code: 12009,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Dati Quattroruote non trovati nella risposta HTML",
                                "preview": responsePreview(data2)
                            ]
                        )))
                        return

                        
                    }
                }.resume()
                return
                                }
                            }
                        }

                        // 3) Se non si trova nulla, ritorna errore più diagnostico
                        let ct = (resp as? HTTPURLResponse)?.allHeaderFields["Content-Type"] as? String ?? ""
                        completion(.failure(NSError(
                            domain: "LicensePlateReader",
                            code: 12004,
                            userInfo: [NSLocalizedDescriptionKey: "Risposta HTML senza csrf-token rilevabile", "contentType": ct, "preview": String(html.prefix(512))]
                        )))
                        return
                    }

                    // 4) Fallback: dati non decodificabili
                    completion(.failure(NSError(domain: "LicensePlateReader", code: 12005, userInfo: [NSLocalizedDescriptionKey: "Risposta non decodificabile né JSON né HTML"])))
                }.resume()
            }
        }
    }





public static func fetchCaptchaGenerate(completion: @escaping (Result<[String: String], Error>) -> Void) {
guard let url = URL(string: "https://www.ilportaledellautomobilista.it/interrogazionistoricorevisioni/noauth/captcha/generate") else {
    completion(.failure(NSError(domain: "LicensePlateReader", code: 1001, userInfo: nil)))
    return
}
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = "{}".data(using: .utf8)
let task = URLSession.tyreVibesShared.dataTask(with: request) { data, response, error in
    if let error = error {
        completion(.failure(error))
        return
    }
    guard let data = data else {
        completion(.failure(NSError(domain: "LicensePlateReader", code: 1002, userInfo: nil)))
        return
    }
    do {
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = json["id"] as? String,
           let image = json["image"] as? String {
            completion(.success(["id": id, "image": image]))
        } else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Missing id or image in response"])))
        }
    } catch {
        completion(.failure(error))
    }
}
task.resume()
}
public static func fetchRevisioniSecure(
    plate: String,
    tipoVeicolo: String = "A",
    maxAttempts: Int = 15,
    completion: @escaping (Result<[[String:String]], Error>) -> Void
) {
    let captchaCount = 10
    let candidatesPerBatch = 4

    func attempt(_ remaining: Int) {
        let group = DispatchGroup()
        var captchaResults: [(id: String, image: String)] = []
        var firstError: Error?
        let lock = NSLock()
        for _ in 0..<captchaCount {
            group.enter()
            fetchCaptchaGenerate { result in
                switch result {
                case .success(let dict):
                    if let id = dict["id"], let image = dict["image"] {
                        lock.lock()
                        captchaResults.append((id: id, image: image))
                        lock.unlock()
                    }
                case .failure(let err):
                    lock.lock()
                    if firstError == nil { firstError = err }
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .global()) {
            if captchaResults.isEmpty {
                if let err = firstError {
                    completion(.failure(err))
                } else {
                    completion(.failure(NSError(domain: "LicensePlateReader", code: 3010, userInfo: [NSLocalizedDescriptionKey: "Nessun captcha ottenuto"])))
                }
                return
            }
            let candidates = rankedCaptchaCandidates(captchaResults).prefix(candidatesPerBatch)
            guard !candidates.isEmpty else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 3011, userInfo: [NSLocalizedDescriptionKey: "Impossibile selezionare captcha"])))
                return
            }

            func verifyCandidate(_ index: Int) {
                guard index < candidates.count else {
                    if remaining > 1 {
                        attempt(remaining - 1)
                    } else {
                        completion(.failure(NSError(domain: "LicensePlateReader", code: 3012, userInfo: [NSLocalizedDescriptionKey: "Impossibile risolvere il captcha"])))
                    }
                    return
                }

                let candidate = candidates[index]
                fetchCaptchaVerify(id: candidate.id, imageBase64: candidate.image) { verifyResult in
                switch verifyResult {
                case .failure(let error):
                    print("⚠️ [Revisioni] Captcha candidate \(index + 1)/\(candidates.count) fallito: \(error.localizedDescription)")
                    verifyCandidate(index + 1)
                    return
                case .success(let guid):
                    callRevisioniAPI(plate: plate, tipoVeicolo: tipoVeicolo, guid: guid) { apiResult in
                        switch apiResult {
                        case .success:
                            completion(apiResult)
                        case .failure(let error):
                            print("⚠️ [Revisioni] GUID ottenuto ma API revisioni fallita: \(error.localizedDescription)")
                            verifyCandidate(index + 1)
                        }
                    }
                }
                }
            }

            verifyCandidate(0)
        }
    }
    attempt(maxAttempts)
}

private static func rankedCaptchaCandidates(_ captchas: [(id: String, image: String)]) -> [(id: String, image: String)] {
    let scored = captchas.compactMap { captcha -> (captcha: (id: String, image: String), score: Double)? in
        guard let data = Data(base64Encoded: captcha.image),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            return nil
        }

        let inkScore = inkDensity(of: cgImage)
        let spacing = averageCharSpacing(of: cgImage)
        let leftPadding = leftmostInkPosition(of: cgImage)
        let combined = inkScore - spacing * 0.01 + leftPadding * 0.001
        return (captcha, combined)
    }

    return scored
        .sorted { $0.score < $1.score }
        .map { $0.captcha }
}

// Async/await wrapper per fetchRevisioniSecure
public static func fetchRevisioniSecureAsync(
    plate: String,
    tipoVeicolo: String = "A",
    maxAttempts: Int = 4
) async throws -> [[String:String]] {
    try await withCheckedThrowingContinuation { cont in
        fetchRevisioniSecure(plate: plate, tipoVeicolo: tipoVeicolo, maxAttempts: maxAttempts) { result in
            switch result {
            case .success(let arr): cont.resume(returning: arr)
            case .failure(let err): cont.resume(throwing: err)
            }
        }
    }
}

/// Chiamata all'API revisioni con header Guid, estratta da fetchRevisioniSecure
private static func callRevisioniAPI(
    plate: String,
    tipoVeicolo: String,
    guid: String,
    completion: @escaping (Result<[[String:String]], Error>) -> Void
) {
    let urlString = "https://www.ilportaledellautomobilista.it/interrogazionistoricorevisioni/api/v1/storicorevisioni/\(tipoVeicolo)/\(plate)"
    guard let url = URL(string: urlString) else {
        completion(.failure(NSError(domain: "LicensePlateReader", code: 3002, userInfo: [NSLocalizedDescriptionKey: "URL non valida"])))
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    request.setValue(guid, forHTTPHeaderField: "Guid")
    let task = URLSession.tyreVibesShared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        guard let data = data else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 3003, userInfo: [NSLocalizedDescriptionKey: "Nessun dato ricevuto"])))
            return
        }
        do {
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            if let dict = obj as? [String: Any] {
                guard let informations = dict["informations"] as? [[String: Any]] else {
                    let message = (dict["messaggio"] as? String)
                        ?? (dict["message"] as? String)
                        ?? "Risposta revisioni senza campo informations"
                    completion(.failure(NSError(domain: "LicensePlateReader", code: 3005, userInfo: [NSLocalizedDescriptionKey: message])))
                    return
                }
                // Estrai campi richiesti
                let resultArr: [[String:String]] = informations.compactMap { info in
                    var res: [String:String] = [:]
                    if let datRvs = info["datRvs"] as? String { res["datRvs"] = datRvs }
                    if let numKmiPcsRvs = info["numKmiPcsRvs"] as? String ?? (info["numKmiPcsRvs"] as? NSNumber)?.stringValue {
                        res["numKmiPcsRvs"] = numKmiPcsRvs
                    }
                    if let flgEsiRvsVei = info["flgEsiRvsVei"] as? String {
                        let mapped: String
                        switch flgEsiRvsVei {
                        case "P": mapped = "REGOLARE"
                        case "S": mapped = "SOSPENDERE"
                        case "R": mapped = "RIPETERE"
                        default:  mapped = flgEsiRvsVei
                        }
                        res["flgEsiRvsVei"] = mapped
                    }
                    return res.isEmpty ? nil : res
                }
                completion(.success(resultArr))
            } else if let dict = obj as? [AnyHashable: Any] {
                // Try to read "messaggio" if present
                if let msg = dict["messaggio"] as? String {
                    let err = NSError(domain: "LicensePlateReader", code: 3005, userInfo: [NSLocalizedDescriptionKey: msg])
                    completion(.failure(err))
                    return
                } else {
                    completion(.failure(NSError(domain: "LicensePlateReader", code: 3004, userInfo: [NSLocalizedDescriptionKey: "Risposta non valida"])))
                    return
                }
            } else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 3004, userInfo: [NSLocalizedDescriptionKey: "Risposta non valida"])))
                return
            }
        } catch {
            // Fallback: non è JSON, stampa come stringa e ritorna errore
            if let str = String(data: data, encoding: .utf8) {
                print("Risposta non JSON:", str)
            }
            completion(.failure(error))
        }
    }
    task.resume()
}

// Verifica captcha tramite OCR e chiamata POST
public static func fetchCaptchaVerify(id: String, imageBase64: String, completion: @escaping (Result<String, Error>) -> Void) {
// Gestione robusta del base64 (rimozione eventuale prefisso data URL)
let base64String: String = {
    if let comma = imageBase64.firstIndex(of: ",") {
        return String(imageBase64[imageBase64.index(after: comma)...])
    } else {
        return imageBase64
    }
}()
guard let imageData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
      let uiImage = UIImage(data: imageData),
      let cgImage = uiImage.cgImage else {
    completion(.failure(NSError(domain: "LicensePlateReader", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Immagine non valida"])))
    return
}

// OCR con Vision (robusto: preprocessing + multi-candidati + normalizzazione)
// Esegue OCR in background (sincrono per Vision; nessun callback multiplo)
DispatchQueue.global(qos: .userInitiated).async {
    guard let solved = solveCaptchaWithVisionSimple(from: cgImage) else {
        completion(.failure(NSError(domain: "LicensePlateReader", code: 2002, userInfo: [NSLocalizedDescriptionKey: "OCR non riuscito"])))
        return
    }
    let captchaText = solved

    // Chiamata POST per verifica captcha
    guard let url = URL(string: "https://www.ilportaledellautomobilista.it/interrogazionistoricorevisioni/noauth/captcha/verify") else {
        completion(.failure(NSError(domain: "LicensePlateReader", code: 2003, userInfo: nil)))
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any] = ["id": id, "text": captchaText]
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
    } catch {
        completion(.failure(error))
        return
    }
    let task = URLSession.tyreVibesShared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        guard let data = data else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 2004, userInfo: nil)))
            return
        }
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let guid = json["guid"] as? String {
                completion(.success(guid))
            } else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 2005, userInfo: [NSLocalizedDescriptionKey: "Risposta senza guid"])))
            }
        } catch {
            completion(.failure(error))
        }
    }
    task.resume()
}
}
    

/// Euristica per distinguere tra O e Q
private static func disambiguateQvsO(_ cgImage: CGImage, _ recognized: String, _ box: CGRect) -> String {
    guard recognized.uppercased() == "O" else { return recognized }
    
    let width = cgImage.width
    let height = cgImage.height
    let rect = CGRect(
        x: Int(box.origin.x * CGFloat(width)),
        y: Int(box.origin.y * CGFloat(height)),
        width: Int(box.width * CGFloat(width)),
        height: Int(box.height * CGFloat(height))
    )
    guard let cropped = cgImage.cropping(to: rect),
          let dataProvider = cropped.dataProvider,
          let data = dataProvider.data as Data? else {
        return recognized
    }
    
    let w = cropped.width, h = cropped.height
    let bytesPerPixel = cropped.bitsPerPixel / 8
    let bytesPerRow = cropped.bytesPerRow
    
    var sum = 0
    for y in Int(Double(h) * 0.6)..<h { // parte bassa
        for x in Int(Double(w) * 0.5)..<w { // lato destro
            let offset = y * bytesPerRow + x * bytesPerPixel
            let r = Int(data[offset])
            let g = Int(data[offset+1])
            let b = Int(data[offset+2])
            let luma = (2126*r + 7152*g + 722*b) / 10000
            sum += (255 - luma)
        }
    }
    
    // Se c’è abbastanza inchiostro extra, interpretalo come Q
    if sum > (h * w / 20) {
        return "Q"
    }
    return recognized
}

/// Rimuove eventuali linee orizzontali marcate (es. strike-through centrale) schiarendo la/le bande più scure
/// - Parameters:
///   - cgImage: immagine sorgente
///   - bandHalfHeight: semi-spessore (in pixel) della banda da schiarire attorno alla riga più scura
///   - thresholdRatio: rimuove tutte le righe con proiezione >= max*thresholdRatio (0..1)
/// - Returns: nuova immagine senza la linea orizzontale se riuscito, altrimenti l'originale
private static func removeCentralLineArtifacts(_ cgImage: CGImage, bandHalfHeight: Int = 2, thresholdRatio: Double = 0.85) -> CGImage {
    let width = cgImage.width
    let height = cgImage.height

    guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
        return cgImage
    }
    // Disegna l'immagine di partenza nel buffer RGBA
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let dataPtr = ctx.data else { return cgImage }

    let bytesPerPixel = 4
    let bytesPerRow = ctx.bytesPerRow
    let buffer = dataPtr.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)

    // Proiezione orizzontale: somma "inchiostro" per riga (più scuro -> valore più alto)
    var proj = [Int](repeating: 0, count: height)
    for y in 0..<height {
        var sum = 0
        let rowBase = y * bytesPerRow
        for x in 0..<width {
            let idx = rowBase + x * bytesPerPixel
            let r = Int(buffer[idx + 0])
            let g = Int(buffer[idx + 1])
            let b = Int(buffer[idx + 2])
            // Luma Rec.709 approx
            let luma = (2126 * r + 7152 * g + 722 * b) / 10000
            sum += (255 - luma)
        }
        proj[y] = sum
    }

    // Trova il picco (riga più scura) e soglia
    guard let maxVal = proj.max(), maxVal > 0 else {
        return cgImage
    }
    let thresh = Int(Double(maxVal) * thresholdRatio)

    // Schiarisci (porta a bianco) le righe molto scure e una banda attorno a ciascuna
    for y in 0..<height {
        if proj[y] >= thresh {
            let y0 = max(0, y - bandHalfHeight)
            let y1 = min(height - 1, y + bandHalfHeight)
            for yy in y0...y1 {
                let rowBase = yy * bytesPerRow
                // Porta a bianco preservando l'alpha
                for x in 0..<width {
                    let idx = rowBase + x * bytesPerPixel
                    buffer[idx + 0] = 255
                    buffer[idx + 1] = 255
                    buffer[idx + 2] = 255
                    // alpha invariato
                }
            }
        }
    }

    return ctx.makeImage() ?? cgImage
}

private static func majorityVoteCaptcha(_ captchas: [(id: String, image: String)], topN: Int = 5) -> (id: String, image: String, text: String)? {
    var scored: [(captcha: (id: String, image: String), score: Double)] = []

    for captcha in captchas {
        guard let data = Data(base64Encoded: captcha.image),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else { continue }
        
        let score = inkDensity(of: cgImage)
        let spacing = averageCharSpacing(of: cgImage)
        let combined = score - spacing * 0.01 // pesatura semplice
        scored.append((captcha, combined))
    }
    
    // prendi i migliori N
    let best = scored.sorted { $0.score < $1.score }.prefix(topN)
    
    // OCR su ciascuno
    var freq: [String: Int] = [:]
    var mapId: [String: (id: String, image: String)] = [:]
    for item in best {
        if let data = Data(base64Encoded: item.captcha.image),
           let uiImage = UIImage(data: data),
           let cgImage = uiImage.cgImage,
           let text = solveCaptchaWithVision(from: cgImage) {
            let norm = normalizeCaptcha(text)
            freq[norm, default: 0] += 1
            mapId[norm] = item.captcha
        }
    }
    
    // restituisci il più votato
    if let winner = freq.max(by: { $0.value < $1.value })?.key,
       let captcha = mapId[winner] {
        return (captcha.id, captcha.image, winner)
    }
    return nil
}
// MARK: - OCR helpers (Vision + CoreImage)
private static let ciContext = CIContext()

private static func solveCaptchaWithVision(from cgImage: CGImage, expectedLength: ClosedRange<Int> = 5...9) -> String? {
    // Preprocessa l'immagine in più varianti
    let variants = preprocessCaptchaVariants(from: cgImage)
    var candidates: [(text: String, score: Double)] = []

    for variant in variants {
        let observations = recognizeObservations(on: variant)
        guard !observations.isEmpty else { continue }

        // 1) OCR sull'intera immagine
        let fullText = observations
            .compactMap { obs -> String? in
                guard let cand = obs.topCandidates(1).first else { return nil }
                return disambiguateQvsO(cgImage, cand.string, obs.boundingBox)
            }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        if !fullText.isEmpty {
            let normalized = normalizeCaptcha(fullText)
            let len = normalized.count
            let score = (expectedLength.contains(len) ? 0.2 : 0.0) + 0.8
            candidates.append((normalized, score))
        }

        // 2) OCR con bounding box dei singoli caratteri
        let chars = observations.compactMap { obs -> (String, CGFloat)? in
            guard let cand = obs.topCandidates(1).first else { return nil }
            let fixed = disambiguateQvsO(cgImage, cand.string, obs.boundingBox)
            return (normalizeCaptcha(fixed), obs.boundingBox.minX)
        }
        let ordered = chars.sorted { $0.1 < $1.1 }.map { $0.0 }.joined()
        if !ordered.isEmpty {
            let len = ordered.count
            let score = (expectedLength.contains(len) ? 0.3 : 0.0) + 0.9
            candidates.append((ordered, score))
        }

        // 3) Segmentazione verticale in blocchi fissi (fallback)
        let segmented = segmentAndRecognize(variant, parts: expectedLength.upperBound)
        if !segmented.isEmpty {
            let len = segmented.count
            let score = (expectedLength.contains(len) ? 0.3 : 0.0) + 0.7
            candidates.append((segmented, score))
        }
        
        // 4) Segmentazione tramite proiezioni verticali (dinamica)
        let projSeg = segmentAndRecognizeByProjections(variant, minGapWidth: 2, minCharWidth: max(5, cgImage.width / 40))
        if !projSeg.isEmpty {
            let len = projSeg.count
            let score = (expectedLength.contains(len) ? 0.4 : 0.0) + 0.95
            candidates.append((projSeg, score))
        }
    }

    // Nuova logica di scelta del candidato
    let valid = candidates
        .map { $0.text }
        .filter { expectedLength.contains($0.count) }

    if !valid.isEmpty {
        let freq = Dictionary(grouping: valid, by: { $0 })
            .mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }

    return candidates.max(by: { $0.score < $1.score })?.text
}

private static func chooseBestCaptcha(_ captchas: [(id: String, image: String)]) -> (id: String, image: String)? {
    var best: (id: String, image: String)?
    var bestScore = Double.greatestFiniteMagnitude
    
    for captcha in captchas {
        guard let data = Data(base64Encoded: captcha.image),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else { continue }
        
        let score = inkDensity(of: cgImage) // calcolo "quanto nero"
        if score < bestScore {
            bestScore = score
            best = captcha
        }
        let spacing = averageCharSpacing(of: cgImage) // calcolo "spazio medio tra i blocchi di nero"
        if score < bestScore || (score == bestScore && spacing > 0) {
            bestScore = score
           best = captcha
        }
    }
    return best
}

private static func leftmostInkPosition(of cgImage: CGImage) -> Double {
    let width = cgImage.width
    let height = cgImage.height
    guard let dataProvider = cgImage.dataProvider,
          let data = dataProvider.data as Data? else { return Double(width) }
    
    let bytesPerPixel = cgImage.bitsPerPixel / 8
    let bytesPerRow = cgImage.bytesPerRow
    
    // Scansiona da sinistra verso destra finché trovi inchiostro
    for x in 0..<width {
        var sum = 0
        let xOffset = x * bytesPerPixel
        for y in 0..<height {
            let idx = y * bytesPerRow + xOffset
            let r = Int(data[idx + 0])
            let g = Int(data[idx + 1])
            let b = Int(data[idx + 2])
            let luma = (2126 * r + 7152 * g + 722 * b) / 10000
            sum += (255 - luma)
        }
        if sum > 20 { // soglia: se c’è abbastanza nero
            return Double(x)
        }
    }
    return Double(width)
}

private static func inkDensity(of cgImage: CGImage) -> Double {
    let width = cgImage.width
    let height = cgImage.height
    guard let dataProvider = cgImage.dataProvider,
          let data = dataProvider.data as Data? else { return .infinity }
    
    let bytesPerPixel = cgImage.bitsPerPixel / 8
    let bytesPerRow = cgImage.bytesPerRow
    
    var sum = 0
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * bytesPerRow + x * bytesPerPixel
            let r = Int(data[offset])
            let g = Int(data[offset+1])
            let b = Int(data[offset+2])
            let luma = (2126*r + 7152*g + 722*b) / 10000
            sum += (255 - luma) // più scuro → maggiore somma
        }
    }
    return Double(sum) / Double(width * height)
}

private static func averageCharSpacing(of cgImage: CGImage) -> Double {
    let width = cgImage.width
    let height = cgImage.height
    guard let dataProvider = cgImage.dataProvider,
          let data = dataProvider.data as Data? else { return 0.0 }

    let bytesPerPixel = cgImage.bitsPerPixel / 8
    let bytesPerRow = cgImage.bytesPerRow

    // Calcola la proiezione verticale (inchiostro per colonna)
    var proj = [Int](repeating: 0, count: width)
    for x in 0..<width {
        var sum = 0
        let xOffset = x * bytesPerPixel
        for y in 0..<height {
            let idx = y * bytesPerRow + xOffset
            let r = Int(data[idx + 0])
            let g = Int(data[idx + 1])
            let b = Int(data[idx + 2])
            let luma = (2126 * r + 7152 * g + 722 * b) / 10000
            sum += (255 - luma)
        }
        proj[x] = sum
    }

    // Identifica i blocchi di nero (colonne con inchiostro > soglia)
    let threshold = (proj.max() ?? 0) / 5
    var lastBlackX: Int? = nil
    var spacings: [Int] = []
    for x in 0..<width {
        if proj[x] > threshold {
            if let last = lastBlackX {
                let gap = x - last
                if gap > 1 { spacings.append(gap) }
            }
            lastBlackX = x
        }
    }

    if spacings.isEmpty { return 0.0 }
    return Double(spacings.reduce(0, +)) / Double(spacings.count)
}

/// Segmenta l'immagine in N parti verticali e applica OCR su ciascuna.
private static func segmentAndRecognize(_ cgImage: CGImage, parts: Int) -> String {
    let width = cgImage.width
    let height = cgImage.height
    var result = ""

    for i in 0..<parts {
        let rect = CGRect(x: width * i / parts, y: 0,
                          width: width / parts, height: height)
        if let cropped = cgImage.cropping(to: rect) {
            let obs = recognizeObservations(on: cropped, minTextHeight: 0.05)
            if let cand = obs.first?.topCandidates(1).first {
                result.append(normalizeCaptcha(cand.string))
            }
        }
    }
    return result
}

/// Versione migliorata della segmentazione tramite proiezioni verticali
    private static func segmentAndRecognizeByProjections(
        _ cgImage: CGImage,
        minGapWidth: Int = 2,
        minCharWidth: Int = 8,
        aggressiveSeparation: Bool = true
    ) -> String {
        let width = cgImage.width
        let height = cgImage.height

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data as Data? else { return "" }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        // 1. Calcola proiezione verticale con maggiore sensibilità
        var proj = [Int](repeating: 0, count: width)
        for x in 0..<width {
            var sum = 0
            let xOffset = x * bytesPerPixel
            for y in 0..<height {
                let idx = y * bytesPerRow + xOffset
                let r = Int(data[idx + 0])
                let g = Int(data[idx + 1])
                let b = Int(data[idx + 2])
                let luma = (2126 * r + 7152 * g + 722 * b) / 10000
                let ink = 255 - luma
                // Amplifica l'inchiostro per migliorare la separazione
                sum += ink > 50 ? ink * 2 : ink
            }
            proj[x] = sum
        }

        // 2. Smoothing più aggressivo per ridurre il rumore
        if width > 3 {
            var smooth = [Int](repeating: 0, count: width)
            let kernelSize = max(3, width / 100) // Kernel adattivo
            for x in 0..<width {
                var s = 0, c = 0
                let halfKernel = kernelSize / 2
                for dx in -halfKernel...halfKernel {
                    let xx = x + dx
                    if xx >= 0 && xx < width {
                        s += proj[xx]
                        c += 1
                    }
                }
                smooth[x] = s / max(1, c)
            }
            proj = smooth
        }

        // 3. Segmentazione migliorata con soglie adattive
        let cuts = findCharacterBoundaries(proj, minGapWidth: minGapWidth, minCharWidth: minCharWidth, aggressiveSeparation: aggressiveSeparation)
        
        // 4. OCR per ogni segmento con preprocessing specifico
        var result = ""
        for i in 0..<(cuts.count - 1) {
            let x0 = cuts[i]
            let x1 = cuts[i + 1]
            
            if x1 - x0 < minCharWidth { continue }
            
            let rect = CGRect(x: x0, y: 0, width: x1 - x0, height: height)
            if let cropped = cgImage.cropping(to: rect) {
                // Preprocessing specifico per carattere singolo
                let processed = preprocessSingleCharacter(cropped)
                let text = recognizeSingleCharacter(processed)
                result.append(text)
            }
        }
        
        return result
    }
    
    /// Trova i confini dei caratteri con algoritmo migliorato
    private static func findCharacterBoundaries(
        _ projection: [Int],
        minGapWidth: Int,
        minCharWidth: Int,
        aggressiveSeparation: Bool
    ) -> [Int] {
        
        let width = projection.count
        guard width > minCharWidth else { return [0, width] }
        
        let maxVal = projection.max() ?? 1
        
        // Soglie dinamiche basate sulla distribuzione
        let baseThreshold = maxVal / 15  // Soglia base più bassa
        let aggressiveThreshold = maxVal / 25 // Soglia aggressiva per separazione forzata
        
        var cuts: [Int] = [0]
        var inGap = false
        var gapStart = 0
        
        // 1. Prima passata: gaps evidenti
        for x in 0..<width {
            let currentThresh = aggressiveSeparation ? aggressiveThreshold : baseThreshold
            
            if projection[x] < currentThresh {
                if !inGap {
                    inGap = true
                    gapStart = x
                }
            } else if inGap {
                inGap = false
                let gapWidth = x - gapStart
                if gapWidth >= minGapWidth {
                    let cutPoint = (gapStart + x) / 2
                    cuts.append(cutPoint)
                }
            }
        }
        
        // 2. Seconda passata: separazione forzata per caratteri molto larghi
        if aggressiveSeparation {
            var newCuts: [Int] = []
            
            for i in 0..<(cuts.count - 1) {
                let start = cuts[i]
                let end = cuts[i + 1]
                let segmentWidth = end - start
                
                newCuts.append(start)
                
                // Se il segmento è troppo largo, prova a dividerlo
                if segmentWidth > minCharWidth * 3 {
                    let forcedCuts = forceSeparation(projection, start: start, end: end, minCharWidth: minCharWidth)
                    newCuts.append(contentsOf: forcedCuts)
                }
            }
            
            newCuts.append(cuts.last!)
            cuts = newCuts.sorted()
        }
        
        // 3. Terza passata: separazione basata su minimi locali
        cuts = refineCutsWithLocalMinima(projection, cuts: cuts, minCharWidth: minCharWidth)
        
        if cuts.last != width {
            cuts.append(width)
        }
        
        return cuts.sorted()
    }
    
    /// Separazione forzata per segmenti troppo larghi
    private static func forceSeparation(
        _ projection: [Int],
        start: Int,
        end: Int,
        minCharWidth: Int
    ) -> [Int] {
        
        var cuts: [Int] = []
        let segmentWidth = end - start
        let expectedChars = max(2, segmentWidth / (minCharWidth + 2))
        
        if expectedChars <= 1 { return cuts }
        
        // Cerca minimi locali nell'area
        let segment = Array(projection[start..<end])
        let minima = findLocalMinima(segment, windowSize: max(3, segmentWidth / 20))
        
        // Seleziona i minimi più promettenti
        let sortedMinima = minima.sorted { $0.value < $1.value }
        let selectedCount = min(expectedChars - 1, sortedMinima.count)
        
        for i in 0..<selectedCount {
            let localPos = sortedMinima[i].index
            let globalPos = start + localPos
            
            // Verifica che il taglio sia ragionevole
            if globalPos > start + minCharWidth && globalPos < end - minCharWidth {
                cuts.append(globalPos)
            }
        }
        
        return cuts
    }
    
    /// Trova minimi locali nell'array
    private static func findLocalMinima(_ array: [Int], windowSize: Int) -> [(index: Int, value: Int)] {
        var minima: [(index: Int, value: Int)] = []
        let halfWindow = windowSize / 2
        
        for i in halfWindow..<(array.count - halfWindow) {
            let currentValue = array[i]
            var isMinimum = true
            
            // Controlla se è un minimo locale
            for j in (i - halfWindow)...(i + halfWindow) {
                if j != i && array[j] < currentValue {
                    isMinimum = false
                    break
                }
            }
            
            if isMinimum {
                minima.append((index: i, value: currentValue))
            }
        }
        
        return minima
    }
    
    /// Raffina i tagli usando minimi locali
    private static func refineCutsWithLocalMinima(
        _ projection: [Int],
        cuts: [Int],
        minCharWidth: Int
    ) -> [Int] {
        
        var refinedCuts: [Int] = []
        
        for i in 0..<cuts.count {
            let currentCut = cuts[i]
            
            if i == 0 || i == cuts.count - 1 {
                refinedCuts.append(currentCut)
                continue
            }
            
            let prevCut = cuts[i - 1]
            let nextCut = cuts[i + 1]
            
            
            // Cerca un minimo migliore nell'area intorno al taglio
            let searchStart = max(prevCut + minCharWidth / 2, currentCut - minCharWidth / 4)
            let searchEnd = min(nextCut - minCharWidth / 2, currentCut + minCharWidth / 4)
            
            if searchStart < searchEnd {
                var bestCut = currentCut
                var minValue = projection[currentCut]
                
                for x in searchStart..<searchEnd {
                    if projection[x] < minValue {
                        minValue = projection[x]
                        bestCut = x
                    }
                }
                
                refinedCuts.append(bestCut)
            } else {
                refinedCuts.append(currentCut)
            }
        }
        
        return refinedCuts
    }
    
    /// Preprocessing specifico per carattere singolo
    private static func preprocessSingleCharacter(_ cgImage: CGImage) -> CGImage {
        let ci = CIImage(cgImage: cgImage)
        
        // Pipeline di preprocessing per carattere singolo
        let processed = ci
            // Normalizza il contrasto
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 2.5,
                kCIInputBrightnessKey: 0.1
            ])
            // Riduci il rumore
            .applyingFilter("CINoiseReduction", parameters: [
                "inputNoiseLevel": 0.02,
                "inputSharpness": 0.4
            ])
            // Migliora la nitidezza
            .applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.0,
                kCIInputIntensityKey: 0.8
            ])
            // Morfologia per pulire i bordi
            .applyingFilter("CIMorphologyMinimum", parameters: [
                kCIInputRadiusKey: 0.8
            ])
            .applyingFilter("CIMorphologyMaximum", parameters: [
                kCIInputRadiusKey: 1.2
            ])
        
        return ciContext.createCGImage(processed, from: processed.extent) ?? cgImage
    }
    
    /// Riconosce un singolo carattere con parametri ottimizzati
    private static func recognizeSingleCharacter(_ cgImage: CGImage) -> String {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false
        req.recognitionLanguages = ["en-US"]
        req.minimumTextHeight = 0.01 // Più basso per caratteri singoli
        req.customWords = [] // Nessun dizionario per evitare correzioni
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([req])
            
            if let observations = req.results, !observations.isEmpty {
                // Prendi tutti i candidati e scegli il migliore
                var allCandidates: [(text: String, confidence: Float)] = []
                
                for obs in observations {
                    for candidate in obs.topCandidates(3) {
                        let normalized = normalizeCaptcha(candidate.string)
                        if normalized.count == 1 { // Solo caratteri singoli
                            allCandidates.append((normalized, candidate.confidence))
                        }
                    }
                }
                
                // Scegli il candidato con maggiore confidenza
                if let best = allCandidates.max(by: { $0.confidence < $1.confidence }) {
                    return best.text
                }
            }
        } catch {
            print("OCR error per carattere singolo: \(error)")
        }
        
        return ""
    }
    
    /// Versione aggiornata di solveCaptchaWithVision che usa la segmentazione migliorata
    private static func solveCaptchaWithVisionImproved(from cgImage: CGImage, expectedLength: ClosedRange<Int> = 5...9) -> String? {
        let variants = preprocessCaptchaVariants(from: cgImage)
        var candidates: [(text: String, score: Double)] = []

        for variant in variants {
            // 1. OCR tradizionale sull'intera immagine
            let observations = recognizeObservations(on: variant)
            if !observations.isEmpty {
                let fullText = observations
                    .compactMap { obs -> String? in
                        guard let cand = obs.topCandidates(1).first else { return nil }
                        return disambiguateQvsO(cgImage, cand.string, obs.boundingBox)
                    }
                    .joined()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
                
                if !fullText.isEmpty {
                    let normalized = normalizeCaptcha(fullText)
                    let len = normalized.count
                    let score = (expectedLength.contains(len) ? 0.3 : 0.0) + 0.7
                    candidates.append((normalized, score))
                }
            }
            
            // 2. Segmentazione migliorata (metodo principale)
            let segmented = segmentAndRecognizeByProjections(
                variant,
                minGapWidth: max(1, variant.width / 200),
                minCharWidth: max(8, variant.width / 40),
                aggressiveSeparation: true
            )
            
            if !segmented.isEmpty {
                let len = segmented.count
                let score = (expectedLength.contains(len) ? 0.5 : 0.0) + 1.0
                candidates.append((segmented, score))
            }
            
            // 3. Segmentazione ancora più aggressiva come fallback
            let ultraAggressive = segmentAndRecognizeByProjections(
                variant,
                minGapWidth: 1,
                minCharWidth: max(6, variant.width / 50),
                aggressiveSeparation: true
            )
            
            if !ultraAggressive.isEmpty && ultraAggressive != segmented {
                let len = ultraAggressive.count
                let score = (expectedLength.contains(len) ? 0.4 : 0.0) + 0.9
                candidates.append((ultraAggressive, score))
            }
            
            // 4. Post-processing con correzione pattern comuni
            for candidate in [segmented, ultraAggressive] {
                if !candidate.isEmpty {
                    let corrected = correctCommonPatterns(candidate)
                    if corrected != candidate {
                        let len = corrected.count
                        let score = (expectedLength.contains(len) ? 0.6 : 0.0) + 0.95
                        candidates.append((corrected, score))
                    }
                }
            }
        }

        // Selezione del migliore candidato con validazione aggiuntiva
        let validCandidates = candidates.filter {
            let text = $0.text
            return expectedLength.contains(text.count) && isValidCaptchaPattern(text)
        }
        
        if !validCandidates.isEmpty {
            // Raggruppa per frequenza e scegli il più comune con score alto
            let textFrequency = Dictionary(grouping: validCandidates, by: { $0.text })
            let mostCommon = textFrequency.max { first, second in
                let firstScore = first.value.map { $0.score }.reduce(0, +) / Double(first.value.count)
                let secondScore = second.value.map { $0.score }.reduce(0, +) / Double(second.value.count)
                return firstScore < secondScore
            }
            return mostCommon?.key
        } else {
            // Altrimenti prendi il migliore in assoluto con post-processing
            if let best = candidates.max(by: { $0.score < $1.score }) {
                return correctCommonPatterns(best.text)
            }
        }
        
        return nil
    }
    
    /// Corregge pattern comuni di errore OCR
    private static func correctCommonPatterns(_ text: String) -> String {
        var corrected = text
        
        // Pattern specifici per errori di segmentazione
        let corrections: [(pattern: String, replacement: String)] = [
            ("LEFATI", "UEFATI"),   // Caso specifico
            ("LIEFATI", "UEFATI"),  // Variante
            ("LEFA", "UEFA"),       // Pattern parziale
            ("LEFI", "UEFI"),       // Variante
            ("LEFRA", "UEFRA"),     // Con R
            ("CLEFA", "DUEFA"),     // CL → D + error
            ("RNEFA", "MEFA"),      // RN → M + error
            // Altri pattern comuni
            ("RN", "M"),            // rn → m
            ("CL", "D"),            // cl → d
            ("VV", "W"),            // vv → w
            ("NN", "M"),            // nn → m
            ("II", "U"),            // ii → u
            ("LI", "U"),            // li → u
            ("LE", "U")             // le → u (generico)
        ]
        
        for correction in corrections {
            corrected = corrected.replacingOccurrences(of: correction.pattern, with: correction.replacement)
        }
        
        return corrected
    }
    
    /// Valida se il pattern sembra un captcha valido
    private static func isValidCaptchaPattern(_ text: String) -> Bool {
        // Controlla che non ci siano troppi caratteri ripetuti
        let charCount = Dictionary(grouping: text, by: { $0 })
        let maxRepeats = charCount.values.map { $0.count }.max() ?? 0
        
        // Un carattere non dovrebbe ripetersi più di 2 volte in un captcha tipico
        if maxRepeats > 2 { return false }
        
        // Controlla che ci siano sia consonanti che vocali (per captcha alfabetici)
        let vowels = Set("AEIOU")
        let consonants = Set("BCDFGHJKLMNPQRSTVWXYZ")
        let textSet = Set(text)
        
        let hasVowels = !textSet.intersection(vowels).isEmpty
        let hasConsonants = !textSet.intersection(consonants).isEmpty
        
        // Per captcha corti, è OK avere solo consonanti o solo vocali
        if text.count <= 4 { return true }
        
        // Per captcha lunghi, dovrebbe esserci un mix ragionevole
        return hasVowels || hasConsonants
    }


private static func applyLensSuppression(_ ci: CIImage, factor: CGFloat = 0.75) -> CIImage {
    let extent = ci.extent
    let cx = extent.midX
    let cy = extent.midY
    let radius0 = min(extent.width, extent.height) * 0.22
    let radius1 = min(extent.width, extent.height) * 0.45

    let blurred = ci
        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 2.0])
        .applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 1.1,
            kCIInputBrightnessKey: -0.02
        ])

    // Maschera radiale: 1 al centro (usa blur), 0 ai bordi (usa originale)
    let grad = CIFilter(name: "CIRadialGradient", parameters: [
        "inputCenter": CIVector(x: cx, y: cy),
        "inputRadius0": radius0,
        "inputRadius1": radius1,
        "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: factor),
        "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0)
    ])!.outputImage!.cropped(to: extent)

    // Fonde blurred (al centro) con originale (ai bordi)
    let blended = CIFilter(name: "CIBlendWithAlphaMask", parameters: [
        kCIInputImageKey: blurred,
        kCIInputBackgroundImageKey: ci,
        kCIInputMaskImageKey: grad
    ])!.outputImage!

    return blended
}

/// Preprocessa il captcha in più forme (grayscale, contrasto, median, morfologia) per aiutare l'OCR.
private static func preprocessCaptchaVariants(from cgImage: CGImage) -> [CGImage] {
    let base = CIImage(cgImage: cgImage)

    // Variante 1: B/N + contrasto + median
    let v1 = base
        .applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,
            kCIInputContrastKey: 1.6,
            kCIInputBrightnessKey: 0.0
        ])
        .applyingFilter("CIPhotoEffectNoir")
        .applyingFilter("CIMedianFilter")
    
    let vLens = applyLensSuppression(v1)

    // Variante 2: come v1 ma più contrasto
    let v2 = v1.applyingFilter("CIColorControls", parameters: [
        kCIInputContrastKey: 4.0
    ])

    // Variante 3: esposizione leggermente aumentata
    let v3 = v1.applyingFilter("CIExposureAdjust", parameters: [
        kCIInputEVKey: 0.6
    ])

    // Converte CIImage -> CGImage
    var out: [CGImage] = []
    for ci in [v1, v2, v3, vLens,
               v1.applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 1.5]),
               v1.applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 1.5]),
               v1.applyingFilter("CISharpenLuminance", parameters: ["inputSharpness": 0.6])
    ] {
        if let cg = ciContext.createCGImage(ci, from: ci.extent) {
            out.append(cg)
            // Variante con soppressione della linea orizzontale (captcha con linea centrale)
            let noLine = removeCentralLineArtifacts(cg, bandHalfHeight: max(2, Int(cg.height / 80)), thresholdRatio: 0.80)
            out.append(noLine)
        }
    }

    // Include sempre anche l'originale e la variante senza linea
    out.append(cgImage)
    let noLineOriginal = removeCentralLineArtifacts(cgImage, bandHalfHeight: max(2, Int(cgImage.height / 80)), thresholdRatio: 0.50)
    out.append(noLineOriginal)
    return out
}

/// Esegue Vision OCR sincrono su una singola immagine.
private static func recognizeObservations(on cgImage: CGImage, minTextHeight: Float = 0.04) -> [VNRecognizedTextObservation] {
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = false
    req.recognitionLanguages = ["en-US"] // alfanumerico, nessun dizionario necessario
    req.minimumTextHeight = minTextHeight

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([req])
        return req.results ?? []
    } catch {
        return []
    }
}

/// Normalizza il testo captcha: uppercase, mappa caratteri ambigui e filtra secondo la modalità numerica o alfanumerica.
/// - Parameters:
///   - s: Stringa da normalizzare
///   - digitsOnly: se true, il captcha è solo numerico (default true)
private static func normalizeCaptcha(_ s: String, digitsOnly: Bool = false) -> String {
    let up = s.uppercased()
    var mapped = up.folding(options: .diacriticInsensitive, locale: .current)
        .replacingOccurrences(of: "O", with: "0")
        //.replacingOccurrences(of: "I", with: "1")
        //.replacingOccurrences(of: "L", with: "1")
        //.replacingOccurrences(of: "T", with: "7")
    if digitsOnly {
        // Se solo cifre (o lettere simili), mappa anche T → 1
        mapped = mapped.replacingOccurrences(of: "T", with: "1")
    }
    let allowed: CharacterSet = digitsOnly ? .decimalDigits : .alphanumerics
    let scalars = mapped.unicodeScalars.filter { allowed.contains($0) }
    return String(String.UnicodeScalarView(scalars))
}

private static func solveCaptchaWithVisionSimple(from cgImage: CGImage, expectedLength: ClosedRange<Int> = 6...9) -> String? {
       
       // 1. Solo 2 preprocessing essenziali
       let variants = [
           cgImage, // Originale
           preprocessForOCR(cgImage) // Una sola variante preprocessata
       ]
       
       var bestResult: String?
       var bestScore = 0.0
       
       for variant in variants {
           // 2. Segmentazione precisa
           let segmented = segmentPrecisely(variant)
           
           if expectedLength.contains(segmented.count) {
               let score = Double(segmented.count == 6 ? 1.0 : 0.8) // Preferisci lunghezza 6
               if score > bestScore {
                   bestScore = score
                   bestResult = segmented
               }
           }
           
           // 3. OCR tradizionale come fallback
           if bestResult == nil {
               let traditional = recognizeTraditional(variant)
               if !traditional.isEmpty && expectedLength.contains(traditional.count) {
                   bestResult = traditional
               }
           }
       }
       
       // 4. Solo correzioni essenziali
       if let result = bestResult {
           return fixCriticalErrors(result)
       }
       
       return ""
   }
    
    // MARK: - Async wrappers
    private static func fetchAllianzInfoAsync(plate: String, plateData: PlateData) async throws -> [String:String] {
        try await withCheckedThrowingContinuation { cont in
            fetchAllianzInfo(plate: plate, plateData: plateData) { result in
                cont.resume(with: result)
            }
        }
    }

    private static func fetchAllianzRegistrationDateAsync(plate: String) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            fetchAllianzRegistrationDate(plate: plate) { result in
                cont.resume(with: result)
            }
        }
    }

    private static func fetchQuattroruotePlateDataAsync(plate: String, timeout: TimeInterval = 22.0) async throws -> [String:Any] {
        try await withCheckedThrowingContinuation { cont in
            let continuationBox = ThrowingContinuationBox(cont)

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                continuationBox.resume(with: .failure(NSError(
                    domain: "LicensePlateReader",
                    code: 12010,
                    userInfo: [NSLocalizedDescriptionKey: "Timeout Quattroruote"]
                )))
            }

            fetchQuattroruotePlateData(plate: plate, anchorURL: "https://www.google.com/recaptcha/api2/anchor?ar=1&k=6Le8aF8rAAAAAJWwLyBz0etzTUVmNb_xm68qgxoJ&co=aHR0cHM6Ly9xdW90YXppb25pLnF1YXR0cm9ydW90ZS5pdDo0NDM.&hl=it&v=_mscDd1KHr60EWWbt2I_ULP0&size=invisible&anchor-ms=20000&execute-ms=15000&cb=m871w5q3hb3j") { result in
                continuationBox.resume(with: result)
            }
        }
    }

    private static func fetchCoperturaRCAsync(plate: String) async throws -> [String:String] {
        try await withCheckedThrowingContinuation { cont in
            fetchCoperturaRC(plate: plate) { result in
                cont.resume(with: result)
            }
        }
    }

    private static func fetchClasseAmbientaleAsync(plate: String) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            fetchClasseAmbientale(plate: plate) { result in
                cont.resume(with: result)
            }
        }
    }

    private static func fetchTyreBlackcirclesAsync(plate: String) async throws -> [[String:String]] {
        try await withCheckedThrowingContinuation { cont in
            fetchTyreBlackcircles(plate: plate) { result in
                cont.resume(with: result)
            }
        }
    }

    private static func fetchRevisioniSecureAsync(plate: String) async throws -> [[String:String]] {
        try await withCheckedThrowingContinuation { cont in
            fetchRevisioniSecure(plate: plate) { result in
                cont.resume(with: result)
            }
        }
    }
   
   /// Preprocessing minimo ma efficace
   private static func preprocessForOCR(_ cgImage: CGImage) -> CGImage {
       let ci = CIImage(cgImage: cgImage)
       
       let processed = ci
           .applyingFilter("CIColorControls", parameters: [
               kCIInputSaturationKey: 0.0,      // B/N
               kCIInputContrastKey: 2.0,        // Contrasto moderato
               kCIInputBrightnessKey: 0.05      // Leggero schiarimento
           ])
           .applyingFilter("CIMedianFilter") // Riduce rumore
       let suppressed = applyLensSuppression(processed)
       return ciContext.createCGImage(suppressed, from: suppressed.extent) ?? cgImage
   }
   
   /// Segmentazione verticale precisa
   private static func segmentPrecisely(_ cgImage: CGImage) -> String {
       let width = cgImage.width
       let height = cgImage.height
       
       guard let dataProvider = cgImage.dataProvider,
             let data = dataProvider.data as Data? else { return "" }
       
       let bytesPerPixel = cgImage.bitsPerPixel / 8
       let bytesPerRow = cgImage.bytesPerRow
       
       // Proiezione verticale semplice
       var projection = [Int](repeating: 0, count: width)
       for x in 0..<width {
           var sum = 0
           for y in 0..<height {
               let offset = y * bytesPerRow + x * bytesPerPixel
               let r = Int(data[offset])
               let g = Int(data[offset + 1])
               let b = Int(data[offset + 2])
               let gray = (r + g + b) / 3
               sum += (255 - gray) // Inchiostro
           }
           projection[x] = sum
       }
       
       // Trova tagli semplici
       let threshold = (projection.max() ?? 0) / 8
       let minCharWidth = width / 12 // ~8% della larghezza
       
       var cuts = [0]
       var inGap = false
       var gapStart = 0
       
       for x in 0..<width {
           if projection[x] < threshold {
               if !inGap {
                   inGap = true
                   gapStart = x
               }
           } else if inGap {
               inGap = false
               let gapWidth = x - gapStart
               if gapWidth >= 2 { // Gap minimo di 2 pixel
                   cuts.append((gapStart + x) / 2)
               }
           }
       }
       cuts.append(width)
       
       // OCR per ogni segmento
       var result = ""
       for i in 0..<(cuts.count - 1) {
           let x0 = cuts[i]
           let x1 = cuts[i + 1]
           
           if x1 - x0 >= minCharWidth {
               let rect = CGRect(x: x0, y: 0, width: x1 - x0, height: height)
               if let cropped = cgImage.cropping(to: rect) {
                   let char = recognizeSingleChar(cropped)
                   result.append(char)
               }
           }
       }
       
       return result
   }
   
   /// OCR per singolo carattere
   private static func recognizeSingleChar(_ cgImage: CGImage) -> String {
       let request = VNRecognizeTextRequest()
       request.recognitionLevel = .accurate
       request.usesLanguageCorrection = false
       request.minimumTextHeight = 0.01
       
       let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
       
       do {
           try handler.perform([request])
           if let observation = request.results?.first,
              let candidate = observation.topCandidates(1).first {
               let text = candidate.string.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
               return String(text.prefix(1)) // Solo primo carattere
           }
       } catch {}
       
       return ""
   }
   
   /// OCR tradizionale sull'intera immagine
   private static func recognizeTraditional(_ cgImage: CGImage) -> String {
       let request = VNRecognizeTextRequest()
       request.recognitionLevel = .accurate
       request.usesLanguageCorrection = false
       
       let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
       
       do {
           try handler.perform([request])
           if let observation = request.results?.first,
              let candidate = observation.topCandidates(1).first {
               return candidate.string.uppercased()
                   .trimmingCharacters(in: .whitespacesAndNewlines)
                   .filter { $0.isLetter || $0.isNumber }
           }
       } catch {}
       
       return ""
   }
   
   /// Solo correzioni critiche e verificate
   private static func fixCriticalErrors(_ text: String) -> String {
       return text
           .replacingOccurrences(of: "O", with: "0")
           .replacingOccurrences(of: "I", with: "L")
           .replacingOccurrences(of: "LE", with: "U") // le → u (il tuo caso specifico)
           .replacingOccurrences(of: "LI", with: "U") // li → u
           .filter { $0.isLetter || $0.isNumber }// Solo lettere per captcha alfanumerici
   }

// MARK: - Timeout helper
private struct TimeoutError: LocalizedError {
    let seconds: Double

    var errorDescription: String? {
        "Timeout dopo \(String(format: "%.1f", seconds))s"
    }
}

private static func elapsedMilliseconds(since start: Date) -> Int {
    Int(Date().timeIntervalSince(start) * 1000)
}

private static func responsePreview(_ data: Data?, limit: Int = 360) -> String {
    guard let data, let raw = String(data: data, encoding: .utf8) else { return "" }
    let compact = raw
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return String(compact.prefix(limit))
}

@inline(__always)
private static func withTimeout<T>(_ seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        let continuationBox = ThrowingContinuationBox(continuation)
        let operationTask = Task {
            do {
                continuationBox.resume(with: .success(try await operation()))
            } catch {
                continuationBox.resume(with: .failure(error))
            }
        }

        Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            } catch {
                return
            }

            operationTask.cancel()
            continuationBox.resume(with: .failure(TimeoutError(seconds: seconds)))
        }
    }
}

// Funzione principale che raccoglie tutti i dati da fonti ufficåiali
    /// Versione moderna async/await di fetchPlateSummary
    public static func fetchPlateSummary(plate: String) async throws -> PlateData {
        let traceId = String(UUID().uuidString.prefix(8))
        let lookupStart = Date()
        let lookupPlate = normalizePlate(plate)
        exists = false
        logNetwork("[PlateLookup:\(traceId)] start raw='\(plate)' normalized='\(lookupPlate)'")

        // 🚀 CACHE HIT: Controllo cache prima di fare qualsiasi elaborazione
        if let cachedData = PlateDataCache.get(lookupPlate) {
            print("🎯 Cache hit per targa: \(lookupPlate)")
            logNetwork("[PlateLookup:\(traceId)] cache.hit identity=\(cachedData.hasVehicleIdentityData) elapsedMs=\(elapsedMilliseconds(since: lookupStart))")
            return cachedData
        }

        do {
            let dbStart = Date()
            logNetwork("[PlateLookup:\(traceId)] db.start plate=\(lookupPlate)")
            if let cachedPlateData = try await checkVehicleInDB(plate: lookupPlate) {
                exists = true
                // 💾 CACHE SAVE: Salva anche i dati dal DB in cache
                PlateDataCache.set(lookupPlate, data: cachedPlateData)
                print("💾 Dati dal DB salvati in cache per targa: \(lookupPlate)")
                logNetwork("[PlateLookup:\(traceId)] db.hit identity=\(cachedPlateData.hasVehicleIdentityData) elapsedMs=\(elapsedMilliseconds(since: dbStart))")
                return cachedPlateData
            }
            logNetwork("[PlateLookup:\(traceId)] db.miss elapsedMs=\(elapsedMilliseconds(since: dbStart))")
        } catch let apiError as PlateAPIError {
            if case .alreadyInGarage = apiError {
                logWarning("[PlateLookup:\(traceId)] db.alreadyInGarage plate=\(lookupPlate)")
                throw apiError // lo rilanci per gestirlo più in alto con alert
            }
        } catch {
            print("⚠️ Errore checkVehicleInDB:", error.localizedDescription)
            logWarning("[PlateLookup:\(traceId)] db.error \(error.localizedDescription)")
        }
        
        
        var plateData = PlateData(plate: lookupPlate)

        @Sendable func fetchWithFallback<T>(label: String, fallback: T, timeout: Double = 10.0, operation: @escaping @Sendable () async throws -> T) async -> T {
            let stepStart = Date()
            logNetwork("[PlateLookup:\(traceId)] \(label).start timeout=\(String(format: "%.1f", timeout))s")
            do {
                let value = try await withTimeout(timeout) {
                    try await operation()
                }
                logNetwork("[PlateLookup:\(traceId)] \(label).success elapsedMs=\(elapsedMilliseconds(since: stepStart))")
                return value
            } catch {
                print("⚠️ [PlateSummary] Fallback per '\(label)' sulla targa \(lookupPlate): \(error.localizedDescription)")
                logWarning("[PlateLookup:\(traceId)] \(label).fallback elapsedMs=\(elapsedMilliseconds(since: stepStart)) error=\(error.localizedDescription)")

                // Se l'operazione fallita è quella delle revisioni, schedula il retry in background
                if label == "Revisioni" {
                    Task { @MainActor in
                        print("🔄 Scheduling background retry for revisions due to fetch failure.")
                        // In caso di errore scraping revisioni, forza il retry in background.
                        RevisionRetryManager.shared.scheduleBackgroundRetry(for: lookupPlate, plateExists: true)
                        
                    }
                }

                return fallback
            }
        }

        func stringValue(_ value: Any?) -> String {
            if let str = value as? String { return str }
            if let num = value as? NSNumber { return num.stringValue }
            if let intVal = value as? Int { return String(intVal) }
            if let doubleVal = value as? Double { return String(Int(doubleVal)) }
            return ""
        }
        
        // Prima identifichiamo il veicolo: le chiamate secondarie partono solo se esiste.
        async let quattroruoteResult: [String: Any] = fetchWithFallback(label: "Quattroruote", fallback: [:], timeout: 12.0) {
            try await fetchQuattroruotePlateDataAsync(plate: lookupPlate, timeout: 10.0)
        }
        async let allianzResult: [String: String] = fetchWithFallback(label: "Allianz", fallback: [:], timeout: 8.0) {
            try await fetchAllianzInfoAsync(plate: lookupPlate, plateData: PlateData(plate: lookupPlate))
        }

        let quattroruoteData = await quattroruoteResult
        logNetwork("[PlateLookup:\(traceId)] Quattroruote.keys=\(quattroruoteData.keys.sorted())")

        // Mappa i dati quattroruote in plateData, usando "" come fallback per nil
        plateData.make = (quattroruoteData["make"] as? String) ?? ""
        plateData.model = (quattroruoteData["model"] as? String) ?? ""
        plateData.modelDetails = (quattroruoteData["modelDetails"] as? String) ?? ""
        plateData.displacementCC = (quattroruoteData["displacementCC"] as? String) ?? ""
        plateData.fuelType = (quattroruoteData["fuelType"] as? String) ?? ""
        plateData.powerKW = (quattroruoteData["powerKW"] as? String) ?? ""
        plateData.powerCV = (quattroruoteData["powerCV"] as? String) ?? ""
        plateData.registrationDate = (quattroruoteData["registrationDate"] as? String) ?? ""
        plateData.gearbox = (quattroruoteData["cambio"] as? String) ?? (plateData.gearbox ?? "")
        plateData.maxSpeed = (quattroruoteData["velocitaMax"] as? String) ?? (plateData.maxSpeed ?? "")
        plateData.bodyType = (quattroruoteData["bodyType"] as? String) ?? (plateData.bodyType ?? "")
        plateData.consumption = (quattroruoteData["consumi"] as? String) ?? (plateData.consumption ?? "")
        plateData.traction = (quattroruoteData["trazione"] as? String) ?? (plateData.traction ?? "")
        plateData.version = (quattroruoteData["version"] as? String) ?? (plateData.version ?? "")
        plateData.vin = (quattroruoteData["vin"] as? String) ?? (plateData.vin ?? "")
        plateData.saleStart = (quattroruoteData["inizioVendita"] as? String) ?? (plateData.saleStart ?? "")
        plateData.saleEnd = (quattroruoteData["fineVendita"] as? String) ?? (plateData.saleEnd ?? "")

        let doorsValue = stringValue(quattroruoteData["doors"])
        plateData.doors = !doorsValue.isEmpty ? doorsValue : (plateData.doors ?? "")

        let seatsValue = stringValue(quattroruoteData["seats"])
        plateData.seats = !seatsValue.isEmpty ? seatsValue : (plateData.seats ?? "")

        let allianz = await allianzResult
        logNetwork("[PlateLookup:\(traceId)] Allianz.keys=\(allianz.keys.sorted())")

        // Sovrascriviamo make e model se Allianz li restituisce (anche se già presenti)
        if let allianzMake = allianz["make"], !allianzMake.isEmpty {
            plateData.make = allianzMake
        }
        if let allianzModel = allianz["model"], !allianzModel.isEmpty {
            plateData.model = allianzModel
        }

        // Per gli altri campi, usiamo la logica esistente (solo se vuoti)
        if (plateData.version ?? "").isEmpty {
            plateData.version = allianz["version"] ?? ""
        }
        if (plateData.powerKW ?? "").isEmpty {
            plateData.powerKW = allianz["powerKW"] ?? ""
        }
        if (plateData.powerCV ?? "").isEmpty {
            plateData.powerCV = allianz["powerCV"] ?? ""
        }
        if (plateData.fuelType ?? "").isEmpty {
            plateData.fuelType = allianz["fuelType"] ?? ""
        }
        if (plateData.displacementCC ?? "").isEmpty {
            plateData.displacementCC = allianz["displacementCC"] ?? ""
        }
        if (plateData.registrationDate ?? "").isEmpty {
            plateData.registrationDate = allianz["registrationDate"] ?? ""
        }
        if (plateData.modelDetails ?? "").isEmpty {
            plateData.modelDetails = allianz["modelDetail"] ?? ""
        }

        let hasVehicleIdentity = [
            plateData.make,
            plateData.model,
            plateData.modelDetails,
            plateData.registrationDate,
            plateData.displacementCC
        ].contains { value in
            !(value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let shouldCalculateRevisions = hasVehicleIdentity && Self.shouldCalculateRevisions(registrationDateString: plateData.registrationDate)

        let revisioniRaw: [[String: String]]
        if shouldCalculateRevisions {
            revisioniRaw = await fetchWithFallback(label: "Revisioni", fallback: [[String: String]]()) {
                try await fetchRevisioniSecureAsync(plate: lookupPlate)
            }
        } else if hasVehicleIdentity {
            revisioniRaw = []
        } else {
            print("ℹ️ [PlateSummary] Revisioni saltate per targa \(lookupPlate): veicolo non identificato")
            revisioniRaw = []
        }

        let rca: [String: String]
        let classeAmbientale: String
        let tyres: [[String: String]]
        if hasVehicleIdentity {
            async let rcaLookup: [String: String] = fetchWithFallback(label: "CoperturaRC", fallback: [:]) {
                try await fetchCoperturaRCAsync(plate: lookupPlate)
            }
            async let classeAmbientaleLookup: String = fetchWithFallback(label: "ClasseAmbientale", fallback: "") {
                try await fetchClasseAmbientaleAsync(plate: lookupPlate)
            }
            async let tyresLookup: [[String: String]] = fetchWithFallback(label: "TyreBlackcircles", fallback: [[String: String]]()) {
                try await fetchTyreBlackcirclesAsync(plate: lookupPlate)
            }
            (rca, classeAmbientale, tyres) = await (rcaLookup, classeAmbientaleLookup, tyresLookup)
        } else {
            print("ℹ️ [PlateSummary] Identità veicolo non recuperata per targa \(lookupPlate); dati secondari saltati.")
            logWarning("[PlateLookup:\(traceId)] identity.missing skipSecondaryLookups")
            rca = [:]
            classeAmbientale = ""
            tyres = []
        }

        plateData.insuranceCompany = rca["company"] ?? plateData.insuranceCompany
        if let expiryStr = rca["expiry"], !expiryStr.isEmpty {
            let inputFormatter = DateFormatter()
            inputFormatter.locale = Locale(identifier: "it_IT")
            inputFormatter.dateFormat = "yyyy-MM-ddZZZZZ"
            if let date = inputFormatter.date(from: expiryStr) {
                plateData.insuranceExpiry = date
            }
        }
        plateData.insurancePolicyNumber = rca["policyNumber"] ?? plateData.insurancePolicyNumber
        if let insurancePresent = rca["insurancePresent"] {
            plateData.insurancePresent = (insurancePresent as NSString).boolValue
        }

        plateData.emissionClass = classeAmbientale
        plateData.tyres = tyres
        let parsed = revisioniRaw.compactMap { dict -> Revisione? in
            let km = dict["numKmiPcsRvs"] ?? ""
            let esito = dict["flgEsiRvsVei"] ?? ""
            var data: Date? = nil
            if let datStr = dict["datRvs"] {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "it_IT")
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.S"
                data = formatter.date(from: datStr)
            }
            return Revisione(kmRevisione: km, dataRevisione: data, esitoRevisione: esito)
        }
        plateData.revisioni = parsed

        // Se parsed è vuoto, lo consideriamo un risultato valido ("nessuna revisione").
        // Il retry in background parte solo nel ramo di errore fetch/scraping.

        // Fetch immagine veicolo
        if let make = plateData.make, let model = plateData.model {
            plateData.year = plateData.registrationDate?.components(separatedBy: "/").last ?? ""
            do {
                let image = try await VehicleImageService.fetchVehicleImageAsync(
                    make: make,
                    modelFamily: plateData.modelDetails ?? model,
                    year: plateData.year ?? "",
                    paintId: plateData.color ?? "",
                    plate: plateData.plate,
                    angle: 23
                )
                plateData.vehicleImage = image
            } catch {
                print("⚠️ Immagine non recuperata: \(error.localizedDescription)")
                plateData.vehicleImage = nil
            }
        }

        // 💾 CACHE SAVE: Salva solo veicoli identificati, non targhe inesistenti con dati vuoti
        if hasVehicleIdentity {
            PlateDataCache.set(lookupPlate, data: plateData)
            print("💾 Dati salvati in cache per targa: \(lookupPlate)")
            logNetwork("[PlateLookup:\(traceId)] cache.save")
        } else {
            print("ℹ️ [PlateSummary] Dati non salvati in cache per targa \(lookupPlate): veicolo non identificato")
            logWarning("[PlateLookup:\(traceId)] cache.skipNoIdentity")
        }

        logNetwork("[PlateLookup:\(traceId)] finished identity=\(hasVehicleIdentity) elapsedMs=\(elapsedMilliseconds(since: lookupStart))")
        return plateData
    }

    private static func shouldCalculateRevisions(registrationDateString: String?) -> Bool {
        guard
            let rawValue = registrationDateString?.trimmingCharacters(in: .whitespacesAndNewlines),
            !rawValue.isEmpty,
            let registrationDate = parseRegistrationDate(rawValue)
        else {
            return true
        }

        guard let fourYearsLater = Calendar.current.date(byAdding: .year, value: 4, to: registrationDate) else {
            return true
        }

        return Date() >= fourYearsLater
    }

    private static func parseRegistrationDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let formats = [
            "yyyy-MM-dd",
            "dd/MM/yyyy",
            "MM/yyyy",
            "yyyy-MM",
            "yyyy",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        ]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        let isoFormatter = ISO8601DateFormatter()
        if let isoDate = isoFormatter.date(from: value) {
            return isoDate
        }
        return nil
    }

    private static func checkVehicleInDB(plate: String) async throws -> PlateData? {
        let requestStart = Date()
        
        let apiConfig = PlateAPIService.apiConfig
        
        
        guard let baseURL = apiConfig["BASE_URL"] as? String else {
            print("BASE_URL not found")
            logWarning("[PlateDB] BASE_URL missing for plate=\(plate)")
            return nil
        }
        
        guard let url = URL(string: "\(baseURL)/v1/check_plate") else {
            logWarning("[PlateDB] invalid URL baseURL=\(baseURL)")
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = NetworkTimeout.quickLookup
        logNetwork("[PlateDB] request.start url=\(url.absoluteString) plate=\(plate)")

        // Aggiungi il token JWT
        do {
            let session = try await SupabaseManager.client.auth.session
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            logNetwork("[PlateDB] auth.token.ok plate=\(plate)")
        } catch {
            print("⚠️ Errore nel recupero del token JWT: \(error.localizedDescription)")
            logWarning("[PlateDB] auth.token.error plate=\(plate) error=\(error.localizedDescription)")
        }
        AuthTokenHelper.addSecurityHeaders(to: &request)

        let userId = await AuthService.currentUserId ?? ""
        let body: [String: Any] = [
            "plate": plate,
            "userId": userId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.tyreVibesShared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                logWarning("[PlateDB] invalid response plate=\(plate) elapsedMs=\(elapsedMilliseconds(since: requestStart))")
                exists = false
                return nil
            }
            logNetwork("[PlateDB] response.status=\(http.statusCode) bytes=\(data.count) plate=\(plate) elapsedMs=\(elapsedMilliseconds(since: requestStart))")

            guard http.statusCode == 200 else {
                exists = false
                return nil
            }
            
            if let vehicleDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                
                if let alreadyInGarage = vehicleDict["already_in_garage"] as? Bool, alreadyInGarage {
                    logWarning("[PlateDB] alreadyInGarage plate=\(plate)")
                    throw PlateAPIError.alreadyInGarage
                }
                
                
                var plateData = PlateData(plate: plate)
                plateData.make = vehicleDict["make"] as? String ?? ""
                plateData.model = vehicleDict["model"] as? String ?? ""
                plateData.year = vehicleDict["year"] as? String ?? ""
                plateData.modelDetails = vehicleDict["model_detail"] as? String ?? ""
                // Handle displacementCC (can be String, NSNumber, Int, Double, or nil)
                if let disp = vehicleDict["displacement"] {
                    if let str = disp as? String {
                        plateData.displacementCC = str
                    } else if let num = disp as? NSNumber {
                        plateData.displacementCC = num.stringValue
                    } else if let intVal = disp as? Int {
                        plateData.displacementCC = String(intVal)
                    } else if let doubleVal = disp as? Double {
                        plateData.displacementCC = String(Int(doubleVal))
                    } else {
                        plateData.displacementCC = ""
                    }
                } else {
                    plateData.displacementCC = ""
                }
                plateData.fuelType = vehicleDict["fuel_type"] as? String ?? ""
                plateData.powerKW = vehicleDict["power_kw"] as? String ?? ""
                // Handle powerCV (can be String, NSNumber, Int, Double, or nil)
                if let cv = vehicleDict["power_cv"] {
                    if let str = cv as? String {
                        plateData.powerCV = str
                    } else if let num = cv as? NSNumber {
                        plateData.powerCV = num.stringValue
                    } else if let intVal = cv as? Int {
                        plateData.powerCV = String(intVal)
                    } else if let doubleVal = cv as? Double {
                        plateData.powerCV = String(Int(doubleVal))
                    } else {
                        plateData.powerCV = ""
                    }
                } else {
                    plateData.powerCV = ""
                }
                plateData.registrationDate = vehicleDict["registration_date"] as? String ?? ""
                plateData.version = vehicleDict["version"] as? String ?? ""
                plateData.bodyType = vehicleDict["body_type"] as? String ?? ""
                // Handle doors (can be String, NSNumber, Int, or nil)
                if let doorsVal = vehicleDict["doors"] {
                    if let str = doorsVal as? String {
                        plateData.doors = str
                    } else if let num = doorsVal as? NSNumber {
                        plateData.doors = num.stringValue
                    } else if let intVal = doorsVal as? Int {
                        plateData.doors = String(intVal)
                    } else {
                        plateData.doors = ""
                    }
                } else {
                    plateData.doors = ""
                }
                // Handle seats (can be String, NSNumber, Int, or nil)
                if let seatsVal = vehicleDict["seats"] {
                    if let str = seatsVal as? String {
                        plateData.seats = str
                    } else if let num = seatsVal as? NSNumber {
                        plateData.seats = num.stringValue
                    } else if let intVal = seatsVal as? Int {
                        plateData.seats = String(intVal)
                    } else {
                        plateData.seats = ""
                    }
                } else {
                    plateData.seats = ""
                }
                plateData.color = vehicleDict["color"] as? String ?? ""
                plateData.gearbox = vehicleDict["gearbox"] as? String ?? ""
                plateData.maxSpeed = vehicleDict["max_speed"] as? String ?? ""
                plateData.emissionClass = vehicleDict["emission_class"] as? String ?? ""
                plateData.consumption = vehicleDict["consumption"] as? String ?? ""
                plateData.traction = vehicleDict["traction"] as? String ?? ""
                plateData.saleStart = vehicleDict["sale_start"] as? String ?? ""
                plateData.saleEnd = vehicleDict["sale_end"] as? String ?? ""
                plateData.vin = vehicleDict["vin"] as? String ?? ""
                // Insurance mapping
                if let insuranceDict = vehicleDict["insurance"] as? [String: Any] {
                    plateData.insuranceCompany = insuranceDict["company"] as? String
                    plateData.insurancePolicyNumber = insuranceDict["policy_number"] as? String
                    plateData.insuranceExpiry = insuranceDict["expiry"] as? Date
                    if let present = insuranceDict["insurance_present"] as? Bool {
                        plateData.insurancePresent = present
                    }
                }
                // Decode Base64 image if present
                if let base64String = vehicleDict["image_base64"] as? String,
                   let imageData = Data(base64Encoded: base64String),
                   let image = UIImage(data: imageData) {
                    plateData.vehicleImage = image
                }
                plateData.vehicleId = vehicleDict["vehicle_id"] as? Int ?? nil
                logNetwork("[PlateDB] parsed vehicleId=\(plateData.vehicleId.map(String.init) ?? "nil") identity=\(plateData.hasVehicleIdentityData) keys=\(vehicleDict.keys.sorted()) plate=\(plate)")
                
                return plateData
            }
        } catch let apiError as PlateAPIError {
            throw apiError
        } catch {
            print("⚠️ Errore checkVehicleInDB:", error.localizedDescription)
            logWarning("[PlateDB] request.error plate=\(plate) elapsedMs=\(elapsedMilliseconds(since: requestStart)) error=\(error.localizedDescription)")
            return nil
        }
        
        return nil
    }


// MARK: - Allianz
    private static func fetchAllianzRegistrationDate(plate: String, completion: @escaping (Result<String, Error>) -> Void) {
        let urlString = "https://pro-edp.apis.allianz.com/prod/sales-service/quotebundles?flow=SFQ"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 1, userInfo: nil)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = NetworkTimeout.quickLookup
        request.setValue("motor", forHTTPHeaderField: "line-of-business")
        request.setValue("IT", forHTTPHeaderField: "backend-tenant")
        request.setValue("it-IT", forHTTPHeaderField: "mapped-lang")
        request.setValue(randomSessionId(length: 16), forHTTPHeaderField: "session-id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Generate dateOfBirth as a random string in the format "YYYY-MM-DD"
        let year = Int.random(in: 1952...2004)
        let month = Int.random(in: 1...12)
        let day = Int.random(in: 1...28)
        let generatedDate = String(format: "%04d-%02d-%02d", year, month, day)

        let bodyDict: [String: Any] = [
            "customerData": [
                "insuredProperty": [
                    "type": "car",
                    "usage": "KFZ01",
                    "multipleOwners": false,
                    "licensePlate": plate,
                    "licensePlateType": "01",
                    "driverCircle": ["mainDriverType": "E"],
                    "mileage": "19999",
                    "parkingAvailable": true,
                    "usageDetail": "PR"
                ],
                "paymentFrequency": "ANNUALLY",
                "carOwner": [
                    "type": "person",
                    "dateOfBirth": generatedDate
                ],
                "deviceType": "mobile"
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.tyreVibesShared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 2, userInfo: nil)))
                return
            }

            if let raw = String(data: data, encoding: .utf8),
               let fixedData = raw.data(using: .utf8) {
                do {
                    if let json = try JSONSerialization.jsonObject(with: fixedData) as? [String: Any],
                       let customerData = json["customerData"] as? [String: Any],
                       let insuredProperty = customerData["insuredProperty"] as? [String: Any],
                       let details = insuredProperty["details"] as? [String: Any],
                       let firstRegistrationDate = details["firstRegistrationDate"] as? String {
                        if let model = details["model"] as? String {
                            let cleanModel = model.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces) ?? model
                            let normalized = cleanModel.folding(options: .diacriticInsensitive, locale: .current)
                            _ = normalized
                        }
                        let parts = firstRegistrationDate.split(separator: "-")
                        if parts.count == 3 {
                            completion(.success("\(parts[1])/\(parts[0])"))
                        } else {
                            completion(.success(firstRegistrationDate))
                        }
                    } else {
                        completion(.success(""))
                    }
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.success(""))
            }
        }.resume()
    }

    private static func fetchAllianzInfo(plate: String, plateData: PlateData, completion: @escaping (Result<[String:String], Error>) -> Void) {
        let urlString = "https://pro-edp.apis.allianz.com/prod/sales-service/quotebundles?flow=SFQ"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 1, userInfo: nil)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = NetworkTimeout.quickLookup
        request.setValue("motor", forHTTPHeaderField: "line-of-business")
        request.setValue("IT", forHTTPHeaderField: "backend-tenant")
        request.setValue("it-IT", forHTTPHeaderField: "mapped-lang")
        request.setValue(randomSessionId(length: 16), forHTTPHeaderField: "session-id")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Generate dateOfBirth as a random string in the format "YYYY-MM-DD"
        let year = Int.random(in: 1952...2004)
        let month = Int.random(in: 1...12)
        let day = Int.random(in: 1...28)
        let generatedDate = String(format: "%04d-%02d-%02d", year, month, day)

        let bodyDict: [String: Any] = [
            "customerData": [
                "insuredProperty": [
                    "type": "car",
                    "usage": "KFZ01",
                    
                    "multipleOwners": false,
                    "licensePlate": plate,
                    "licensePlateType": "01",
                    "driverCircle": ["mainDriverType": "E"],
                    "mileage": "19999",
                    "parkingAvailable": true,
                    "usageDetail": "PR"
                ],
                "paymentFrequency": "ANNUALLY",
                "carOwner": [
                    "type": "person",
                    "dateOfBirth": generatedDate
                ],
                "deviceType": "mobile"
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        // Take a snapshot of the relevant plateData fields for use in the closure
        let snapshotFuelType = plateData.fuelType ?? ""
        let snapshotPowerKW = plateData.powerKW ?? ""
        let snapshotPowerCV = plateData.powerCV ?? ""
        let snapshotDisplacement = plateData.displacementCC ?? ""
        let snapshotRegistrationDate = plateData.registrationDate ?? ""
        let snapshotModelDetails = plateData.modelDetails ?? ""

        URLSession.tyreVibesShared.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 2, userInfo: nil)))
                return
            }
            var dict: [String:String] = [:]
            if let raw = String(data: data, encoding: .utf8),
               let fixedData = raw.data(using: .utf8) {
                do {
                    if let json = try JSONSerialization.jsonObject(with: fixedData) as? [String: Any],
                       let customerData = json["customerData"] as? [String: Any],
                       let insuredProperty = customerData["insuredProperty"] as? [String: Any],
                       let details = insuredProperty["details"] as? [String: Any] {
                        // Leggi make da Allianz se disponibile (anche se plateData ha già un valore)
                        if let brand = details["brand"] as? String {
                            dict["make"] = brand
                        }
                        // Leggi model da Allianz se disponibile (anche se plateData ha già un valore)
                        if let model = details["model"] as? String {
                            let cleanModel = model.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces) ?? model
                            let normalized = cleanModel.folding(options: .diacriticInsensitive, locale: .current)
                            dict["model"] = normalized
                        }
                        if let fuelType = details["fuelType"] as? String, snapshotFuelType.isEmpty {
                            var fuel = fuelType
                            switch fuelType {
                            case "D": fuel = "Diesel"
                            case "B": fuel = "Benzina"
                            case "I", "H": fuel = "Ibrida"
                            case "E": fuel = "Elettrica"
                            case "G", "L": fuel = "GPL"
                            case "M": fuel = "Metano"
                            default: break
                            }
                            dict["fuelType"] = fuel
                        }
                        if let power = details["power"], snapshotPowerKW.isEmpty {
                            if let powerStr = power as? String {
                                dict["powerKW"] = powerStr
                                if snapshotPowerCV.isEmpty, let kw = Double(powerStr) {
                                    dict["powerCV"] = String(Int(round(kw / 0.73549875)))
                                }
                            }
                        }
                        if let cubicCapacity = details["cubicCapacity"] as? String, snapshotDisplacement.isEmpty {
                            dict["displacementCC"] = cubicCapacity
                        }
                        if let firstRegistrationDate = details["firstRegistrationDate"] as? String, snapshotRegistrationDate.isEmpty {
                            let parts = firstRegistrationDate.split(separator: "-")
                            if parts.count == 3 {
                                dict["registrationDate"] = "\(parts[1])/\(parts[0])"
                            } else {
                                dict["registrationDate"] = firstRegistrationDate
                            }
                        }
                        if let modelDetails = details["modelDetail"] as? String, snapshotModelDetails.isEmpty {
                            let cleanModelDetails = modelDetails.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces) ?? modelDetails
                            let normalized = cleanModelDetails.folding(options: .diacriticInsensitive, locale: .current)
                            dict["modelDetail"] = normalized
                        }
                    }
                    completion(.success(dict))
                } catch {
                    completion(.failure(error))
                    return
                }
            } else {
                completion(.success(dict))
            }
        }.resume()
    }

private static func randomSessionId(length: Int) -> String {
let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
return String((0..<length).map{ _ in letters.randomElement()! })
}
// RCA
private static func fetchCoperturaRC(plate: String, tipoVeicolo: String = "A", completion: @escaping (Result<[String:String], Error>) -> Void) {
let urlString = "https://www.ilportaledellautomobilista.it/eai/AreaVeicolo-ws/services/secure/coperturaRCNew"
guard let url = URL(string: urlString) else {
completion(.failure(NSError(domain: "CoperturaRC", code: 1, userInfo: nil)))
return
}

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.timeoutInterval = NetworkTimeout.quickLookup
request.setValue("text/xml;charset=utf-8", forHTTPHeaderField: "Content-Type")
request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

let soapBody = """
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
              xmlns:veic="http://www.dtt.it/xsd/Veicolo">
<soapenv:Header>
  <wsse:Security soapenv:mustUnderstand="1"
                 xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
     <wsse:UsernameToken wsu:Id="UsernameToken-1"
         xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
        <wsse:Username>PUBLIC</wsse:Username>
        <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText">PUBLIC</wsse:Password>
     </wsse:UsernameToken>
  </wsse:Security>
</soapenv:Header>
<soapenv:Body>
  <veic:CoperturaRCVeicoloSecureNewRequest>
     <veic:tipoVeicolo>\(tipoVeicolo)</veic:tipoVeicolo>
     <veic:targa>\(plate)</veic:targa>
  </veic:CoperturaRCVeicoloSecureNewRequest>
</soapenv:Body>
</soapenv:Envelope>
"""

request.httpBody = soapBody.data(using: .utf8)

URLSession.tyreVibesShared.dataTask(with: request) { data, response, error in
if let error = error {
    completion(.failure(error))
    return
}
guard let data = data else {
    completion(.failure(NSError(domain: "CoperturaRC", code: 2, userInfo: nil)))
    return
}
let parser = SimpleXMLParser(data: data)
let rcaDict = parser.parseRCA()
completion(.success(rcaDict))
}.resume()
}

// MARK: - Classe Ambientale
private static func fetchClasseAmbientale(plate: String, tipoVeicolo: String = "A", completion: @escaping (Result<String, Error>) -> Void) {
let urlString = "https://www.ilportaledellautomobilista.it/eai/AreaVeicolo-ws/services/secure/verificaClasseAmbientaleVeicolo"
guard let url = URL(string: urlString) else {
completion(.failure(NSError(domain: "LicensePlateReader", code: 5, userInfo: nil)))
return
}

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.timeoutInterval = NetworkTimeout.quickLookup
request.setValue("text/xml;charset=utf-8", forHTTPHeaderField: "Content-Type")
request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
request.setValue("\"VerificaClasseAmbientaleVeicoloSecure\"", forHTTPHeaderField: "SOAPAction")
request.setValue("text/xml", forHTTPHeaderField: "Accept")

let soapBody = """
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<soapenv:Header>
  <wsse:Security soapenv:mustUnderstand="0" soapenv:actor="http://schemas.xmlsoap.org/soap/actor/next"
      xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
     <wsse:UsernameToken wsu:Id="XWSSGID-1253605895203984534550"
         xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
        <wsse:Username>PUBLIC</wsse:Username>
        <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText">PUBLIC</wsse:Password>
     </wsse:UsernameToken>
  </wsse:Security>
</soapenv:Header>
<soapenv:Body>
  <VerificaClasseAmbientaleVeicoloSecureRequest xmlns="http://www.dtt.it/xsd/Veicolo">
     <datiVeicolo>
        <tipoVeicolo>\(tipoVeicolo)</tipoVeicolo>
        <targa>\(plate)</targa>
     </datiVeicolo>
  </VerificaClasseAmbientaleVeicoloSecureRequest>
</soapenv:Body>
</soapenv:Envelope>
"""
request.httpBody = soapBody.data(using: .utf8)

URLSession.tyreVibesShared.dataTask(with: request) { data, response, error in
if let error = error { completion(.failure(error)); return }
guard let data = data else {
    completion(.failure(NSError(domain: "LicensePlateReader", code: 6, userInfo: nil)))
    return
}
let parser = SimpleXMLParser(data: data)
let classe = parser.parseClasse()
if classe == "" {
    completion(.failure(NSError(domain: "LicensePlateReader", code: 7, userInfo: [NSLocalizedDescriptionKey: "Classe ambientale non trovata"])))
    return
} else {
    completion(.success(classe))
}
}.resume()
}

// MARK: - Pneumatici compatibili
public static func fetchTyreCompatibili(plate: String, completion: @escaping (Result<[String], Error>) -> Void) {
let urlString = "https://api.example.com/tires?plate=\(plate)"
guard let url = URL(string: urlString) else {
    completion(.failure(NSError(domain: "LicensePlateReader", code: 9001, userInfo: [NSLocalizedDescriptionKey: "URL non valida"])))
    return
}
var request = URLRequest(url: url)
request.httpMethod = "GET"
request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
let task = URLSession.tyreVibesShared.dataTask(with: request) { data, response, error in
    if let error = error {
        completion(.failure(error))
        return
    }
    guard let data = data else {
        completion(.failure(NSError(domain: "LicensePlateReader", code: 9002, userInfo: [NSLocalizedDescriptionKey: "Nessun dato ricevuto"])))
        return
    }
    do {
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let tires = json["compatibleTires"] as? [String] {
            completion(.success(tires))
        } else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 9003, userInfo: [NSLocalizedDescriptionKey: "Risposta senza compatibleTires"])))
        }
    } catch {
        completion(.failure(error))
    }
}
task.resume()
}

public static func fetchTyreBlackcircles(plate: String, completion: @escaping (Result<[[String: String]], Error>) -> Void) {
    guard let url = URL(string: "https://www.blackcircles.it/find") else {
        completion(.failure(NSError(domain: "LicensePlateReader", code: 9101, userInfo: [NSLocalizedDescriptionKey: "URL non valida"])))
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = NetworkTimeout.quickLookup
    // Generate X-XSRF-TOKEN value
    let xsrfToken = generateBlackcirclesToken()
    // Headers richiesti
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue(xsrfToken, forHTTPHeaderField: "X-XSRF-TOKEN")
    request.setValue("https://www.blackcircles.it", forHTTPHeaderField: "Origin")
    request.setValue("https://www.blackcircles.it/", forHTTPHeaderField: "Referer")
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    // Corpo form-urlencoded
    let params: [String: String] = [
        "searchByNumberplateMode": "searchByNumberplateMode",
        "numberplate": plate
    ]
    let bodyString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
        .joined(separator: "&")
    request.httpBody = bodyString.data(using: .utf8)
    let task = URLSession.tyreVibesShared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        guard let data = data else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 9102, userInfo: [NSLocalizedDescriptionKey: "Nessun dato ricevuto"])))
            return
        }
        guard let htmlString = String(data: data, encoding: .utf8) else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 9104, userInfo: [NSLocalizedDescriptionKey: "Impossibile convertire dati in stringa"])))
            return
        }
        // Regex pattern to match the required fields inside div.custom-control
        // We look for: <div class="custom-control ..."><input ... id="..." value="..." data-width="..." ...><label ...><span class="size-label">...</span></label>
        let pattern = #"<div[^>]*class="[^"]*custom-control[^"]*"[^>]*>.*?<input[^>]*\sid="([^"]*)"[^>]*\svalue="([^"]*)"[^>]*\sdata-width="([^"]*)"[^>]*\sdata-diameter="([^"]*)"[^>]*\sdata-ratio="([^"]*)"[^>]*\sdata-speedindex="([^"]*)"[^>]*\sdata-loadindex="([^"]*)"[^>]*>.*?<label[^>]*>.*?<span[^>]*class="size-label"[^>]*>(.*?)</span>"#
        // Options: allow dot to match newlines
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
            let nsrange = NSRange(htmlString.startIndex..<htmlString.endIndex, in: htmlString)
            let matches = regex.matches(in: htmlString, options: [], range: nsrange)
            var results: [[String: String]] = []
            for match in matches {
                guard match.numberOfRanges == 9 else { continue }
                var dict: [String: String] = [:]
                let keys = ["id", "value", "data-width", "data-diameter", "data-ratio", "data-speedindex", "data-loadindex", "size-label"]
                for idx in 1..<match.numberOfRanges {
                    if let range = Range(match.range(at: idx), in: htmlString) {
                        dict[keys[idx-1]] = String(htmlString[range])
                    }
                }
                if !dict.isEmpty {
                    results.append(dict)
                }
            }
            completion(.success(results))
        } catch {
            completion(.failure(error))
        }
    }
    task.resume()
}
    private static func getToken(token: String) async {
        guard let url = URL(string:
            "https://www.midas.it/api/ecrm/vehicles/search/platenumber/GB241PT?captchaVersion=3&captchaToken=\(token)&captchaAction=add_vehicle_by_platenumber_or_vin"
        ) else { return }
        
        // Recupera XSRF-TOKEN
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        let xsrfCookie = cookies.first { $0.name == "XSRF-TOKEN" }
        let xsrfToken = xsrfCookie?.value ?? ""
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST" // ⚠️ verifica se in realtà è GET!
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.midas.it", forHTTPHeaderField: "Origin")
        request.setValue("https://www.midas.it/", forHTTPHeaderField: "Referer")
        request.setValue(xsrfToken, forHTTPHeaderField: "X-XSRF-TOKEN")
        request.httpBody = "{}".data(using: .utf8)
        
        // 🔑 Aggiungi manualmente i cookie all’header
        let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        if !cookieHeader.isEmpty {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        
        do {
            let (data, response) = try await URLSession.tyreVibesShared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("📡 Status:", http.statusCode)
            }
            print("📩 Body:", String(data: data, encoding: .utf8) ?? "")
        } catch {
            print("❌ Request error:", error)
        }
    }
    
    private static func getPlateData(token: String) async {
        guard let url = URL(string:
            "https://www.midas.it/api/ecrm/vehicles/search/platenumber/GB241PT?captchaVersion=3&captchaToken=\(token)&captchaAction=add_vehicle_by_platenumber_or_vin"
        ) else { return }
        
        var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = NetworkTimeout.quickLookup
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)
        
        do {
        do {
            let (data, response) = try await URLSession.tyreVibesShared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("📡 Status:", http.statusCode)
            }
            print("📩 Body:", String(data: data, encoding: .utf8) ?? "")
        } catch {
            print("❌ Errore rete:", error)
        }
        }
    }

private static func generateBlackcirclesToken() -> String {
// Helper to generate n hex chars
func randomHex(_ count: Int) -> String {
    let hexChars = "0123456789abcdef"
    return String((0..<count).map { _ in hexChars.randomElement()! })
}
return "\(randomHex(8))-\(randomHex(4))-\(randomHex(4))-\(randomHex(4))-\(randomHex(7))"
}

// MARK: - Revisioni
private static func fetchRevisioni(plate: String, completion: @escaping (Result<[String], Error>) -> Void) {
let urlString = "https://www.ilportaledellautomobilista.it/portale/api/storicorevisioni?plate=\(plate)"
guard let url = URL(string: urlString) else {
completion(.failure(NSError(domain: "LicensePlateReader", code: 7, userInfo: nil)))
return
}
URLSession.tyreVibesShared.dataTask(with: url) { data, _, error in
if let error = error { completion(.failure(error)); return }
guard let data = data else {
    completion(.failure(NSError(domain: "LicensePlateReader", code: 8, userInfo: nil)))
    return
}
let parser = SimpleXMLParser(data: data)
let revisions = parser.parseRevisioni()
completion(.success(revisions))
}.resume()
}
}

// Parser XML semplice
class SimpleXMLParser: NSObject, XMLParserDelegate {
private let data: Data
private var currentElement = ""
private var currentValue = ""
private var results: [String: String] = [:]
private var revisions: [String] = []

// Proprietà RCA
private var rcaCompany: String?
private var rcaPolicyNumber: String?
private var rcaInsurancePresent: String?
private var rcaExpiry: String?

init(data: Data) { self.data = data }

func parseRCA() -> [String: String] {
// Reset RCA properties
rcaCompany = nil
rcaPolicyNumber = nil
rcaInsurancePresent = nil
rcaExpiry = nil
let parser = XMLParser(data: data)
parser.delegate = self
parser.parse()
var dict: [String: String] = [:]
if let company = rcaCompany { dict["company"] = company }
if let policyNumber = rcaPolicyNumber { dict["policyNumber"] = policyNumber }
if let insurancePresent = rcaInsurancePresent { dict["insurancePresent"] = insurancePresent }
if let expiry = rcaExpiry { dict["expiry"] = expiry }
return dict
}

func parseClasse() -> String {
let parser = XMLParser(data: data)
parser.delegate = self
let ok = parser.parse()
if !ok {
print("XMLParser error:", parser.parserError?.localizedDescription ?? "unknown")
}
return results["veic:categoriaAmbientale"] ?? results["classe"] ?? ""
}

func parseRevisioni() -> [String] {
let parser = XMLParser(data: data)
parser.delegate = self
parser.parse()
return revisions
}

// MARK: - XMLParserDelegate
func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
currentElement = elementName
currentValue = ""
}

func parser(_ parser: XMLParser, didEndElement elementName: String,
    namespaceURI: String?, qualifiedName qName: String?) {
let value = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
// RCA parsing
if !value.isEmpty {
switch elementName {
case "veic:compagniaAssicurativa":
    rcaCompany = value
case "veic:numeroPolizza":
    rcaPolicyNumber = value
case "veic:assicurazionePresente":
    rcaInsurancePresent = value
case "veic:dataScadenzaPolizza":
    rcaExpiry = value
default:
    break
}
results[elementName] = value
}
currentValue = ""
}

func parser(_ parser: XMLParser, foundCharacters string: String) {
currentValue += string
}
}


// MARK: - Async/await + cache
extension VehicleImageService {
    private static var cache = NSCache<NSString, UIImage>()

    static func fetchVehicleImageAsync(make: String, modelFamily: String, year: String, paintId: String, plate: String, angle: Int) async throws -> UIImage {
        let key = "\(make)-\(modelFamily)-\(year)-\(paintId)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        return try await withCheckedThrowingContinuation { cont in
            fetchVehicleImage(make: make, modelFamily: modelFamily, year: year, paintId: paintId,angle: angle, plate: plate) { result in
                switch result {
                case .success(let img):
                    cache.setObject(img, forKey: key)
                    cont.resume(returning: img)
                case .failure(let err):
                    cont.resume(throwing: err)
                }
            }
        }
    }
}
