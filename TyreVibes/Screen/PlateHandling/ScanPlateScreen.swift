import SwiftUI
import AVFoundation
import Vision

struct CameraPreview: UIViewControllerRepresentable {
    class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
        let captureSession = AVCaptureSession()
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var permissionLabel: UILabel?

        override func viewDidLoad() {
            super.viewDidLoad()
            handleCameraAuthorization()
        }

        private func handleCameraAuthorization() {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                setupSession()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            self?.setupSession()
                        } else {
                            self?.showPermissionLabel(text: "Accesso fotocamera negato.\nAbilitalo in Impostazioni > Privacy > Fotocamera.")
                        }
                    }
                }
            case .denied, .restricted:
                showPermissionLabel(text: "Accesso fotocamera negato o limitato.\nAbilitalo in Impostazioni > Privacy > Fotocamera.")
            @unknown default:
                showPermissionLabel(text: "Impossibile accedere alla fotocamera.")
            }
        }

        private func setupSession() {
            #if targetEnvironment(simulator)
            showPermissionLabel(text: "La fotocamera non è disponibile nel Simulator.\nEsegui su un dispositivo reale.")
            return
            #else
            captureSession.sessionPreset = .photo

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  captureSession.canAddInput(videoInput) else {
                showPermissionLabel(text: "Impossibile inizializzare la fotocamera.")
                return
            }

            captureSession.addInput(videoInput)

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            guard captureSession.canAddOutput(videoOutput) else {
                showPermissionLabel(text: "Impossibile aggiungere output video.")
                return
            }
            captureSession.addOutput(videoOutput)

            let layer = AVCaptureVideoPreviewLayer(session: captureSession)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.insertSublayer(layer, at: 0)
            self.previewLayer = layer

            captureSession.startRunning()
            #endif
        }

        private func showPermissionLabel(text: String) {
            permissionLabel?.removeFromSuperview()
            let label = UILabel()
            label.text = text
            label.textColor = .white
            label.numberOfLines = 0
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
                label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
            permissionLabel = label
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let request = VNRecognizeTextRequest { (request, error) in
                // Handle recognized text here
            }

            // Calculate the region of interest centered in the previewLayer
            if let previewLayer = previewLayer {
                let videoWidth = previewLayer.bounds.width
                let videoHeight = previewLayer.bounds.height

                let widthNorm = 200 / videoWidth
                let heightNorm = 100 / videoHeight

                let originX = (1 - widthNorm) / 2
                let originY = (1 - heightNorm) / 2

                let originYFlipped = 1 - originY - heightNorm

                request.regionOfInterest = CGRect(x: originX, y: originYFlipped, width: widthNorm, height: heightNorm)
            }

            let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try? requestHandler.perform([request])
        }
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
    }
}

struct ScanPlateView: View {
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                CameraPreview()
                    .ignoresSafeArea()
                VStack(spacing: 20) {
                    HStack {
                        Button(action: {
                           dismiss()
                        }) {
                            Image("ArrowIcon")
                        }
                        Spacer()
                        
                        Text("Scan License Plate")
                            .font(.customFont(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.top)
                    .padding(.horizontal,24)
                    // Title
                   
                    
                    // License Plate Frame with Text
                    ZStack {
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .frame(width: 200, height: 100)
                            .foregroundColor(.white)
                            .overlay(
                                Text("PLATYPS")
                                    .foregroundColor(.yellow)
                                    .font(.title)
                                    .offset(y: -10)
                            )
                    }
                    .frame(width: 200, height: 100)
                    .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
                    
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Position License Plate within Frame")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("Ensure words are visible")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    // Detected License Plate Number
                    Text("Detected License Plate Number")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    Text("PLATYPS")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.cyan, lineWidth: 2)
                        )
                        .padding(.horizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.customBackgroundColor.edgesIgnoringSafeArea(.all))
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    ScanPlateView()
}
