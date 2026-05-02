import Foundation

class AddressService {
    private let baseUrl = "https://www.fastweb.it/AVT/ajax/getVia/"

    func findPlace(query: String, completion: @escaping (Result<[AddressSuggestion], Error>) -> Void) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(.failure(NSError(domain: "AddressService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid query"])))
            return
        }

        guard let url = URL(string: "\(baseUrl)?q=\(encodedQuery)") else {
            completion(.failure(NSError(domain: "AddressService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        URLSession.tyreVibesShared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "AddressService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let addressResponse = try JSONDecoder().decode(AddressResponse.self, from: data)
                if addressResponse.status == "ok" {
                    completion(.success(addressResponse.resp))
                } else {
                    completion(.failure(NSError(domain: "AddressService", code: 3, userInfo: [NSLocalizedDescriptionKey: "API error: \(addressResponse.status)"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}