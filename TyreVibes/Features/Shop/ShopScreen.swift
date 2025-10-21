import SwiftUI

struct ShopScreen: View {
    @State private var selectedCategory = "All Tires"
    let categories = ["All Tires", "Winter", "Summer", "All Seasons"]
    
    var body: some View {
        ZStack {
            // Background
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Status Bar
                
                // App Bar with Marketplace title
                AppBarViewShop()
                
                // Search and Filter
                SearchFilterView()
                
                // Main Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Recommended for you section
                        SectionHeaderView(
                            title: "Recommended for you",
                            actionText: "View All",
                            actionColor: Color(hex: "#F36656")
                        )
                        
                        // Category Pills
                        CategoryPillsView(
                            categories: categories,
                            selectedCategory: $selectedCategory
                        )
                        
                        // UltraGrip Product Card
                        UltraGripCardView()
                        
                        // Featured Tires Section
                        SectionHeaderView(
                            title: "Featured Tires",
                            actionText: "View All",
                            actionColor: Color(hex: "#F36656")
                        )
                        
                        // Featured Products (Horizontal Scroll)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                FeaturedTireCardView(
                                    title: "WinterContact TS",
                                    subtitle: "870",
                                    size: "245/45R18",
                                    price: "$ 188.99"
                                )
                                FeaturedTireCardView(
                                    title: "WinterContact TS",
                                    subtitle: "870",
                                    size: "245/45R18",
                                    price: "$ 188.99"
                                )
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // Nearby Dealers Section
                        SectionHeaderView(
                            title: "Nearby Dealers",
                            actionText: "View Map",
                            actionColor: Color(hex: "#F36656")
                        )
                        .padding(.horizontal, 24)
                        
                        // Dealers Cards
                        HStack(spacing: 16) {
                            DealerCardView(
                                name: "Premium Tire Shop",
                                address: "456 Oak Ave, Westside",
                                distance: "1.2 mi",
                                services: ["Rotation", "Balancing", "Alignment"],
                                isAvailable: true
                            )
                            
                            DealerCardView(
                                name: "City Auto Center",
                                address: "123 Main St, Downtown",
                                distance: "0.8 mi",
                                services: ["Installation", "Balancing", "Alignment"],
                                isAvailable: true
                            )
                        }
                        .padding(.horizontal, 24)
                        
                        // Checkout Section Header
                        VStack(alignment: .leading) {
                            Text("Checkout")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        
                        // Checkout Summary
                        CheckoutSummaryView()
                        
                        // Divider
                        Divider()
                            .background(Color(hex: "#2FB8FF").opacity(0.2))
                            .padding(.horizontal, 24)
                        
                        // Payment Methods
                        PaymentMethodsView()
                        
                        // Complete Purchase Button
                        Button(action: {}) {
                            Text("Complete Purchase")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 62)
                                .background(Color(hex: "#F36656").opacity(0.5))
                                .foregroundColor(.white)
                                .cornerRadius(100)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                    }
                    .padding(.top, 16)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - App Bar
struct AppBarViewShop: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Marketplace")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color(hex: "#191919"))
                    .cornerRadius(25)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - Search and Filter
struct SearchFilterView: View {
    var body: some View {
        HStack(spacing: 4) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white)
                
                Text("Search...")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(height: 48)
            .background(Color(hex: "#212121"))
            .cornerRadius(35)
            
            Button(action: {}) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color(hex: "#212121"))
                    .cornerRadius(25)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

// MARK: - Category Pills
struct CategoryPillsView: View {
    let categories: [String]
    @Binding var selectedCategory: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        Text(category)
                            .font(.system(size: 14, weight: .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(height: 34)
                            .background(
                                selectedCategory == category ?
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "#2FB8FF"),
                                        Color(hex: "#9EECD9")
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "#5CEBFF").opacity(0.05)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(
                                        selectedCategory == category ?
                                        Color(hex: "#2FB8FF") :
                                        Color(hex: "#5CEBFF").opacity(0.2),
                                        lineWidth: selectedCategory == category ? 2 : 1
                                    )
                            )
                            .foregroundColor(
                                selectedCategory == category ? Color(hex: "#212121") : .white
                            )
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - UltraGrip Product Card
struct UltraGripCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                // Product Image Placeholder
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#2FB8FF"), lineWidth: 2)
                    .frame(width: 140, height: 138)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .foregroundColor(Color(hex: "#2FB8FF").opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("UltraGrip Performance")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("245/45R18 · All Season")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#FFC37F"))
                            }
                        }
                        
                        Text("426 reviews")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                    }
                    
