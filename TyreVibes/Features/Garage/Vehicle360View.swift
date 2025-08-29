import SwiftUI

struct Vehicle360View: View {
    let make: String
    let modelFamily: String
    let year: String
    let paintId: String
    let angles: [Int] = VehicleImageService.defaultAngles

    @State private var images: [UIImage?] = []
    @State private var currentIndex: Int = 0
    @State private var isPlaying: Bool = true
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // Immagine corrente
            Group {
                if let img = images[safe: currentIndex] ?? nil {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        //.onTapGesture { togglePlay() }
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture().onChanged(handleDrag))
        }
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
        VehicleImageService.preloadImages(
            make: make,
            modelFamily: modelFamily,
            year: year,
            paintId: paintId,
            angles: angles,
            progress: { _, _ in },
            completion: { ordered in
                images = ordered
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
        //  drag verso destra = avanti, verso sinistra = indietro
        let delta = value.translation.width
        guard angles.count > 0 else { return }
        let stepPer40pt = Int(delta / 40) // ogni ~40pt cambia frame (meno sensibile)
        var idx = currentIndex - stepPer40pt
        idx = (idx % angles.count + angles.count) % angles.count
        currentIndex = idx
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
            paintId: "blue"
        )
        .frame(height: 300)
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
