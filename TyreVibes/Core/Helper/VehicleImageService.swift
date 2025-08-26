import Foundation
import SwiftUI


class VehicleImageService {
    struct VehicleImageOptions {
        var customer: String = "img"
        var angle: Int = 23
        var fileType: String = "webp"
        var safeMode: Bool = false
        var origin: String = "https://docs.imagin.studio"
        var userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36"
        var accept: String = "*/*"
    }
    

    static func fetchVehicleImage(make: String, modelFamily: String, year: String, paintId: String, options: VehicleImageOptions , completion: @escaping (Result<UIImage, Error>) -> Void) {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "cdn.imagin.studio"
        comps.path = "/getImage"
        comps.queryItems = [
            URLQueryItem(name: "customer", value: options.customer),
            URLQueryItem(name: "make", value: make),
            URLQueryItem(name: "modelFamily", value: modelFamily),
            URLQueryItem(name: "paintId", value: paintId),
            URLQueryItem(name: "angle", value: String(options.angle)),
            URLQueryItem(name: "modelYear", value: String(year)),
            URLQueryItem(name: "fileType", value: options.fileType)
        ]
        guard let url = comps.url else {
            completion(.failure(NSError(domain: "VehicleImageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL components"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(options.accept, forHTTPHeaderField: "Accept")
        // NON modificare il Referer: mantieni quello attuale
        request.setValue("https://docs.imagin.studio/api-integration/apis", forHTTPHeaderField: "Referer")
        request.setValue(options.origin, forHTTPHeaderField: "Origin")
        request.setValue(options.userAgent, forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error)); return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let msg = "HTTP \(http.statusCode) for URL: \(url.absoluteString)"
                completion(.failure(NSError(domain: "VehicleImageService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])));
                return
            }
            guard let data = data, let image = UIImage(data: data) else {
                completion(.failure(NSError(domain: "VehicleImageService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])))
                return
            }
            completion(.success(image))
        }
        task.resume()
    }

    static func fetchVehicleImage(make: String, modelFamily: String,year : String, paintId: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let options = VehicleImageOptions()
        fetchVehicleImage(make: make, modelFamily: modelFamily, year: year, paintId: paintId, options: options, completion: completion)
    }
}
