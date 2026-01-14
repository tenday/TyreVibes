import Foundation
import Network
import Combine

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isReachable: Bool = true

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor.queue")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let nextValue = path.status == .satisfied
            DispatchQueue.main.async {
                self.isReachable = nextValue
            }
        }
        monitor.start(queue: monitorQueue)
    }
}