                    Text("$ 188.99")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .foregroundColor(Color(hex: "#5CEBFF").opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color(hex: "#5CEBFF").opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Featured Tire Card
struct FeaturedTireCardView: View {
    let title: String
    let subtitle: String
    let size: String
    let price: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Image placeholder
            RoundedRectangle(cornerRadius: 16)
                .foregroundColor(Color(hex: "#5CEBFF"))
                .frame(height: 122)
            
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(size)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            
            Spacer()
            
            Text(price)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .frame(width: 188)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .foregroundColor(Color(hex: "#5CEBFF").opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color(hex: "#5CEBFF").opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Section Header
struct SectionHeaderView: View {
    let title: String
    let actionText: String
    let actionColor: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {}) {
                Text(actionText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(actionColor)
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Dealer Card
struct DealerCardView: View {
    let name: String
    let address: String
    let distance: String
    let services: [String]
    let isAvailable: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(address)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text(distance)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .foregroundColor(Color(hex: "#5CEBFF").opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color(hex: "#5CEBFF").opacity(0.2), lineWidth: 1)
                        )
                }
            }
            
            if isAvailable {
                HStack(spacing: 8) {
                    Circle()
                        .foregroundColor(Color(hex: "#1CDA81"))
                        .frame(width: 8, height: 8)
                    
                    Text("Available Today")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "#1CDA81"))
                }
            }
            
            HStack(spacing: 8) {
                ForEach(services, id: \.self) { service in
                    Text(service)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(25)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .foregroundColor(Color(hex: "#5CEBFF").opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color(hex: "#5CEBFF").opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Checkout Summary
struct CheckoutSummaryView: View {
    var body: some View {
        VStack(spacing: 12) {
            CheckoutRowView(label: "UltraGrip Performance 3 × 4", price: "$759.96")
            CheckoutRowView(label: "Installation Fee", price: "$80.00")
            CheckoutRowView(label: "Tax", price: "$67.20")
            
            Divider()
                .background(Color(hex: "#2FB8FF").opacity(0.2))
            
            CheckoutRowView(label: "Total", price: "$907.16", isTotal: true)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .foregroundColor(Color(hex: "#5CEBFF").opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color(hex: "#5CEBFF").opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Checkout Row
struct CheckoutRowView: View {
    let label: String
    let price: String
    var isTotal: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: isTotal ? .semibold : .regular))
                .foregroundColor(isTotal ? .white : .white.opacity(0.6))
            
            Spacer()
            
            Text(price)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Payment Methods
struct PaymentMethodsView: View {
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 34, height: 40)
            
            Image(systemName: "creditcard.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 51, height: 40)
            
            Image(systemName: "creditcard.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 75, height: 24)
            
            Image(systemName: "creditcard.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 60, height: 40)
            
            Image(systemName: "creditcard.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 52, height: 40)
        }
        .padding(.vertical, 24)
    }
}

// MARK: - Navigation Tab
struct NavigationTabView: View {
    let icon: String
    let label: String
    
    var body: some View {
        Button(action: {}) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .frame(width: 48, height: 48)
            .background(Color.clear)
        }
    }
}


#Preview {
    ShopScreen()
}
