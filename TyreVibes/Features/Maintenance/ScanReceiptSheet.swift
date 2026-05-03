import SwiftUI
import VisionKit

struct ScanReceiptSheet: View {
    let vehicleId: Int
    let onSave: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: ScanReceiptViewModel
    @State private var capturePulse = false
    @State private var processingSweep = false
    @State private var formAppeared = false

    init(vehicleId: Int, onSave: (() -> Void)? = nil) {
        self.vehicleId = vehicleId
        self.onSave = onSave
        _viewModel = StateObject(wrappedValue: ScanReceiptViewModel(vehicleId: vehicleId))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.scannedImage == nil {
                    capturePromptView
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if viewModel.isProcessing {
                    processingView
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    reviewForm
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .navigationTitle("Scansiona ricevuta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                if viewModel.ocrCompleted {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Salva") {
                            if viewModel.save() {
                                AppHaptics.success()
                                onSave?()
                                dismiss()
                            }
                        }
                        .disabled(!viewModel.canSave)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showImagePicker) {
                ImagePickerView(
                    source: viewModel.imagePickerSource,
                    onImagePicked: { image in
                        viewModel.handleImagePicked(image)
                    },
                    onCancel: {
                        viewModel.showImagePicker = false
                    }
                )
            }
            .fullScreenCover(isPresented: $viewModel.showLiveScanner) {
                ReceiptLiveScannerView(
                    onImageCaptured: { image in
                        viewModel.handleImagePicked(image)
                    },
                    onCancel: {
                        viewModel.showLiveScanner = false
                    }
                )
            }
        }
    }

    // MARK: - Step 1: Capture Prompt

    private var capturePromptView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.cyan.opacity(capturePulse ? 0.18 : 0.45), lineWidth: 2)
                    .frame(width: capturePulse ? 124 : 104, height: capturePulse ? 124 : 104)
                    .opacity(capturePulse ? 0.4 : 1)

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 64))
                    .foregroundColor(.cyan)
                    .scaleEffect(capturePulse && !reduceMotion ? 1.04 : 1.0)
            }
            .animation(nil, value: capturePulse)

            Text("Scansiona la ricevuta")
                .font(.customFont(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text("Scansiona una nuova ricevuta o scegli una foto già salvata. I dati verranno estratti automaticamente.")
                .font(.customFont(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    Button {
                        AppHaptics.impact(.light)
                        viewModel.showLiveScanner = true
                    } label: {
                        Label("Scansiona con fotocamera", systemImage: "text.viewfinder")
                            .font(.customFont(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.cyan)
                            )
                    }
                    .pressScaleButtonStyle()
                } else if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        AppHaptics.impact(.light)
                        viewModel.imagePickerSource = .camera
                        viewModel.showImagePicker = true
                    } label: {
                        Label("Scatta nuova foto", systemImage: "camera.fill")
                            .font(.customFont(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.cyan)
                            )
                    }
                    .pressScaleButtonStyle()
                }

                Button {
                    AppHaptics.impact(.light)
                    viewModel.imagePickerSource = .photoLibrary
                    viewModel.showImagePicker = true
                } label: {
                    Label("Libreria foto", systemImage: "photo.on.rectangle")
                        .font(.customFont(size: 16, weight: .semibold))
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan, lineWidth: 1.5)
                        )
                }
                .pressScaleButtonStyle()
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "191919"))
        .onAppear {
            capturePulse = true
        }
        .onDisappear {
            capturePulse = false
        }
    }

    // MARK: - Step 2: Processing

    private var processingView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                if let image = viewModel.scannedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 220, height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.cyan.opacity(0.45), lineWidth: 1.5)
                        )
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, Color.cyan.opacity(0.65), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 3)
                                .shadow(color: .cyan.opacity(0.7), radius: 12)
                                .offset(y: processingSweep && !reduceMotion ? 244 : 12)
                        }
                        .shadow(color: .cyan.opacity(0.18), radius: 18, x: 0, y: 12)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        .scaleEffect(1.5)
                }
            }

            Text("Analisi in corso...")
                .font(.customFont(size: 16, weight: .medium))
                .foregroundColor(.white)
            Text("Estrazione dati dalla ricevuta")
                .font(.customFont(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "191919"))
        .onAppear {
            processingSweep = true
        }
        .onDisappear {
            processingSweep = false
        }
    }

    // MARK: - Step 3: Review Form

    private var reviewForm: some View {
        Form {
            // Scanned image preview
            if let image = viewModel.scannedImage {
                Section {
                    HStack {
                        Spacer()
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    Button {
                        AppHaptics.impact(.light)
                        viewModel.scannedImage = nil
                        viewModel.ocrCompleted = false
                    } label: {
                        Label("Scansiona di nuovo", systemImage: "arrow.clockwise")
                            .font(.customFont(size: 14, weight: .medium))
                    }
                } header: {
                    Text("Ricevuta scansionata")
                }
                .opacity(formAppeared ? 1 : 0)
                .offset(y: formAppeared || reduceMotion ? 0 : 10)
            }

            // Error banner
            if let error = viewModel.errorMessage {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.customFont(size: 13, weight: .regular))
                            .foregroundColor(.orange)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Maintenance details
            Section("Intervento") {
                Picker("Tipo", selection: $viewModel.maintenanceType) {
                    ForEach(MaintenanceSchedule.MaintenanceType.groupedByCategory, id: \.category) { group in
                        SwiftUI.Section(group.category.localizedName) {
                            ForEach(group.types, id: \.self) { type in
                                HStack(spacing: 8) {
                                    MaintenanceTypeIconView(type: type, size: 16)
                                    Text(type.localizedName)
                                }
                                    .tag(type)
                            }
                        }
                    }
                }

                TextField("Titolo", text: $viewModel.title)

                TextField("Note (opzionale)", text: $viewModel.note, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Dettagli") {
                DatePicker("Data", selection: $viewModel.date, displayedComponents: .date)

                HStack {
                    Text("Km")
                        .foregroundColor(.secondary)
                    TextField("Opzionale", text: $viewModel.mileageInput)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: viewModel.mileageInput) { _, newValue in
                            let filtered = newValue.filter(\.isNumber)
                            if filtered != newValue {
                                viewModel.mileageInput = filtered
                            }
                        }
                }

                HStack {
                    Text("Costo")
                        .foregroundColor(.secondary)
                    Spacer()
                    TextField("0,00", text: $viewModel.costText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("€")
                        .foregroundColor(.secondary)
                }

                TextField("Officina (opzionale)", text: $viewModel.workshopName)
            }

            // Raw OCR text
            if !viewModel.rawOCRText.isEmpty {
                Section {
                    DisclosureGroup("Testo OCR rilevato") {
                        Text(viewModel.rawOCRText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            formAppeared = false
            formAppeared = true
        }
        .animation(nil, value: viewModel.errorMessage)
    }
}
