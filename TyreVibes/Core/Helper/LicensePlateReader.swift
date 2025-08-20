import Foundation

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
    public var extra: [String: String] = [:]
}

// Lettore principale
public class LicensePlateReader {
    
    // Funzione principale che raccoglie tutti i dati da fonti ufficåiali
    public static func fetchPlateSummary(plate: String, completion: @escaping (Result<PlateData, Error>) -> Void) {
        var plateData = PlateData(plate: plate)
        
        // Step 1: Allianz API per dati base veicolo
        fetchAllianzInfo(plate: plate) { result in
            switch result {
            case .success(let allianz):
                print(allianz)
                plateData.make = allianz["make"]
                plateData.model = allianz["model"]
                plateData.version = allianz["version"]
                plateData.powerKW = allianz["powerKW"]
                plateData.powerCV = allianz["powerCV"]
                plateData.fuelType = allianz["fuelType"]
                plateData.displacementCC = allianz["displacementCC"]
                plateData.registrationDate = allianz["registrationDate"]
                plateData.modelDetails = allianz["modelDetail"]
            case .failure(let error):
                print("Allianz error: \(error)")
            }
            
            // Step 2: RCA dal Portale
            fetchRCA(plate: plate) { rcaResult in
                switch rcaResult {
                case .success(let rca):
                    plateData.extra["rcaCompany"] = rca["company"]
                    plateData.extra["rcaExpiry"] = rca["expiry"]
                case .failure(let error):
                    print("RCA error: \(error)")
                }
                
                // Step 3: Classe ambientale
                fetchClasseAmbientale(plate: plate) { classeResult in
                    switch classeResult {
                    case .success(let classe):
                        plateData.extra["classeAmbientale"] = classe
                    case .failure(let error):
                        print("Classe error: \(error)")
                    }
                    
                    // Step 4: Revisioni
                    fetchRevisioni(plate: plate) { revResult in
                        switch revResult {
                        case .success(let revisions):
                            plateData.extra["revisioni"] = revisions.joined(separator: "; ")
                        case .failure(let error):
                            print("Revisioni error: \(error)")
                        }
                        
                        completion(.success(plateData))
                    }
                }
            }
        }
    }
    
    // MARK: - Allianz
    private static func fetchAllianzInfo(plate: String, completion: @escaping (Result<[String:String], Error>) -> Void) {
        let urlString = "https://pro-edp.apis.allianz.com/prod/sales-service/quotebundles?flow=SFQ"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 1, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 2, userInfo: nil)))
                return
            }
            var dict: [String:String] = [:]
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
               let customerData = json["customerData"] as? [String: Any],
               let insuredProperty = customerData["insuredProperty"] as? [String: Any],
               let details = insuredProperty["details"] as? [String: Any] {
                if let brand = details["brand"] as? String {
                    dict["make"] = brand
                }
                if let model = details["model"] as? String {
                    let cleanModel = model.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces) ?? model
                    dict["model"] = cleanModel
                }
                if let fuelType = details["fuelType"] as? String {
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
                if let power = details["power"] {
                    if let powerStr = power as? String {
                        dict["powerKW"] = powerStr + " kW"
                        if let kw = Double(powerStr) {
                            dict["powerCV"] = String(Int(round(kw / 0.73549875)))
                        }
                    } else if let powerNum = power as? NSNumber {
                        dict["powerKW"] = "\(powerNum) kW"
                        let kw = powerNum.doubleValue
                        dict["powerCV"] = String(Int(round(kw / 0.73549875)))
                    }
                }
                if let cubicCapacity = details["cubicCapacity"] as? String {
                    dict["displacementCC"] = cubicCapacity
                }
                if let firstRegistrationDate = details["firstRegistrationDate"] as? String {
                    let parts = firstRegistrationDate.split(separator: "-")
                    if parts.count == 3 {
                        dict["registrationDate"] = "\(parts[2])-\(parts[1])-\(parts[0])"
                    } else {
                        dict["registrationDate"] = firstRegistrationDate
                    }
                }
                
                if let modelDetails = details["modelDetail"] as? String{
                    let cleanModelDetails = modelDetails.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces) ?? modelDetails
                    dict["modelDetail"] = cleanModelDetails
                }
            }
            completion(.success(dict))
        }.resume()
    }
    
    private static func randomSessionId(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    // MARK: - RCA
    private static func fetchRCA(plate: String, completion: @escaping (Result<[String:String], Error>) -> Void) {
        let urlString = "https://www.ilportaledellautomobilista.it/portale/api/visura/coperturaRCNew?plate=\(plate)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 3, userInfo: nil)))
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 4, userInfo: nil)))
                return
            }
            let parser = SimpleXMLParser(data: data)
            let dict = parser.parseRCA()
            completion(.success(dict))
        }.resume()
    }
    
    // MARK: - Classe Ambientale
    private static func fetchClasseAmbientale(plate: String, completion: @escaping (Result<String, Error>) -> Void) {
        let urlString = "https://www.ilportaledellautomobilista.it/portale/api/verificaClasseAmbientaleVeicolo?plate=\(plate)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 5, userInfo: nil)))
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "LicensePlateReader", code: 6, userInfo: nil)))
                return
            }
            let parser = SimpleXMLParser(data: data)
            let classe = parser.parseClasse()
            completion(.success(classe))
        }.resume()
    }
    
    // MARK: - Revisioni
    private static func fetchRevisioni(plate: String, completion: @escaping (Result<[String], Error>) -> Void) {
        let urlString = "https://www.ilportaledellautomobilista.it/portale/api/storicorevisioni?plate=\(plate)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "LicensePlateReader", code: 7, userInfo: nil)))
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, error in
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
    private var results: [String:String] = [:]
    private var revisions: [String] = []
    
    init(data: Data) { self.data = data }
    
    func parseRCA() -> [String:String] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return results
    }
    
    func parseClasse() -> String {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return results["classe"] ?? ""
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
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return }
        
        if elementName == "compagnia" {
            results["company"] = value
        } else if elementName == "scadenza" {
            results["expiry"] = value
        } else if elementName == "classe" {
            results["classe"] = value
        } else if elementName == "revisione" {
            revisions.append(value)
        }
    }
}
