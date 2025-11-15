//
//  UserPreferences.swift
//  TyreVibes
//
//  Created by Claude on 15/11/25.
//

import Foundation

// Modello per la tabella 'user_preferences'
struct UserPreferencesModel: Codable {
    var id: UUID?
    var userId: UUID
    var emailNotifications: Bool
    var productUpdates: Bool
    var smsNotifications: Bool
    var securityAlerts: Bool
    var marketingEmails: Bool
    var profileVisible: Bool
    var dataCollection: Bool
    var activityHistory: Bool
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case emailNotifications = "email_notifications"
        case productUpdates = "product_updates"
        case smsNotifications = "sms_notifications"
        case securityAlerts = "security_alerts"
        case marketingEmails = "marketing_emails"
        case profileVisible = "profile_visible"
        case dataCollection = "data_collection"
        case activityHistory = "activity_history"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// Modello per la tabella 'user_activities'
struct UserActivityModel: Codable {
    var id: UUID?
    var userId: UUID
    var activityType: String
    var title: String
    var subtitle: String?
    var icon: String?
    var metadata: [String: String]?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case title
        case subtitle
        case icon
        case metadata
        case createdAt = "created_at"
    }
}
