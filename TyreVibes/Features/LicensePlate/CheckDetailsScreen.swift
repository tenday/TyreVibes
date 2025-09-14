import SwiftUI

struct CheckDetailsView: View {
    
    @Environment(\.dismiss) private var navigationDismiss
    var onFullScreenDismiss: (() -> Void)? = nil
    
    var vehicleImage: UIImage?
    var plateData: PlateData?
    @State private var displayImage: UIImage?
    @State private var dateString: String = ""
    @State private var showConfirmDetailsScreen: Bool = false
    @State private var showCheckmark: Bool = false
    @State private var goToGarage: Bool = false
    @Binding var isContinueEnabled: Bool
    @ObservedObject var viewModel: ConfirmDetailsViewModel
    var body: some View {
        ZStack {
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Custom navigation bar
                HStack {
                    if !isContinueEnabled  {
                        Button(action: {
                           navigationDismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                            
                        }
                    }
                       
                    
                    Spacer()
                    
                    Text("Check Details")
                        .font(.customFont(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top)
                
                Spacer()
                
                // Vehicle card
                ZStack(alignment: .center) {
                  
                  ZStack {
                      VStack (spacing : 2){
                          Text("Modello:")
                              .font(.customFont(size: 16, weight: .regular))
                              .offset(y: -UIScreen.main.bounds.height * 0.175)
                              .foregroundColor(Color.white)
                          Text(plateData?.model ?? plateData?.modelDetails ?? "-")
                              .font(.customFont(size: 16, weight: .bold))
                              .offset(y: -UIScreen.main.bounds.height * 0.175)
                              .foregroundColor(Color.white)
                      }
                      
                      Image("ellipse")
                          .offset(y: -UIScreen.main.bounds.height * 0.137)
                      Image("cardCheckDetails")
                          .resizable()
                          .scaledToFit()
                  }
                  .padding(.horizontal, 24)
                    
                    Button(action: {
                        showConfirmDetailsScreen = true
                    }) {
                        VStack(spacing: 50) {
                            // Model pill
                            if !isContinueEnabled {
                                HStack {
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.black)
                                        .frame(width: 24, height: 24)
                                }
                                .padding(.horizontal, 35)
                            }
                            if(isContinueEnabled) {
                                Spacer().frame(height: 20)
                            }
                            
                            
                            ZStack {
                                ZStack {
                                    Color.clear
                                    if let rawImage = viewModel.vehicleImage ?? vehicleImage {
                                        let trimmed = rawImage.trimmedTransparentPixels(threshold: 5)
                                        Image(uiImage: trimmed)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 280, height: 180)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .clipped()
                                    }
                                }
                                .frame(width: 280, height: 180)
                                
                              Image("vector")
                                    .opacity(showCheckmark ? 1 : 0)
                                    .scaleEffect(showCheckmark ? 1.5 : 0.6)
                                    .allowsHitTesting(false)
                                    .animation(.spring(response: 2, dampingFraction: 1), value: showCheckmark)
                            }
                            
                            
                            if !isContinueEnabled {
                                if let date = plateData?.registrationDate {
                                    let comps = date.split(separator: "-")
                                    let formatted = (comps.count == 3) ? "\(comps[1])/\(comps[2])" : date
                                    Text(formatted)
                                        .font(.customFont(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                        .offset(y: UIScreen.main.bounds.height * -0.04)

                                }
                            }
                           
                            

                        }
                    }
                    .disabled(isContinueEnabled)
                }
                
                Spacer()
                
                Button(action: {
                    // Se ho una closure per chiudere la fullScreenCover (Scan/Enter), usala per tornare al Garage con animazione dall’alto al basso.
                    if let closeFullScreen = onFullScreenDismiss {
                        closeFullScreen()
                    } else {
                        // Altrimenti fai pop della navigation (caso di push da ConfirmDetailsView)
                        navigationDismiss()
                    }
                }) {
                    Text("Continue")
                        .font(.customFont(size: 18, weight: .bold))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                }
                .background(Color.customBitterSweet)
                .cornerRadius(100)
                .opacity(isContinueEnabled ? 1.0 : 0.6)
                .disabled(!isContinueEnabled)
                .padding(.horizontal, 24)
            }
        }
        .navigationDestination(isPresented: $showConfirmDetailsScreen) {
            if let plateData = plateData {
                ConfirmDetailsView(
                    plateData: plateData,
                    manualEntryEnabled: false,
                    viewModel: viewModel,
                    onFullScreenDismiss: onFullScreenDismiss
                )
                .navigationBarBackButtonHidden(true)
            } else {
                Text("Nessun dato disponibile")
            }
        }
        .navigationDestination(isPresented: $goToGarage) {
            GarageScreen()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if isContinueEnabled {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showCheckmark = true
                }
            }
        }
        .onChange(of: isContinueEnabled) { oldValue, newValue in
            if newValue {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showCheckmark = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    showCheckmark = false
                }
            }
        }
    }
}

#Preview {
    CheckDetailsView(isContinueEnabled: .constant(true), viewModel: ConfirmDetailsViewModel())
}
