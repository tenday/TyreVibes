import SwiftUI
import PhotosUI

struct ProfileView: View {
    var onDetected: ((String) -> Void)? = nil
    var onFullScreenDismiss: (() -> Void)? = nil
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var loginViewModel = LoginViewModel()
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @Environment(\.dismiss) private var dismiss

    @State private var showEditSheet = false
    @State private var showLogoutAlert = false
    @State private var selectedImage: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        profileHeader
                            .padding(.top, 20)
                            .padding(.bottom, 40)

                        communicationPreferencesSection

                        privacySection

                        recentActivitySection

                        logoutButton
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Profilo").font(.customFont(size: 20, weight: .semibold)).foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showEditSheet = true }) {
                        Image(systemName: "pencil").foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                viewModel.loadUserProfile()
                viewModel.loadPreferences()
            }
            .scrollIndicators(.hidden)
          //  .onChange(of: viewModel.preferences) { _, _ in
          //      Task { await viewModel.savePreferences() }
          //  }
            .sheet(isPresented: $showEditSheet) {
                EditProfileSheet(viewModel: viewModel)
            }
            .alert("Logout", isPresented: $showLogoutAlert) {
                Button("Annulla", role: .cancel) {}
                Button("Esci", role: .destructive) { performLogout() }
            } message: {
                Text("Sei sicuro di voler uscire?")
            }
            .overlay(Group {
                if viewModel.isLoading {
                    ProgressView().scaleEffect(1.5).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black.opacity(0.3))
                }
            })
        }
    }

    private var communicationPreferencesSection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: "Preferenze di Comunicazione")

            VStack(spacing: 12) {
                toggleRow(title: "Ricevi notifiche email", isOn: $viewModel.preferences.emailNotifications)
                toggleRow(title: "Ricevi aggiornamenti prodotto", isOn: $viewModel.preferences.productUpdates)
                toggleRow(title: "Ricevi notifiche SMS", isOn: $viewModel.preferences.smsNotifications)
                toggleRow(title: "Ricevi avvisi di sicurezza", isOn: $viewModel.preferences.securityAlerts)
                toggleRow(title: "Ricevi email di marketing", isOn: $viewModel.preferences.marketingEmails)
            }
            .padding(.bottom, 40)
        }
    }

    private var privacySection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: "Impostazioni Privacy")

            VStack(spacing: 12) {
                toggleRow(title: "Profilo visibile", isOn: $viewModel.preferences.profileVisible)
                toggleRow(title: "Raccolta dati", isOn: $viewModel.preferences.dataCollection)
                toggleRow(title: "Cronologia attività", isOn: $viewModel.preferences.activityHistory)
            }
            .padding(.bottom, 40)
        }
    }

    private var recentActivitySection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: "Attività Recente")

            VStack(spacing: 0) {
                ForEach(viewModel.recentActivities) { activity in
                    activityRow(activity: activity)
                }
            }
            .padding(.bottom, 40)
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let image = viewModel.profileImage {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: 100, height: 100).clipShape(Circle())
                } else {
                    Circle().fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 100, height: 100)
                        .overlay(Text(viewModel.userProfile?.name.prefix(1).uppercased() ?? "U").font(.system(size: 40, weight: .bold)).foregroundColor(.white))
                }
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Circle().fill(.white).frame(width: 32, height: 32).overlay(Image(systemName: "camera.fill").font(.system(size: 14)).foregroundColor(.cyan))
                }
            }
            Text(viewModel.userProfile?.name ?? "Caricamento...").font(.customFont(size: 24, weight: .bold)).foregroundColor(.white)
            if let email = viewModel.userProfile?.email {
                Text(email).font(.customFont(size: 16, weight: .regular)).foregroundColor(.gray)
            }
            if let phone = viewModel.userProfile?.phone {
                Text(phone).font(.customFont(size: 16, weight: .regular)).foregroundColor(.white)
            }
        }
        .onChange(of: selectedImage) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                    await viewModel.uploadProfileImage(uiImage)
                }
            }
        }
    }

    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title).font(.customFont(size: 20, weight: .bold)).foregroundColor(.white)
            Spacer()
        }.padding(.bottom, 16)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.customFont(size: 16, weight: .regular)).foregroundColor(.white)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(.cyan)
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.3), lineWidth: 1)))
    }

    private func activityRow(activity: ActivityItem) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.cyan.opacity(0.2)).frame(width: 44, height: 44)
                Image(systemName: activity.icon).font(.system(size: 18)).foregroundColor(.cyan)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title).font(.customFont(size: 16, weight: .semibold)).foregroundColor(.white)
                Text(activity.subtitle).font(.customFont(size: 14, weight: .regular)).foregroundColor(.gray)
            }
            Spacer()
            Text(activity.time).font(.customFont(size: 12, weight: .regular)).foregroundColor(.gray)
        }.padding(.vertical, 16)
    }

    private var logoutButton: some View {
        Button(action: {
            showLogoutAlert = true
        }) {
            HStack {
                Image(systemName: "arrow.right.square").font(.system(size: 20))
                Text("Esci").font(.customFont(size: 18, weight: .semibold)).foregroundColor(.white)
            }
            .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 56)
            .background(Color.customBitterSweet)
            .cornerRadius(100)
        }
    }

    private func performLogout() {
        Task { @MainActor in
            do {
                try await AuthService().logout()
                KeychainHelper.delete()
                UserDefaults.standard.set(false, forKey: "rememberMe")
                UserDefaults.standard.set(false, forKey: "useFaceID")
                UserDefaults.standard.removeObject(forKey: "cachedVehicles")
                UserDefaults.standard.removeObject(forKey: "userPreferences")

                isLoggedIn = false

                // Post the notification to inform the app about the logout
                NotificationCenter.default.post(name: .didRequestLogout, object: nil)

                loginViewModel.showHomeScreen = false
                loginViewModel.email = ""
                loginViewModel.password = ""
                loginViewModel.rememberMe = false

                onFullScreenDismiss?()
                dismiss()
            } catch {
                print("Errore logout: \(error.localizedDescription)")
            }
        }
    }
}

struct EditProfileSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.customBackgroundColor.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nome").font(.customFont(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                        TextField("", text: $name).font(.customFont(size: 16, weight: .regular)).foregroundColor(.white).padding().background(Color.white.opacity(0.05)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email").font(.customFont(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                        TextField("", text: $email).font(.customFont(size: 16, weight: .regular)).foregroundColor(.white).keyboardType(.emailAddress).textInputAutocapitalization(.never).padding().background(Color.white.opacity(0.05)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Telefono").font(.customFont(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                        TextField("", text: $phone).font(.customFont(size: 16, weight: .regular)).foregroundColor(.white).keyboardType(.phonePad).padding().background(Color.white.opacity(0.05)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                    }
                    Spacer()
                    Button(action: { Task { await viewModel.updateProfile(name: name, email: email, phone: phone); dismiss() } }) {
                        Text("Salva Modifiche").font(.customFont(size: 18, weight: .semibold)).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 56).background(Color.cyan).cornerRadius(16)
                    }
                }.padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("Modifica Profilo").font(.customFont(size: 20, weight: .semibold)).foregroundColor(.white) }
                ToolbarItem(placement: .navigationBarLeading) { Button(action: { dismiss() }) { Image(systemName: "xmark").foregroundColor(.white) } }
            }
            .onAppear { name = viewModel.userProfile?.name ?? ""; email = viewModel.userProfile?.email ?? ""; phone = viewModel.userProfile?.phone ?? "" }
        }
    }
}

#Preview { ProfileView() }
