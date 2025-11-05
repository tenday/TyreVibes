//
//  BugReportSheet.swift
//  TyreVibes
//
//  Created by Claude on 31/10/2025.
//

import SwiftUI

struct BugReportSheet: View {
    // MARK: - Environment

    @ObservedObject var manager: BugReportManager

    // MARK: - State

    @State private var bugDescription: String = ""
    @State private var includeScreenshot: Bool = true
    @FocusState private var isTextEditorFocused: Bool

    // MARK: - Constants

    private let maxCharacters = 1000

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color.customBackgroundColor
                .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                // Header
                headerView

                // Main Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Titolo e descrizione
                        titleSection

                        // Screenshot preview
                        if let screenshot = manager.getScreenshot() {
                            screenshotPreview(screenshot)
                        }

                        // Text Editor per descrizione bug
                        textEditorSection

                        // Toggle screenshot
                        screenshotToggle

                        // Character count
                        characterCountView

                        // Error message
                        if let error = manager.submissionError {
                            errorView(error)
                        }

                        // Success message
                        if manager.showSuccessAlert {
                            successView
                        }

                        // Submit button
                        submitButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onAppear {
            isTextEditorFocused = true
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Button(action: {
                manager.dismissSheet()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Text("Segnala Bug")
                .font(.customFont(size: 18, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            // Placeholder per bilanciare
            Color.clear
                .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.customGray.opacity(0.3)
                .background(.ultraThinMaterial)
        )
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.customSandyBrown)

                Text("Hai riscontrato un problema?")
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("Descrivi il bug che hai riscontrato. Il tuo feedback ci aiuta a migliorare l'app!")
                .font(.customFont(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Screenshot Preview

    private func screenshotPreview(_ screenshot: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Screenshot catturato")
                .font(.customFont(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Image(uiImage: screenshot)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 200)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        }
    }

    // MARK: - Text Editor Section

    private var textEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Descrizione del problema *")
                .font(.customFont(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.customFieldColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                // Placeholder
                if bugDescription.isEmpty {
                    Text("Descrivi cosa è successo, quali passaggi hai effettuato, e quale era il risultato atteso...")
                        .font(.customFont(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }

                // Text Editor
                TextEditor(text: $bugDescription)
                    .font(.customFont(size: 15, weight: .regular))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .focused($isTextEditorFocused)
                    .onChange(of: bugDescription) { oldValue, newValue in
                        if newValue.count > maxCharacters {
                            bugDescription = String(newValue.prefix(maxCharacters))
                        }
                    }
            }
            .frame(height: 180)
        }
    }

    // MARK: - Screenshot Toggle

    private var screenshotToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Includi screenshot")
                    .font(.customFont(size: 15, weight: .medium))
                    .foregroundColor(.white)

                Text("Lo screenshot aiuta a comprendere meglio il problema")
                    .font(.customFont(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Toggle("", isOn: $includeScreenshot)
                .labelsHidden()
                .tint(.customBitterSweet)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.customFieldColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Character Count

    private var characterCountView: some View {
        HStack {
            Spacer()
            Text("\(bugDescription.count)/\(maxCharacters)")
                .font(.customFont(size: 13, weight: .regular))
                .foregroundColor(bugDescription.count >= maxCharacters ? .customBitterSweet : .white.opacity(0.5))
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.customBitterSweet)

            Text(message)
                .font(.customFont(size: 14, weight: .medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.customBitterSweet.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.customBitterSweet.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Success View

    private var successView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)

            Text("Bug segnalato con successo!")
                .font(.customFont(size: 14, weight: .medium))
                .foregroundColor(.white)

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.green.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button(action: {
            Task {
                await manager.submitBugReport(
                    description: bugDescription,
                    includeScreenshot: includeScreenshot
                )
            }
        }) {
            HStack(spacing: 12) {
                if manager.isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                }

                Text(manager.isSubmitting ? "Invio in corso..." : "Invia Segnalazione")
                    .font(.customFont(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.customBitterSweet)
            .cornerRadius(100)
        }
        .disabled(manager.isSubmitting || bugDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity((manager.isSubmitting || bugDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.5 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    BugReportSheet(manager: BugReportManager())
}
