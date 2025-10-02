import SwiftUI

struct Vehicle360View: View {
    let make: String
    let modelFamily: String
    let year: String
    let paintId: String
    let angles: [Int] = VehicleImageService.defaultAngles

    @State private var images: [UIImage?] = []
    @State private var currentIndex: Int = 0
    @State private var isPlaying: Bool = false
    @State private var timer: Timer?
    @Binding var loadingProgress: Double
    @Binding var isLoading: Bool
    @State private var scale: CGFloat = 1.0
    @State private var baseIndex: Int = 0

    var body: some View {
        ZStack {
            Color.customBackgroundColor
                .ignoresSafeArea()

            // Immagine corrente - SEMPLICE E VELOCE
            if let imgOptional = images[safe: currentIndex], let img = imgOptional {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
            }

            // Controls
            if !isLoading {
                VStack {
                    Spacer()

                    HStack(spacing: 30) {
                        // Auto-rotate button
                        Button(action: togglePlay) {
                            ZStack {
                                Circle()
                                    .fill(Color.customFieldColor.opacity(0.9))
                                    .frame(width: 50, height: 50)

                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .shadow(color: .black.opacity(0.3), radius: 10)
                        }

                        // Rotation angle indicator
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 4)
                                .frame(width: 80, height: 80)

                            Circle()
                                .trim(from: 0, to: CGFloat(currentIndex) / CGFloat(max(angles.count - 1, 1)))
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.customBitterSweet, Color.orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentIndex)

                            Text("\(Int((Double(currentIndex) / Double(max(angles.count - 1, 1))) * 360))°")
                                .font(.customFont(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }

                        // Reset zoom button
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                scale = 1.0
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.customFieldColor.opacity(0.9))
                                    .frame(width: 50, height: 50)

                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .shadow(color: .black.opacity(0.3), radius: 10)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }

            // Loading overlay
            if isLoading {
                ZStack {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()

                    VStack(spacing: 25) {
                        // Animated logo
                        ZStack {
                            Circle()
                                .fill(Color.customBitterSweet.opacity(0.2))
                                .frame(width: 120, height: 120)
                                .scaleEffect(1.0 + sin(loadingProgress * .pi * 4) * 0.1)

                            Image("LogoImage")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(loadingProgress * 360))
                        }

                        VStack(spacing: 12) {
                            // Circular progress
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                                    .frame(width: 150, height: 150)

                                Circle()
                                    .trim(from: 0, to: loadingProgress)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.customBitterSweet, Color.orange, Color.yellow],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                    )
                                    .frame(width: 150, height: 150)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 0.3), value: loadingProgress)

                                Text("\(Int(loadingProgress * 100))%")
                                    .font(.customFont(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Caricamento vista 360°")
                                .font(.customFont(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))

                            Text("Preparazione immagini...")
                                .font(.customFont(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.customFieldColor)
                            .shadow(color: .black.opacity(0.5), radius: 30)
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged(handleDrag)
                .onEnded(handleDragEnd)
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = min(max(value, 0.5), 2.5)
                }
        )
        .onAppear {
            preload()
            stopTimer()
        }
        .onDisappear {
            stopTimer()
            VehicleImageService.clearCache()
        }
    }

    // MARK: - Logic

    private func preload() {
        images = Array(repeating: nil, count: angles.count)
        isLoading = true
        loadingProgress = 0.0

        VehicleImageService.preloadImages(
            make: make,
            modelFamily: modelFamily,
            year: year,
            paintId: paintId,
            angles: angles,
            progress: { loaded, total in
                DispatchQueue.main.async {
                    loadingProgress = Double(loaded) / Double(total)
                }
            },
            plate: "",
            completion: { ordered in
                DispatchQueue.main.async {
                    images = ordered
                    isLoading = false
                }
            }
        )
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) {
                currentIndex = (currentIndex + 1) % max(angles.count, 1)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func togglePlay() {
        isPlaying.toggle()
        isPlaying ? startTimer() : stopTimer()
    }

    private func handleDrag(_ value: DragGesture.Value) {
        if isPlaying {
            stopTimer()
            isPlaying = false
            baseIndex = currentIndex
        }

        let delta = value.translation.width
        guard angles.count > 0 else { return }

        // Sensibilità: ogni 15 punti = 1 frame (più responsivo)
        let sensitivity: CGFloat = 15.0
        let steps = -Int(delta / sensitivity)

        var newIndex = baseIndex + steps
        newIndex = ((newIndex % angles.count) + angles.count) % angles.count

        currentIndex = newIndex
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        baseIndex = currentIndex

        // Calcola la velocità del drag
        let velocity = value.predictedEndTranslation.width - value.translation.width

        if abs(velocity) > 50 {
            // Se c'è momentum, continua a ruotare
            let direction = velocity > 0 ? -1 : 1
            let steps = Int(abs(velocity) / 100)

            var targetIndex = currentIndex
            for _ in 0..<min(steps, 5) {
                targetIndex += direction
                targetIndex = ((targetIndex % angles.count) + angles.count) % angles.count
            }

            // Anima verso il target
            animateToIndex(targetIndex)
        }
    }

    private func animateToIndex(_ target: Int) {
        let distance = abs(target - currentIndex)
        let duration = 0.05 * Double(distance)

        withAnimation(.easeOut(duration: duration)) {
            currentIndex = target
        }
    }
}


fileprivate extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#if DEBUG
struct Vehicle360View_Previews: PreviewProvider {
    static var previews: some View {
        Vehicle360View(
            make: "seat",
            modelFamily: "leon",
            year: "2020",
            paintId: "GRAY",
            loadingProgress: .constant(0.5),
            isLoading: .constant(false)
        )
        .frame(height: 300)
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
