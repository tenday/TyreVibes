import SwiftUI

struct OnboardingView: View {
    // Stato per tracciare la pagina corrente dell'onboarding
    @State private var currentPage = 0
    
    // Array di contenuti dell'onboarding
    let onboardingData = [
        OnboardingPage(
            title: "Lorem ipsum sem arcu placerat",
            description: "Ciao, sono Matteo. Vivo a Milano. Vivo a Milano. Vivo a Milano.",
            image: "imageOnBoardingScreen1"
        ),
        OnboardingPage(
            title: "Etiam vitae consectetur",
            description: "Lavoro come sviluppatore di app. Mi piace creare interfacce intuitive.",
            image: "onboarding2"
        ),
        OnboardingPage(
            title: "Nullam fermentum",
            description: "Amo viaggiare ed esplorare nuove città. La fotografia è la mia passione.",
            image: "onboarding3"
        )
    ]
    
    // Stato per gestire l'uscita dall'onboarding
    @State private var isOnboardingComplete = false
    
    var body: some View {
        ZStack {
            // Sfondo nero
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Se l'onboarding è completo, mostra la vista principale
           if isOnboardingComplete {
                WelcomeScreen()
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                    .animation(.easeInOut(duration: 0.6), value: isOnboardingComplete)
            } else {
                VStack {
                    Spacer()
                    
                    // Area semicircolare nella parte superiore (può essere un'immagine o una formwa)
                    Circle()
                        .fill(Color.customGray)
                        .frame(width: UIScreen.main.bounds.width * 1.5, height: UIScreen.main.bounds.width * 1.5)
                        .position(x: UIScreen.main.bounds.width / 2, y: -UIScreen.main.bounds.width * -0.3)
                        .edgesIgnoringSafeArea(.top)
                    
                    // Immagine centrata sopra il cerchio
                    Image(onboardingData[currentPage].image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .padding(.top, -UIScreen.main.bounds.width * 0.7)
                    
                    Spacer()
                    
                    Text(onboardingData[currentPage].title)
                        .font(.customFont(size: 40, weight: .semibold))
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#F78F18"), Color(hex: "#FF4C81")]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .mask(
                            Text(onboardingData[currentPage].title)
                                .font(.system(size: 40, weight: .bold))
                        )
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    
                    // Descrizione in testo bianco
                    Text(onboardingData[currentPage].description)
                        .font(.customFont(size: 16, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    
                    Spacer()
                    
                    // Indicatori di pagina
                    HStack(spacing: 4) {
                        ForEach(0..<onboardingData.count, id: \.self) { index in
                            Capsule()
                                .fill(currentPage == index ? Color.white : Color(hex: "808080"))
                                .cornerRadius(10)
                                .frame(width: currentPage == index ? 52 : 12, height: currentPage == index ? 6 : 12,)
                                .animation(.spring(), value: currentPage)
                        }
                    }
                    .padding(.bottom, 50)
                    
                    // Pulsanti Skip e Continue
                    HStack {
                        // Pulsante Skip
                        Button(action: {
                            withAnimation {
                                isOnboardingComplete = true
                            }
                        }) {
                            Text("Skip")
                                .font(.customFont(size: 18, weight: .regular))
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Spacer()
                        
                        // Pulsante Continue
                        Button(action: {
                            withAnimation {
                                if currentPage < onboardingData.count - 1 {
                                    currentPage += 1
                                } else {
                                    isOnboardingComplete = true
                                }
                            }
                        })
                        {
                            Text("Continue")
                                .font(.customFont(size: 16, weight: .semibold))
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 134, height: 50)
                                .background(Color.customBitterSweet)
                                .cornerRadius(25)
                        }
                        
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 2)
                }
            }
        }
    }
}

// Struttura per i dati di ogni pagina dell'onboarding
struct OnboardingPage {
    let title: String
    let description: String
    let image: String
}

// Definizione di ContentView come placeholder
struct ContentView: View {
    var body: some View {
        Text("TyreVibes")
    }
}

// Anteprima della vista
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
