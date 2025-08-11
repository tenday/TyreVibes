import SwiftUI



struct GarageScreen: View {
    @State private var searchText = ""
    @State private var isPresentingSheet = false
    
    @State private var cars: [Car] = [
        Car(name: "Audi Q3", plateCode: "FN841WA", make: "Audi", model: "Q3", year: "2024", engine: "1.6 eTSI", imageName: "audiQ3"),
        Car(name: "Seat Leon", plateCode: "TEST567", make: "Audi", model: "Q3", year: "2024", engine: "1.6 eTSI", imageName: "audiQ3"),
        Car(name: "Audi Q8", plateCode: "TEST123", make: "Audi", model: "Q3", year: "2024", engine: "1.6 ETS", imageName: "audiQ3"),
        Car(name: "Audi Q8", plateCode: "TEST123", make: "Audi", model: "Q3", year: "2024", engine: "1.6 ETS", imageName: "audiQ3"),
        Car(name: "Audi Q8", plateCode: "TEST123", make: "Audi", model: "TerraMar", year: "2024", engine: "1.6 tisdkg", imageName: "audiQ3")
    ]
    
    var body: some View {
        ZStack {
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Text("Garage")
                        .font(.customFont(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        HStack(alignment: .center) {
                            Button(action: {}) {
                                Image(systemName: "bell")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(
                                        ZStack {
                                            Circle()
                                                .fill(Color.customBackgroundColor)
                                            Circle()
                                                .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                                                .blur(radius: 1)
                                                .offset(x: 0.3, y: 1)
                                                .mask(
                                                    Circle().fill(LinearGradient(
                                                        gradient: Gradient(colors: [.black, .black]),
                                                        startPoint: .top,
                                                        endPoint: .bottom)
                                                    )
                                                )
                                            VisualEffectBlur(blurStyle:.systemUltraThinMaterial)
                                                .clipShape(Circle())
                                                .padding(12)
                                                .blur(radius: 40)
                                                .opacity(0.8)
                                        }
                                    )
                            }
                        }
                        .frame(width: 48, height: 48)
                        
                        HStack(alignment: .center) {
                            Button(action: {}) {
                                Image("UsernameIcon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(
                                        ZStack {
                                            Circle()
                                                .fill(Color.customBackgroundColor)

                                            Circle()
                                                .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                                                .blur(radius: 1)
                                                .offset(x: 0.3, y: 1)
                                                .mask(
                                                    Circle().fill(LinearGradient(
                                                        gradient: Gradient(colors: [.black, .black]),
                                                        startPoint: .top,
                                                        endPoint: .bottom)
                                                    )
                                                )
                                            
                                            VisualEffectBlur(blurStyle:.systemUltraThinMaterial)
                                                .clipShape(Circle())
                                                .padding(12)
                                                .blur(radius: 40)
                                                .opacity(0.8)
                                        }
                                    )
                                    
                                
                            }
                        }
                        .frame(width: 48, height: 48)
                        
                        
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                
                HStack(spacing: 10) {
                   
                    HStack (spacing: 12 ) {
                        Image("searchIcon")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.white)
                            .frame(height: 20)
                            .offset(x: 16)
                        TextField("Search...",  text: $searchText)
                            .frame(maxHeight: .infinity)
                            .font(.customFont(size: 16, weight: .semibold))
                            .disableAutocorrection(true)
                            .foregroundColor(.white)
                            .offset(x: 16)
                            .autocapitalization(.none)
                        
                    }
                    
                    .background(Color.customFieldColor)
                    .cornerRadius(35)
                    .frame(height: 48)
                    
                    
                    HStack {
                        Button(action: {
                            isPresentingSheet = true
                        }) {
                            Image("plusIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .shadow(color: Color.black.opacity(0.22), radius: 2 , x: 0 , y: 4)
    
                        }
                    }
                    .frame(width: 80, height: 48)
                    .background(Color.customFieldColor)
                    .cornerRadius(35)
                    
                    
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .sheet(isPresented: $isPresentingSheet) {
                    VStack(spacing: 20) {
                        Capsule()
                            .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                            .frame(width: 88, height: 4)
                            .padding(.top, 19)
                            

                        Spacer().frame(height: 15)

                        VStack(spacing: 16) {
                            Button(action: {
                                // Azione per la scansione targa
                            }) {
                                HStack {
                                    Image(systemName: "camera")
                                        .foregroundColor(.cyan)
                                        .font(.system(size: 20))
                                    Spacer().frame(width: 14)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Scan License Plate")
                                            .foregroundColor(.white)
                                            .font(.customFont(size: 16, weight: .semibold))
                                        Text("Auto fill vehicles details")
                                            .foregroundColor(.white.opacity(0.8))
                                            .font(.customFont(size: 12, weight: .regular))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(
                                            LinearGradient(
                                                stops: [
                                                    Gradient.Stop(color: Color(red: 0.18, green: 0.72, blue: 1), location: 0.00),
                                                    Gradient.Stop(color: Color(red: 0.62, green: 0.92, blue: 0.85), location: 1.00),
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 24, height: 24)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            LinearGradient(
                                                stops: [
                                                    Gradient.Stop(color: Color(red: 0.18, green: 0.72, blue: 1), location: 0.00),
                                                    Gradient.Stop(color: Color(red: 0.62, green: 0.92, blue: 0.85), location: 1.00),
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1
                                        )
                                        .frame(height: 94)
                                )
                            }
                            .padding(.bottom, 31)

                            HStack {
                                Rectangle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(height: 1)
                                Text("OR")
                                    .foregroundColor(.white)
                                    .font(.customFont(size: 12, weight: .regular))
                                Rectangle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(height: 1)
                            }
                            .padding(.bottom,41)
                            

                            Button(action: {
                                // Azione per inserimento manuale
                            }) {
                                HStack {
                                    Text("Enter License Plate Manually")
                                        .foregroundColor(.white)
                                        .font(.customFont(size: 16, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(
                                            LinearGradient(
                                                stops: [
                                                    Gradient.Stop(color: Color(red: 0.18, green: 0.72, blue: 1), location: 0.00),
                                                    Gradient.Stop(color: Color(red: 0.62, green: 0.92, blue: 0.85), location: 1.00),
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            LinearGradient(
                                                stops: [
                                                    Gradient.Stop(color: Color(red: 0.18, green: 0.72, blue: 1), location: 0.00),
                                                    Gradient.Stop(color: Color(red: 0.62, green: 0.92, blue: 0.85), location: 1.00),
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1
                                        )
                                        .frame(height: 94)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.customBackgroundColor)
                    .presentationDetents([.fraction(0.45)])
                }
                
                List {
                    if cars.isEmpty {
                        Text("No veichles found,pls add a new one")
                            .font(.customFont(size: 18, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 24)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    ForEach(cars, id: \.id) { car in
                        SwipeableCarRow(car: car) {
                            delete(car)
                        }
                        .padding(.horizontal, 24)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 18, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)

                .background(Color.customBackgroundColor)
                .padding(.top,16)
               
            }
            
            VStack (spacing : 0){
                Spacer()
                //BottomNavigationView()
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }
    private func delete(_ car: Car) {
        if let idx = cars.firstIndex(where: { $0.id == car.id }) {
            cars.remove(at: idx)
        }
    }
}


struct CarCardView: View {
    let car: Car
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Card background fills the available size responsively
                ZStack(alignment: .leading) {
                    Image("CardModel")
                        .resizable()
                        .scaledToFill()
                        .frame(width: w, height: h)
                        .clipped()
                        .shadow(color: Color(red: 0.36, green: 0.92, blue: 1), radius: 0, x: 10, y: 0)
                        .shadow(color: .black.opacity(0.25), radius: 2, x: 2, y: 0)
                }

                VStack(alignment: .leading, spacing: h * 0.05) {
                    HStack {
                        VStack() {
                            HStack(spacing: 12) {
                                Text(car.name)
                                    .foregroundColor(.black)
                                    .font(.customFont(size: 16, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                Text(car.plateCode)
                                    .font(.customFont(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Button(action: {}) {
                                Image("shareIcon")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)

                            Button(action: {}) {
                                Image("detailsIcon")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, w * 0.04)
                    .padding(.top, w * -0.07 )

                    HStack(alignment: .center, spacing: w * 0.04) {
                        Image(car.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: w * 0.57)

                        // Technical Specs section
                        VStack(alignment: .leading, spacing: 12) {

                            VStack(alignment: .leading, spacing: 8) {
                                SpecRow(label: "Make:", value: car.make)
                                SpecRow(label: "Model:", value: car.model)
                                SpecRow(label: "Year:", value: car.year)
                                SpecRow(label: "Engine:", value: car.engine)
                            }
                        }
                        .padding(.trailing, w * 0.04)
                    }
                }
            }
        }
        .aspectRatio(2.05, contentMode: .fit)
    }
}

// Custom swipeable row for car card with delete action revealed behind the card
struct SwipeableCarRow: View {
    let car: Car
    let onDelete: () -> Void

    @State private var offsetX: CGFloat = 0
    @State private var isDragging = false
    @State private var offsetStart: CGFloat = 0

    private let revealWidth: CGFloat = 110.0   // quanto resta aperto dopo lo swipe
    private let deleteTrigger: CGFloat = 180.0 // soglia per eliminazione con full swipe

    var body: some View {
        ZStack {
            // Background dietro la card: pulsante "Elimina" allineato a destra, nell'area della shadow
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.spring()) { onDelete() }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Elimina")
                            .font(.customFont(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.red)
                            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                    )
                }
                .padding(.trailing, 24) // allineato con il padding orizzontale delle card
            }

            // Card che scorre a sinistra per rivelare il background
            CarCardView(car: car)
                .offset(x: offsetX)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8, coordinateSpace: .local)
                        .onChanged { value in
                            // Gestisci solo drag orizzontali; lascia i verticali alla List
                            let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                            guard isHorizontal else { return }
                            if !isDragging { isDragging = true; offsetStart = offsetX }
                            let proposed = offsetStart + value.translation.width
                            // vincola tra 0 e -revealWidth
                            offsetX = min(0, max(-revealWidth, proposed))
                        }
                        .onEnded { value in
                            let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                            guard isHorizontal else { isDragging = false; return }
                            let dx = value.translation.width
                            let opened = -min(0, max(-revealWidth, offsetStart + dx))
                            if opened > deleteTrigger {
                                withAnimation(.spring()) { onDelete() }
                            } else if opened > revealWidth * 0.6 {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { offsetX = -revealWidth }
                            } else {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { offsetX = 0 }
                            }
                            isDragging = false
                        }
                )
                .simultaneousGesture(
                    TapGesture().onEnded {
                        // Se è aperto, tocco sulla card la richiude
                        if offsetX != 0 {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { offsetX = 0 }
                        }
                    }
                )
        }
    }
}

struct SpecRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.customFont(size: 12, weight: .semibold))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.customFont(size: 12, weight: .semibold))
                .foregroundColor(.black)
        }
    }
}



struct TabBarItem: View {
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        Button(action: {}) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.orange)
                        .frame(width: 60, height: 40)
                }
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : .gray)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct GarageScreen_Previews: PreviewProvider {
    static var previews: some View {
        GarageScreen()
            .preferredColorScheme(.dark)
    }
}
