//
//  LicensePlateComponent.swift
//  TyreVibes
//
//  Created by Matteo La Manna on 13/08/25.
//

import Foundation
import SwiftUI


struct LicensePlateComponent: View {
    var text: String
    var width: CGFloat = 200
    var height: CGFloat = 100
    var countryCode: String = "I"

    var body: some View {
        ZStack {
            // Plate base
            RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                        .stroke(Color.black, lineWidth: 3)
                )
                // subtle inner bevel
                .overlay(
                    RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                        .blur(radius: 1)
                        .offset(x: 0, y: 1)
                        .mask(
                            RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                        )
                )

            // Blue EU/country band on the left
            HStack(spacing: 0) {
                ZStack {
                    Rectangle().fill(Color(red: 0.0, green: 0.35, blue: 0.8))
                    VStack(spacing: height * 0.06) {
                        // (Optional) stars could be added later if you have an asset
                        Text(countryCode)
                            .font(.customFont(size: height * 0.38, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, height * 0.08)
                    }
                }
                .frame(width: height * 0.28)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: height * 0.18, style: .continuous))

            // Plate number
            Text(text)
                .font(.customFont(size: height * 0.5, weight: .semibold))
                .foregroundColor(.gray).opacity(0.2)
                .padding(.horizontal, height * 0.32) // keep clear of blue band and border

        }
        .frame(width: width, height: height)
        // Rivets
        .overlay(
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                Group {
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
                        .frame(width: h * 0.08, height: h * 0.08)
                        .position(x: w * 0.14, y: h * 0.22)
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
                        .frame(width: h * 0.08, height: h * 0.08)
                        .position(x: w * 0.86, y: h * 0.22)
                }
            }
        )
        .accessibilityLabel(Text("License plate \(text)"))
    }
}
