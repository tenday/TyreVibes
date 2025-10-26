import SwiftUI

struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: ShopFilter
    @State private var tempFilter: ShopFilter

    init(filter: Binding<ShopFilter>) {
        self._filter = filter
        self._tempFilter = State(initialValue: filter.wrappedValue)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    ratingSection
                    distanceSection
                    optionsSection
                    priceRangeSection
                    sortSection
                }
                .padding()
            }
            .background(Color.customBackgroundColor)
            .navigationTitle("Filtri Avanzati")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                    .foregroundColor(.customAzure)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Applica") {
                        filter = tempFilter
                        dismiss()
                    }
                    .foregroundColor(.customAzure)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.customAzure, .customBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Personalizza la tua ricerca")
                .font(.customFont(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Valutazione Minima")
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            } icon: {
                Image(systemName: "star.fill")
                    .foregroundColor(.customSandyBrown)
            }

            HStack {
                ForEach(0..<5) { index in
                    Image(systemName: tempFilter.minRating > Double(index) ? "star.fill" : "star")
                        .font(.system(size: 24))
                        .foregroundColor(.customSandyBrown)
                }

                Spacer()

                Text(String(format: "%.1f+", tempFilter.minRating))
                    .font(.customFont(size: 18, weight: .bold))
                    .foregroundColor(.customAzure)
            }

            Slider(value: $tempFilter.minRating, in: 0...5, step: 0.5)
                .tint(.customAzure)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.customFieldColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Distanza Massima")
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            } icon: {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(.customBlue)
            }

            HStack {
                Text(distanceText)
                    .font(.customFont(size: 18, weight: .bold))
                    .foregroundColor(.customAzure)

                Spacer()

                Image(systemName: "arrow.left.and.right")
                    .foregroundColor(.white.opacity(0.5))
            }

            Slider(value: $tempFilter.maxDistance, in: 1_000...100_000, step: 1_000)
                .tint(.customBlue)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.customFieldColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var optionsSection: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $tempFilter.openNow) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aperto Ora")
                            .font(.customFont(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Text("Mostra solo officine aperte")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                } icon: {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.customPurple)
                }
            }
            .tint(.customPurple)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.customFieldColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private var priceRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Fascia di Prezzo")
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            } icon: {
                Image(systemName: "eurosign.circle.fill")
                    .foregroundColor(.customAzure)
            }

            VStack(spacing: 10) {
                ForEach(ShopFilter.PriceRange.allCases, id: \.self) { range in
                    priceRangeButton(range)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.customFieldColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func priceRangeButton(_ range: ShopFilter.PriceRange) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                tempFilter.priceRange = range
            }
        } label: {
            HStack {
                Text(range.rawValue)
                    .font(.customFont(size: 15, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                if tempFilter.priceRange == range {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.customAzure)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tempFilter.priceRange == range ? Color.customAzure.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Ordina Per")
                    .font(.customFont(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            } icon: {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .foregroundColor(.customBlue)
            }

            VStack(spacing: 10) {
                ForEach(ShopFilter.SortOption.allCases, id: \.self) { option in
                    sortOptionButton(option)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.customFieldColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func sortOptionButton(_ option: ShopFilter.SortOption) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                tempFilter.sortBy = option
            }
        } label: {
            HStack {
                Text(option.rawValue)
                    .font(.customFont(size: 15, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                if tempFilter.sortBy == option {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.customBlue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tempFilter.sortBy == option ? Color.customBlue.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var distanceText: String {
        let km = tempFilter.maxDistance / 1_000
        return String(format: "%.0f km", km)
    }
}

struct FilterSheet_Previews: PreviewProvider {
    static var previews: some View {
        FilterSheet(filter: .constant(ShopFilter()))
            .preferredColorScheme(.dark)
    }
}
