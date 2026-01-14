//
//  BugReport.swift
//  TyreVibes
//
//  Created by Claude on 31/10/2025.
//

import Foundation
import UIKit

// MARK: - Device Info

struct DeviceInfo: Codable {
    let model: String
    let osVersion: String
    let appVersion: String
    let buildVersion: String

    enum CodingKeys: String, CodingKey {
        case model
        case osVersion = "os_version"
        case appVersion = "app_version"
        case buildVersion = "build_version"
    }

    static var current: DeviceInfo {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        return DeviceInfo(
            model: device.model,
            osVersion: device.systemVersion,
            appVersion: appVersion,
            buildVersion: buildVersion
        )
    }
}

// MARK: - Report Type

enum ReportType: String, Codable, CaseIterable {
    case bug = "bug"
    case feedback = "feedback"
    
    var title: String {
        switch self {
        case .bug: return "Segnala Bug"
        case .feedback: return "Invia Feedback"
        }
    }
}

// MARK: - Bug Report Request

struct BugReportRequest: Codable {
    let userId: String?
    let description: String
    let screenshot: String?
    let deviceInfo: DeviceInfo
    let timestamp: String
    let type: ReportType
    let breadcrumbs: [String]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case description
        case screenshot
        case deviceInfo = "device_info"
        case timestamp
        case type
        case breadcrumbs
    }
}

// MARK: - Bug Report Response

struct BugReportResponse: Codable {
    let id: Int
    let message: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case message
        case createdAt = "created_at"
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func toBase64(compressionQuality: CGFloat = 0.7) -> String? {
        guard let imageData = self.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        return imageData.base64EncodedString()
    }
}

// MARK: - Screenshot Capture

extension UIApplication {
    func captureScreenshot() -> UIImage? {
        guard let window = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows
            .first(where: { $0.isKeyWindow }) else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { context in
            window.layer.render(in: context.cgContext)
        }
    }
}
