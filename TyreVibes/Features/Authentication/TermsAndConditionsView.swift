import SwiftUI

struct TermsAndConditionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasReadTerms: Bool
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var hasScrolledToBottom = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.customBackgroundColor.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Scrollable Content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            termsContent

                            // Anchor per tracking scroll
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(20)
                        .background(GeometryReader { geo in
                            Color.clear.preference(
                                key: ViewHeightKey.self,
                                value: geo.size.height
                            )
                        })
                    }
                    .background(GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollViewHeightKey.self,
                            value: geo.size.height
                        )
                    })
                    .onPreferenceChange(ViewHeightKey.self) { height in
                        contentHeight = height
                        checkIfScrolledToBottom()
                    }
                    .onPreferenceChange(ScrollViewHeightKey.self) { height in
                        scrollViewHeight = height
                        checkIfScrolledToBottom()
                    }
                }
                .coordinateSpace(name: "scroll")

                // Bottom Button
                VStack(spacing: 12) {
                    if !hasScrolledToBottom {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Color.customBitterSweet)
                            Text("Scroll to the bottom to accept")
                                .font(.customFont(size: 14, weight: .regular))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 8)
                    }

                    Button(action: {
                        if hasScrolledToBottom {
                            hasReadTerms = true
                            dismiss()
                        }
                    }) {
                        Text("I Accept")
                            .font(.customFont(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                    }
                    .background(hasScrolledToBottom ? Color.customBitterSweet : Color.gray)
                    .cornerRadius(100)
                    .disabled(!hasScrolledToBottom)
                    .opacity(hasScrolledToBottom ? 1.0 : 0.6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .background(Color.customBackgroundColor)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                }
            }

            ToolbarItem(placement: .principal) {
                Text("Terms & Conditions")
                    .font(.customFont(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.customBackgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            // Delay to ensure content is laid out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                checkIfScrolledToBottom()
            }
        }
        }
    }

    private func checkIfScrolledToBottom() {
        // Se il contenuto è più piccolo dello scroll view, considera già letto
        if contentHeight <= scrollViewHeight {
            hasScrolledToBottom = true
        }
    }

    private var termsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                Text("Last Updated: January 2025")
                    .font(.customFont(size: 14, weight: .regular))
                    .foregroundColor(.gray)

                sectionTitle("1. Acceptance of Terms")
                sectionText("By accessing and using TyreVibes, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.")

                sectionTitle("2. Description of Service")
                sectionText("TyreVibes provides tire monitoring and maintenance tracking services for vehicle owners. The service includes tire condition analysis, maintenance reminders, and safety recommendations.")

                sectionTitle("3. User Account")
                sectionText("To use certain features of TyreVibes, you must register for an account. You agree to provide accurate, current, and complete information during the registration process and to update such information to keep it accurate, current, and complete.")

                sectionTitle("4. Privacy Policy")
                sectionText("Your use of TyreVibes is also governed by our Privacy Policy. Please review our Privacy Policy, which also governs the Service and informs users of our data collection practices.")

                sectionTitle("5. User Responsibilities")
                sectionText("You are responsible for:\n• Maintaining the confidentiality of your account credentials\n• All activities that occur under your account\n• Ensuring all information provided is accurate\n• Using the service in compliance with applicable laws")
            }

            Group {
                sectionTitle("6. Tire Safety Disclaimer")
                sectionText("While TyreVibes provides tire monitoring and analysis, it does not replace professional tire inspection and maintenance. Users should regularly have their tires inspected by qualified professionals. TyreVibes is not liable for any damages or injuries resulting from tire-related issues.")

                sectionTitle("7. Subscription and Payments")
                sectionText("Certain features of TyreVibes may require a subscription. Subscription fees are billed in advance on a recurring basis. You can cancel your subscription at any time through your account settings.")

                sectionTitle("8. Intellectual Property")
                sectionText("The Service and its original content, features, and functionality are and will remain the exclusive property of TyreVibes and its licensors. The Service is protected by copyright, trademark, and other laws.")

                sectionTitle("9. Apple App Store Requirements")
                sectionText("These Terms are between you and TyreVibes only, and not with Apple Inc. (\"Apple\"). TyreVibes, not Apple, is solely responsible for the App and its content.\n\nApple and Apple's subsidiaries are third party beneficiaries of these Terms, and upon your acceptance of these Terms, Apple will have the right to enforce these Terms against you as a third party beneficiary.\n\nYou represent and warrant that (i) you are not located in a country that is subject to a U.S. Government embargo, or that has been designated by the U.S. Government as a \"terrorist supporting\" country; and (ii) you are not listed on any U.S. Government list of prohibited or restricted parties.")

                sectionTitle("10. Apple's Role and Responsibilities")
                sectionText("Apple has no obligation whatsoever to furnish any maintenance and support services with respect to the App.\n\nIn the event of any failure of the App to conform to any applicable warranty, you may notify Apple, and Apple will refund the purchase price (if any) for the App to you. To the maximum extent permitted by applicable law, Apple will have no other warranty obligation whatsoever with respect to the App.\n\nApple is not responsible for addressing any claims you have or any claims of any third party relating to the App or your possession and use of the App, including: (i) product liability claims; (ii) any claim that the App fails to conform to any applicable legal or regulatory requirement; and (iii) claims arising under consumer protection or similar legislation.")

                sectionTitle("11. Intellectual Property Claims")
                sectionText("In the event of any third party claim that the App or your possession and use of the App infringes that third party's intellectual property rights, TyreVibes, not Apple, will be solely responsible for the investigation, defense, settlement and discharge of any such intellectual property infringement claim.")

                sectionTitle("12. Limitation of Liability")
                sectionText("In no event shall TyreVibes, nor its directors, employees, partners, agents, suppliers, or affiliates, be liable for any indirect, incidental, special, consequential or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses.\n\nApple and Apple's subsidiaries shall not be liable for any damages whatsoever arising out of or in connection with your use of the App.")

                sectionTitle("13. Legal Compliance")
                sectionText("You must comply with applicable third party terms of agreement when using the App (e.g., you must not be in violation of your wireless data service agreement when using the App).\n\nYou agree to comply with all applicable local, state, national, and international laws and regulations.")

                sectionTitle("14. Changes to Terms")
                sectionText("We reserve the right to modify or replace these Terms at any time. If a revision is material, we will provide at least 30 days' notice prior to any new terms taking effect.")

                sectionTitle("15. Contact Information")
                sectionText("For questions about these Terms, contact TyreVibes at:\nsupport@tyrevibes.com\n\nFor App-related support, contact TyreVibes, not Apple.\n\nApple and its subsidiaries are third party beneficiaries of these Terms and may enforce them directly against you.")
            }

            Spacer(minLength: 40)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.customFont(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .padding(.top, 8)
    }

    private func sectionText(_ text: String) -> some View {
        Text(text)
            .font(.customFont(size: 14, weight: .regular))
            .foregroundColor(.gray)
            .lineSpacing(4)
    }
}

