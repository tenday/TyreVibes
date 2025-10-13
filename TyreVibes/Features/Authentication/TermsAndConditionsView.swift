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
            Text("Last Updated: October 2025")
                .font(.customFont(size: 14, weight: .regular))
                .foregroundColor(.gray)

            ForEach(TermsAndConditions.sections, id: \.title) { section in
                sectionTitle(section.title)
                sectionText(section.content)
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
                Text("Last Updated: October 2025")
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
