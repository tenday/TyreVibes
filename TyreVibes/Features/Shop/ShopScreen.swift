import SwiftUI

struct ShopScreen: View {
    @State private var searchText = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Text("Marketplace")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Spacer()

                        Button(action: {}) {
                            Image(systemName: "bell")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)

                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search...", text: $searchText)
                            .foregroundColor(.white)
                        Button(action: {}) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // Filter Buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            FilterButton(text: "All Tires", isSelected: true)
                            FilterButton(text: "Winter")
                            FilterButton(text: "Summer")
                            FilterButton(text: "All Seasons")
                        }
                        .padding(.horizontal)
                    }

                    // Recommended for you
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Recommended for you")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Button("View All") {}
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal)

                        RecommendedTireView()
                            .padding(.horizontal)
                    }

                    // Featured Tires
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Featured Tires")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Button("View All") {}
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                FeaturedTireView()
                                FeaturedTireView()
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Nearby Dealers
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Nearby Dealers")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            Button("View Map") {}
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                NearbyDealerView()
                                NearbyDealerView()
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Checkout
                    VStack(alignment: .leading) {
                        Text("Checkout")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        CheckoutView()
                            .padding(.horizontal)
                    }

                    // Payment Methods
                    VStack {
                        HStack {
                            Image("paypal")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 25)
                            Image("mastercard")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 25)
                            Image("visa")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 25)
                            Image("amex")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 25)
                        }
                        .padding(.horizontal)
                    }

                    Button(action: {}) {
                        Text("Complete Purchase")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
    }
}

struct FilterButton: View {
    let text: String
    var isSelected: Bool = false

    var body: some View {
        Text(text)
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(10)
    }
}

struct RecommendedTireView: View {
    var body: some View {
        HStack(spacing: 15) {
            Image("tire")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 5) {
                Text("UltraGrip Performance")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("245/45R18 - All Season")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                    Text("426 reviews")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text("$ 188.99")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}

struct FeaturedTireView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image("tire")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .background(Color.accentColor.opacity(0.3))
                .cornerRadius(10)

            Text("WinterContact TS 870")
                .font(.headline)
                .foregroundColor(.white)
            Text("245/45R18")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text("$ 188.99")
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
        .frame(width: 200)
    }
}

struct NearbyDealerView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Premium Tire Shop")
                .font(.headline)
                .foregroundColor(.white)
            Text("456 Oak Ave, Westside")
                .font(.subheadline)
                .foregroundColor(.gray)

            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                Text("Available Today")
                    .font(.caption)
                    .foregroundColor(.green)
                Spacer()
                Text("1.2 mi")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            HStack {
                ServiceTag(text: "Rotation")
                ServiceTag(text: "Alignment")
                ServiceTag(text: "Balancing")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
        .frame(width: 250)
    }
}

struct ServiceTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.gray.opacity(0.4))
            .foregroundColor(.white)
            .cornerRadius(5)
    }
}

struct CheckoutView: View {
    var body: some View {
        VStack(spacing: 15) {
            CheckoutRow(label: "UltraGrip Performance 3 x 4", amount: "$759.96")
            CheckoutRow(label: "Installation Fee", amount: "$80.00")
            CheckoutRow(label: "Tax", amount: "$67.20")

            Divider().background(Color.gray)

            HStack {
                Text("Total")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("$907.16")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}

struct CheckoutRow: View {
    let label: String
    let amount: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(amount)
                .foregroundColor(.white)
        }
    }
}


struct ShopScreen_Previews: PreviewProvider {
    static var previews: some View {
        ShopScreen()
    }
}