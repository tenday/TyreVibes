import SwiftUI

struct CustomAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let showProgress: Bool
    let primaryButtonTitle: String
    let primaryButtonAction: () -> Void

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
               CustomAlertView(
                    title: title,
                    showProgress: showProgress
               )
                    //     message: message,
               //     primaryButtonTitle: primaryButtonTitle,
              //      primaryButtonAction: {
              //          primaryButtonAction()
              //          isPresented = false
              //      }
              //  )
            }
        }
    }
}

extension View {
    func customAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        showprogress: Bool,
        primaryButtonTitle: String,
        primaryButtonAction: @escaping () -> Void
    ) -> some View {
        self.modifier(
            CustomAlertModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                showProgress: showprogress,
                primaryButtonTitle: primaryButtonTitle,
                primaryButtonAction: primaryButtonAction
            )
        )
    }
}
