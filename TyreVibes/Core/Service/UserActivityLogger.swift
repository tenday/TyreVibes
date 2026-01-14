//
//  UserActivityLogger.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 11/05/25.
//

import Foundation

final class UserActivityLogger: ObservableObject {
    static let shared = UserActivityLogger()
    
    private var logs: [String] = []
    private let maxLogs = 30
    private let queue = DispatchQueue(label: "it.tyrevibes.activityLogger", qos: .utility)
    
    private init() {}
    
    func log(_ message: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let logEntry = "[\(timestamp)] \(message)"
            
            self.logs.append(logEntry)
            
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst()
            }
        }
    }
    
    func getLogs() -> [String] {
        return queue.sync {
            return logs
        }
    }
    
    func clearLogs() {
        queue.async { [weak self] in
            self?.logs.removeAll()
        }
    }
}
