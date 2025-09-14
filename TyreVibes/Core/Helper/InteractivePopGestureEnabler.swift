
import SwiftUI

// UIViewControllerRepresentable che riabilita il gesto di interactive pop quando si nasconde il back button nativo
struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        DispatchQueue.main.async {
            if let nav = vc.navigationController {
                nav.interactivePopGestureRecognizer?.delegate = context.coordinator
                nav.interactivePopGestureRecognizer?.isEnabled = true
            }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}
