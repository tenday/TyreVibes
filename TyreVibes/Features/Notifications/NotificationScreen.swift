
import SwiftUI

struct NotificationScreen: View {
    @StateObject private var store = NotificationStore()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    header

                    if store.getAllNotifications().isEmpty {
                        emptyState
                    } else {
                        // Notifications List
                        List {
                            ForEach(store.getAllNotifications()) { notification in
                                ZStack {
                                    NavigationLink(destination: Text("Details for \(notification.title)")) {
                                        EmptyView()
                                    }
                                    .opacity(0) // Hide the navigation arrow

                                    NotificationRow(notification: notification) {
                                        store.markAsRead(notification.id)
                                    }
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                            .onDelete(perform: deleteNotification)
                        }
                        .listStyle(.plain)
                        .padding(.top, 10)
                    }
                }
            }
            .navigationBarHidden(true)
            .background(InteractivePopGestureEnabler())
        }
    }

    private func deleteNotification(at offsets: IndexSet) {
        let notificationsToDelete = offsets.map { store.getAllNotifications()[$0] }
        for notification in notificationsToDelete {
            store.deleteNotification(notification: notification)
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Back Button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }

                // Title
                Text("Notifications")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // Mark all as read
                if !store.getAllNotifications().isEmpty && store.unreadCount > 0 {
                    Button(action: {
                        withAnimation {
                            store.markAllAsRead()
                        }
                    }) {
                        Text("Mark all as read")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 1.0, green: 0.27, blue: 0.23))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bell.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Notifications")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text("You're all caught up!")
                .font(.system(size: 16))
                .foregroundColor(.gray)

            Spacer()
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left colored border
                Rectangle()
                    .fill(notification.type.color)
                    .frame(width: 4)
                    .cornerRadius(2, corners: [.topLeft, .bottomLeft])

                HStack(alignment: .top, spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(notification.type.color.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: notification.type.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(notification.type.color)
                    }
                    .padding(.leading, 12)

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(notification.message)
                            .font(.system(size: 14))
                            .foregroundColor(Color(white: 0.7))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)

                            Text(notification.relativeTime)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 12)

                    Spacer()

                    // Unread indicator
                    if !notification.isRead {
                        Circle()
                            .fill(notification.type.color)
                            .frame(width: 8, height: 8)
                            .padding(.trailing, 16)
                            .padding(.top, 20)
                    }
                }
                .padding(.trailing, notification.isRead ? 16 : 0)
            }
            .background(Color(white: 0.1))
            .cornerRadius(12)
            .opacity(notification.isRead ? 0.6 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    NotificationScreen()
}
