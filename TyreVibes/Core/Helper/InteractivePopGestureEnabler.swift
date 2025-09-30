import SwiftUI

struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    typealias UIViewControllerType = PopGestureViewController
    
    func makeUIViewController(context: Context) -> PopGestureViewController {
        PopGestureViewController()
    }

    func updateUIViewController(_ uiViewController: PopGestureViewController, context: Context) {
        // Manteniamo vuoto se non ci sono aggiornamenti necessari
    }

    // MARK: - Embedded Types
    
    final class PopGestureViewController: UIViewController {
        
        override func loadView() {
            view = UIView()
            view.backgroundColor = .clear
            view.isHidden = true // Nasconde completamente la view
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            configureInteractivePopGesture()
        }
        
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            resetInteractivePopGesture()
        }
        
        private func configureInteractivePopGesture() {
            guard let navigationController = navigationController,
                  let popGesture = navigationController.interactivePopGestureRecognizer else {
                return
            }
            
            popGesture.delegate = self
            popGesture.isEnabled = true
        }
        
        private func resetInteractivePopGesture() {
            navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension InteractivePopGestureEnabler.PopGestureViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Controlla che ci siano view controllers da cui tornare indietro
        guard let navigationController = navigationController else { return false }
        return navigationController.viewControllers.count > 1
    }
    
    // Opzionale: permette il riconoscimento simultaneo di più gesture
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                          shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}
