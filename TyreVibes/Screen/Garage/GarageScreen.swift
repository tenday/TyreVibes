import SwiftUI



struct GarageScreen: View {
    @State private var searchText = ""
    @State private var isPresentingSheet = false
    
    let cars = [
        Car(name: "Audi Q3", code: "FN841WA", make: "Audi", model: "Q3", year: "2024", engine: "1.6 ETS", imageName: "audi_q3"),
        Car(name: "Seat Leon", code: "TEST567", make: "Audi", model: "Q3", year: "2024", engine: "1.6 ETS", imageName: "seat_leon"),
        Car(name: "Audi Q8", code: "TEST123", make: "Audi", model: "Q3", year: "2024", engine: "1.6 ETS", imageName: "audi_q8")
    ]
    
    var body: some View {
        ZStack {
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top header
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
                        TextField("Search...", text: $searchText)
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
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 40, height: 5)
                            .padding(.top, 10)

                        Spacer().frame(height: 10)

                        VStack(spacing: 16) {
                            Button(action: {
                                // Azione per la scansione targa
                            }) {
                                HStack {
                                    Image(systemName: "camera")
                                        .foregroundColor(.cyan)
                                        .font(.system(size: 20))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Scan License Plate")
                                            .foregroundColor(.white)
                                            .font(.customFont(size: 16, weight: .semibold))
                                        Text("Auto fill vehicles details")
                                            .foregroundColor(.gray)
                                            .font(.customFont(size: 12, weight: .regular))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.cyan)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.cyan, lineWidth: 1)
                                )
                            }

                            HStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 1)
                                Text("OR")
                                    .foregroundColor(.gray)
                                    .font(.customFont(size: 12, weight: .regular))
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 1)
                            }

                            Button(action: {
                                // Azione per inserimento manuale
                            }) {
                                HStack {
                                    Text("Enter License Plate Manually")
                                        .foregroundColor(.white)
                                        .font(.customFont(size: 16, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.cyan)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.cyan, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 24)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.customBackgroundColor)
                    .presentationDetents([.medium])
                }
                
                
                
                
                // Cars ScrollView
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 18) {
                        if cars.isEmpty {
                            Text("No veichles found, pls add a new one")
                                .font(.customFont(size: 18, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        ForEach(cars, id: \.id) { car in
                            CarCardView(car: car)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top,16)
               
            }
            
            VStack (spacing : 0){
                Spacer()
                //BottomNavigationView()
            }
            .edgesIgnoringSafeArea(.bottom)
        }
    }
}


struct CarCardView: View {
    let car: Car
    
    var body: some View {
        ZStack {
            // Card background with gradient border effect
            ZStack(alignment: .leading) {
                Image("CardModel")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .shadow(color: Color(red: 0.36, green: 0.92, blue: 1), radius: 0, x: 10, y: 0)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 2, y: 0)

            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 12) {
                            Text(car.name)
                                .foregroundColor(.black)
                                .font(.customFont(size: 16, weight: .semibold))
                            
                            Text(car.code)
                                .font(.customFont(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.bottom, 60)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Button(action: {}) {
                            Image("shareIcon")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        
                        Button(action: {}) {
                            Image("detailsIcon")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.bottom, 60)
                }
                .padding(.horizontal, 20)
                
                HStack {
                 
                    
                    ZStack {
                        // Car body shape
                        RoundedRectangle(cornerRadius: 12)
                            
                            .frame(width: 120, height: 60)
                        
                        // Simple car details
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.black.opacity(0.3))
                                .frame(width: 12, height: 12)
                            
                            Spacer()
                            
                            Circle()
                                .fill(.black.opacity(0.3))
                                .frame(width: 12, height: 12)
                        }
                        .frame(width: 100)
                        .offset(y: 2)
                    }
                    .offset(x: 15)
                    
                    Spacer()
                    
                    
                    // Technical Specs section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Technical Specs")
                                .font(.customFont(size: 12, weight: .semibold))
                                .foregroundColor(.black)
                            
                            Spacer()
                        }
                        
                        HStack(alignment: .top, spacing: 40) {
                            VStack(alignment: .leading, spacing: 8) {
                                SpecRow(label: "Make:", value: car.make)
                                SpecRow(label: "Model:", value: car.model)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                SpecRow(label: "Year:", value: car.year)
                                SpecRow(label: "Engine:", value: car.engine)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    
                }
                //.padding(.top, 18)
                
                
            }
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
