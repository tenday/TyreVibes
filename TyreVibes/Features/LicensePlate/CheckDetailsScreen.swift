import SwiftUI

struct CheckDetailsView: View {
    
    @Environment(\.dismiss) private var dismiss
    var vehicleImage: UIImage?
    var plateData: PlateData?
    @State private var displayImage: UIImage?
    @State private var dateString: String = ""
    @State private var showConfirmDetailsScreen: Bool = false
    
    var body: some View {
        ZStack {
            Color.customBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Custom navigation bar
                HStack {
                    Button(action: {
                       dismiss()
                    }) {
                        Image("ArrowIcon")
                        
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
                      HStack (spacing : 2){
                          Text("Model:")
                              .font(.customFont(size: 16, weight: .regular))
                              .offset(y: -UIScreen.main.bounds.height * 0.175)
                              .foregroundColor(Color.white)
                          Text(plateData?.model ?? "")
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
                    
                    Button(action: { /* azione da eseguire */ }) {
                        VStack(spacing: 20) {
                            // Model pill
                            HStack {
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.black)
                                    .frame(width: 24, height: 24)
                            }
                            .padding(.horizontal, 39)
                            
                            
                            
                            ZStack {
                                Color.clear
                                if let image = vehicleImage {
                                    Image(uiImage: displayImage ?? image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 280, height: 180)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .clipped()
                                } else {
                                    Image("audiQ3")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 280, height: 180)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .clipped()
                                }
                            }
                            .frame(width: 280, height: 180)
                            .onAppear {
                                if displayImage == nil, let src = vehicleImage {
                                    let monthString = plateData?.month ?? ""
                                    let paddedMonth = monthString.count == 1 ? "" + monthString : monthString
                                    if(paddedMonth == "0" && plateData?.year == "")
                                    {
                                        dateString = ""
                                    }
                                    else if (paddedMonth == "" || plateData?.year == ""){
                                        dateString = paddedMonth + (plateData?.year ?? "")
                                    }
                                    else {
                                        dateString = paddedMonth + "/" + (plateData?.year ?? "")

                                    }
                                    
                                    displayImage = src.trimmedTransparentPixels(threshold: 5)
                                }
                            }
                            
                            
                            // Date
                            Text(dateString)
                                .font(.customFont(size: 16, weight: .bold))
                                .foregroundColor(.black)
                            
                            // Car type
                            HStack (spacing: 2){
                                Text("CarType:")
                                    .font(.customFont(size: 16, weight: .regular))
                                    .foregroundColor(.black)
                                
                                Text("Hybrid Sports Car")
                                    .font(.customFont(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Continue button
                Button(action: {
                    showConfirmDetailsScreen = true
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
               // .opacity(isContinueEnabled ? 1.0 : 0.6)
               // .disabled(!isContinueEnabled)
                .padding(.horizontal, 24)
            }
        }
        .navigationDestination(isPresented: $showConfirmDetailsScreen) {
            if let plateData = plateData {
                ConfirmDetailsView(plateData: plateData, manualEntryEnabled: false)
                    .navigationBarBackButtonHidden(true)
            } else {
                Text("Nessun dato disponibile")
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    CheckDetailsView()
}