// Preference Keys per misurare le altezze
struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// ScrollView con tracking dello scroll
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasReadPrivacy: Bool
    @State private var contentHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var hasScrolledToBottom = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.customBackgroundColor.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Scrollable Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        privacyContent

                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(20)
                    .background(GeometryReader { geo in
                        Color.clear.preference(
                            key: ViewHeightKey.self,
                            value: geo.size.height
                        )
                    })
                }
                .background(GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollViewHeightKey.self,
                        value: geo.size.height
                    )
                })
                .onPreferenceChange(ViewHeightKey.self) { height in
                    contentHeight = height
                    checkIfScrolledToBottom()
                }
                .onPreferenceChange(ScrollViewHeightKey.self) { height in
                    scrollViewHeight = height
                    checkIfScrolledToBottom()
                }

                // Bottom Button
                VStack(spacing: 12) {
                    if !hasScrolledToBottom {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Color.customBitterSweet)
                            Text("Scroll to the bottom to accept")
                                .font(.customFont(size: 14, weight: .regular))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 8)
                    }

                    Button(action: {
                        if hasScrolledToBottom {
                            hasReadPrivacy = true
                            dismiss()
                        }
                    }) {
                        Text("I Accept")
                            .font(.customFont(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                    }
                    .background(hasScrolledToBottom ? Color.customBitterSweet : Color.gray)
                    .cornerRadius(100)
                    .disabled(!hasScrolledToBottom)
                    .opacity(hasScrolledToBottom ? 1.0 : 0.6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .background(Color.customBackgroundColor)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                }
            }

            ToolbarItem(placement: .principal) {
                Text("Privacy Policy")
                    .font(.customFont(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.customBackgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                checkIfScrolledToBottom()
            }
        }
        }
    }

    private func checkIfScrolledToBottom() {
        if contentHeight <= scrollViewHeight {
            hasScrolledToBottom = true
        }
    }

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                Text("Last Updated: January 2025")
                    .font(.customFont(size: 14, weight: .regular))
                    .foregroundColor(.gray)

                sectionTitle("1. Information We Collect")
                sectionText("We collect information that you provide directly to us, including:\n• Account information (name, email, phone number)\n• Vehicle information\n• Tire data and measurements\n• Usage data and preferences")

                sectionTitle("2. How We Use Your Information")
                sectionText("We use the information we collect to:\n• Provide and maintain our services\n• Send you notifications about tire maintenance\n• Improve our services\n• Communicate with you about updates and offers")

                sectionTitle("3. Data Storage and Security")
                sectionText("We implement appropriate technical and organizational measures to protect your personal data. Your data is stored securely using industry-standard encryption methods.")

                sectionTitle("4. Sharing Your Information")
                sectionText("We do not sell your personal information. We may share your information only:\n• With your consent\n• To comply with legal obligations\n• With service providers who assist us")
            }

            Group {
                sectionTitle("5. Your Rights")
                sectionText("You have the right to:\n• Access your personal data\n• Request correction of your data\n• Request deletion of your data\n• Object to processing of your data\n• Data portability")

                sectionTitle("6. Cookies and Tracking")
                sectionText("We use cookies and similar tracking technologies to track activity on our service and hold certain information to improve and analyze our service.")

                sectionTitle("7. Third-Party Services")
                sectionText("Our service may contain links to third-party websites or services. We are not responsible for the privacy practices of these third parties.")

                sectionTitle("8. Children's Privacy")
                sectionText("Our service is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13.")

                sectionTitle("9. Changes to Privacy Policy")
                sectionText("We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.")

                sectionTitle("10. Contact Us")
                sectionText("If you have any questions about this Privacy Policy, please contact us at:\nprivacy@tyrevibes.com")
            }

            Spacer(minLength: 40)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.customFont(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .padding(.top, 8)
    }

    private func sectionText(_ text: String) -> some View {
        Text(text)
            .font(.customFont(size: 14, weight: .regular))
            .foregroundColor(.gray)
            .lineSpacing(4)
    }
}

struct TermsAndConditionsView_Previews: PreviewProvider {
    static var previews: some View {
        TermsAndConditionsView(hasReadTerms: .constant(false))
            .preferredColorScheme(.dark)
    }
}
