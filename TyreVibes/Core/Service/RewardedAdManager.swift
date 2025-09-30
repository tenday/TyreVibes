import GoogleMobileAds
import SwiftUI

class RewardedAdManager: NSObject, ObservableObject, GADFullScreenContentDelegate {
    // Ad Unit ID di test di Google. Sostituiscilo con il tuo ID di produzione.
    private let adUnitID = "ca-app-pub-3940256099942544/1712485313"

    @Published var rewardedAd: GADRewardedAd?
    @Published var adDidFinish: Bool = false

    override init() {
        super.init()
        loadAd()
    }

    func loadAd() {
        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: adUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load rewarded ad with error: \(error.localizedDescription)")
                self?.rewardedAd = nil
                return
            }
            print("Rewarded ad loaded.")
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
        }
    }

    func showAd(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let ad = rewardedAd else {
            print("Ad wasn't ready.")
            completion(false)
            // L'annuncio non è pronto, ne carico un altro per la prossima volta.
            loadAd()
            return
        }

        ad.present(fromRootViewController: viewController) {
            let reward = ad.adReward
            print("Reward received with currency: \(reward.amount), amount \(reward.amount.doubleValue)")
            // L'utente ha guadagnato la ricompensa.
            completion(true)
        }
    }

    // MARK: - GADFullScreenContentDelegate

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Ad did fail to present full screen content.")
        rewardedAd = nil
        loadAd() // Carica il prossimo annuncio
    }

    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Ad will present full screen content.")
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Ad did dismiss full screen content.")
        adDidFinish = true
        rewardedAd = nil
        loadAd() // Carica il prossimo annuncio
    }
}