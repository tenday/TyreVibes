//
//  UpcomingMaintenanceView.swift
//  TyreVibes
//
//  Created on 2025-10-04.
//  Component to display upcoming maintenance schedule
//

import SwiftUI

struct UpcomingMaintenanceView: View {
    let maintenances: [MaintenanceSchedule]
    @State private var expandedId: String? = nil

    var sortedMaintenances: [MaintenanceSchedule] {
        maintenances.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))

                Text("Upcoming Maintenance")
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if !maintenances.isEmpty {
                    Text("\(maintenances.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color(red: 0.0, green: 0.48, blue: 1.0))
                        .clipShape(Circle())
                }
            }

            if maintenances.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(sortedMaintenances) { maintenance in
                        MaintenanceCard(
                            maintenance: maintenance,
                            isExpanded: expandedId == maintenance.id
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                expandedId = expandedId == maintenance.id ? nil : maintenance.id
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.customFieldColor)
        .cornerRadius(14)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)

            Text("All caught up!")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Text("No upcoming maintenance scheduled")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

struct MaintenanceCard: View {
    let maintenance: MaintenanceSchedule
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            mainContent
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            if isExpanded {
                expandedSection
            }
        }
        .background(Color(white: 0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    maintenance.isOverdue ? Color.red.opacity(0.5) : Color.gray.opacity(0.2),
                    lineWidth: 1
                )
        )
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            iconView
            infoView
            Spacer()
            expandIcon
        }
        .padding(12)
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(maintenance.type.color.opacity(0.15))
                .frame(width: 48, height: 48)

            Image(systemName: maintenance.type.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(maintenance.type.color)
        }
    }

    private var infoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(maintenance.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            HStack(spacing: 8) {
                dateBadge
                if maintenance.priority == .high || maintenance.priority == .critical {
                    priorityBadge
                }
            }
        }
    }

    private var dateBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 11))

            Text(maintenance.relativeTimeString)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(maintenance.isOverdue ? .red : .cyan)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((maintenance.isOverdue ? Color.red : Color.cyan).opacity(0.15))
        .cornerRadius(6)
    }

    private var priorityBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))

            Text(maintenance.priority.label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(maintenance.priority.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(maintenance.priority.color.opacity(0.15))
        .cornerRadius(6)
    }

    private var expandIcon: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.gray)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
    }

    private var expandedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(Color.gray.opacity(0.3))

            VStack(alignment: .leading, spacing: 8) {
                Text(maintenance.description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)

                if let metadata = maintenance.metadata {
                    metadataView(metadata)
                }

                if let cost = maintenance.estimatedCost {
                    costView(cost)
                }

                actionButton
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func metadataView(_ metadata: MaintenanceSchedule.MaintenanceMetadata) -> some View {
        VStack(spacing: 6) {
            if let mileage = metadata.currentMileage,
               let targetMileage = metadata.targetMileage {
                MetadataRow(
                    icon: "speedometer",
                    label: "Mileage",
                    value: "\(mileage) → \(targetMileage) km"
                )
            }

            if let treadDepth = metadata.currentTreadDepth {
                MetadataRow(
                    icon: "ruler",
                    label: "Tread Depth",
                    value: String(format: "%.1f mm", treadDepth)
                )
            }

            if let dueInDays = metadata.dueInDays {
                MetadataRow(
                    icon: "clock",
                    label: "Due in",
                    value: "\(dueInDays) days"
                )
            }

            if let lastService = metadata.lastServiceDate {
                MetadataRow(
                    icon: "wrench.and.screwdriver",
                    label: "Last Service",
                    value: formattedDate(lastService)
                )
            }
        }
    }

    private func costView(_ cost: Double) -> some View {
        HStack {
            Image(systemName: "eurosign.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.green)

            Text("Estimated Cost:")
                .font(.system(size: 13))
                .foregroundColor(.gray)

            Spacer()

            Text(String(format: "€%.0f", cost))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.green)
        }
        .padding(.top, 4)
    }

    private var actionButton: some View {
        Button(action: {
            // TODO: Navigate to schedule service
        }) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 14))

                Text("Schedule Service")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(maintenance.type.color)
            .cornerRadius(8)
        }
        .padding(.top, 8)
    }
}

struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.cyan)
                .frame(width: 20)

            Text(label + ":")
                .font(.system(size: 13))
                .foregroundColor(.gray)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 20) {
                UpcomingMaintenanceView(maintenances: MaintenanceSchedule.samples)

                UpcomingMaintenanceView(maintenances: [])
            }
            .padding()
        }
    }
}
