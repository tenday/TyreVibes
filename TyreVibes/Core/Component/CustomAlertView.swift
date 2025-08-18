import SwiftUI

struct CustomAlertView: View {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let primaryButtonAction: () -> Void

    var body: some View {
        ZStack {
            // Background blur
            VisualEffectBlur(blurStyle: .dark)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text(title)
                    .font(.customFont(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text(message)
                    .font(.customFont(size: 16, weight: .regular))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: primaryButtonAction) {
                    Text(primaryButtonTitle)
                        .font(.customFont(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.customBitterSweet)
                        .cornerRadius(25)
                }
            }
            .padding(30)
            .background(Color.customFieldColor)
            .cornerRadius(30)
            .shadow(radius: 20)
            .padding(.horizontal, 40)
        }
    }
}

struct CustomAlertView_Previews: PreviewProvider {
    static var previews: some View {
        CustomAlertView(
            title: "Error",
            message: "This is a custom alert message.",
            primaryButtonTitle: "OK",
            primaryButtonAction: {}
        )
    }
}
