import GoogleMobileAds
import SwiftUI

class InterstitialAdManager: NSObject, ObservableObject, GADFullScreenContentDelegate {
    // Ad Unit ID di test di Google. Sostituiscilo con il tuo ID di produzione.
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910"

    @Published var interstitialAd: GADInterstitialAd?
    private var adDismissalCompletion: (() -> Void)?

    override init() {
        super.init()
        loadAd()
    }

    func loadAd() {
        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: adUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                self?.interstitialAd = nil
                return
            }
            print("Interstitial ad loaded.")
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
        }
    }

    func showAd(from viewController: UIViewController, onDismiss: @escaping () -> Void) {
        guard let ad = interstitialAd else {
            print("Ad wasn't ready. Performing action immediately.")
            onDismiss() // Se l'annuncio non è pronto, esegui comunque l'azione.
            loadAd() // Prova a caricare il prossimo.
            return
        }

        self.adDismissalCompletion = onDismiss
        ad.present(fromRootViewController: viewController)
    }

    // MARK: - GADFullScreenContentDelegate

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Ad did fail to present full screen content.")
        adDismissalCompletion?() // Esegui l'azione anche se la presentazione fallisce.
        adDismissalCompletion = nil
        interstitialAd = nil
        loadAd()
    }

    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Ad will present full screen content.")
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Ad did dismiss full screen content.")
        adDismissalCompletion?() // Esegui l'azione dopo che l'utente ha chiuso l'annuncio.
        adDismissalCompletion = nil
        interstitialAd = nil
        loadAd()
    }
}