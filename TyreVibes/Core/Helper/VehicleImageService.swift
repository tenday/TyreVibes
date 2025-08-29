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
        var zoomType: String = "relative"
    }

    static let defaultAngles: [Int] = Array(200...231)
    private static let cache = NSCache<NSNumber, UIImage>()

    /// Builds the CDN URL for a specific angle (without performing the request)
    private static func buildURL(make: String,
                                 modelFamily: String,
                                 year: String,
                                 paintId: String,
                                 angle: Int,
                                 options: VehicleImageOptions) -> URL? {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "cdn.imagin.studio"
        comps.path = "/getImage"
        comps.queryItems = [
            URLQueryItem(name: "customer", value: options.customer),
            URLQueryItem(name: "make", value: make),
            URLQueryItem(name: "modelFamily", value: modelFamily),
            URLQueryItem(name: "paintId", value: paintId),
            URLQueryItem(name: "angle", value: String(angle)),
            URLQueryItem(name: "modelYear", value: String(year)),
            URLQueryItem(name: "fileType", value: options.fileType),
            URLQueryItem(name: "zoomType", value: options.zoomType),
            URLQueryItem(name: "tailoring", value: "empty")
        ]
        return comps.url
    }

    /// Fetch a single vehicle image for a specific angle with simple in-memory caching.
    static func fetchVehicleImage(make: String,
                                  modelFamily: String,
                                  year: String,
                                  paintId: String,
                                  angle: Int,
                                  options: VehicleImageOptions = VehicleImageOptions(),
                                  completion: @escaping (Result<UIImage, Error>) -> Void) {
        let cacheKey = NSNumber(value: angle)
        if let cached = cache.object(forKey: cacheKey) {
            completion(.success(cached))
            return
        }
        var opt = options
        opt.angle = angle
        fetchVehicleImage(make: make, modelFamily: modelFamily, year: year, paintId: paintId, options: opt) { result in
            if case .success(let img) = result {
                cache.setObject(img, forKey: cacheKey)
            }
            completion(result)
        }
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
            URLQueryItem(name: "fileType", value: options.fileType),
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

    /// Preload a sequence of angles (default 200...231) and report progress.
    /// - Parameters:
    ///   - angles: Angles list. Defaults to `defaultAngles`.
    ///   - progress: Called on the main thread with (completed, total) as items finish.
    ///   - completion: Called on the main thread with an ordered array of images aligned to `angles`.
    static func preloadImages(make: String,
                              modelFamily: String,
                              year: String,
                              paintId: String,
                              angles: [Int] = defaultAngles,
                              options: VehicleImageOptions = VehicleImageOptions(),
                              progress: ((Int, Int) -> Void)? = nil,
                              completion: @escaping ([UIImage?]) -> Void) {
        let total = angles.count
        if total == 0 { completion([]); return }

        var results: [Int: UIImage] = [:]
        let group = DispatchGroup()
        let lock = NSLock()

        for angle in angles {
            group.enter()
            fetchVehicleImage(make: make, modelFamily: modelFamily, year: year, paintId: paintId, angle: angle, options: options) { result in
                if case .success(let img) = result {
                    lock.lock(); results[angle] = img; lock.unlock()
                }
                let done = results.count
                DispatchQueue.main.async { progress?(done, total) }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            // Map results back to the requested order; missing items become nil
            let ordered = angles.map { results[$0] }
            completion(ordered)
        }
    }

    static func fetchVehicleImage(make: String, modelFamily: String,year : String, paintId: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let options = VehicleImageOptions()
        fetchVehicleImage(make: make, modelFamily: modelFamily, year: year, paintId: paintId, options: options, completion: completion)
    }

    /// Clears the in-memory image cache (useful when switching car/paint).
    static func clearCache() {
        cache.removeAllObjects()
    }
}
