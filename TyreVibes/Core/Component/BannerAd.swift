import SwiftUI
import GoogleMobileAds
import UIKit

private struct BannerAdViewController: UIViewControllerRepresentable {

    let adUnitID: String

    init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let bannerViewController = UIViewController()
        let bannerView = GADBannerView(adSize: GADAdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = bannerViewController
        bannerView.load(GADRequest())
        bannerViewController.view.addSubview(bannerView)
        return bannerViewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct BannerAd: View {
    let adUnitID: String

    var body: some View {
        BannerAdViewController(adUnitID: adUnitID)
            .frame(height: GADAdSizeBanner.size.height)
    }
}