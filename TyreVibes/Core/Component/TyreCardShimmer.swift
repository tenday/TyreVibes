import SwiftUI

struct TyreCardShimmer: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.customFieldColor)
                .frame(width: 188, height: 231)

            VStack(spacing: 0) {
                // Image area placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 172, height: 122)
                        .cornerRadius(12)
                        .shimmer()
                }

                // Brand placeholder (16pt height matching Text)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 120, height: 16)
                    .shimmer()
                    .padding(.top, 6)

                Spacer().frame(height: 6)

                // Season placeholder (16pt height matching Text)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 16)
                    .shimmer()

                Spacer().frame(height: 11)

                // Radius placeholder (16pt height matching Text)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 50, height: 16)
                    .shimmer()
                    .padding(.bottom, 10)
            }
        }
    }
}
