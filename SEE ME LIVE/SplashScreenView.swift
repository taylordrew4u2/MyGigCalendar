//
//  SplashScreenView.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/3/26.
//
//  Quiet launch screen. The performer should be using the app within a
//  second of opening it; this surface is decoration, not a destination.
//

import SwiftUI

struct SplashScreenView: View {
    var onFinish: () -> Void = {}

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 14) {
                BrandLogoView(size: 96)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1.0 : 0.96)

                Text("SEE ME LIVE")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(.primary)
                    .opacity(appeared ? 0.8 : 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("SEE ME LIVE is starting up")
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { onFinish() }
        }
    }
}

#Preview {
    SplashScreenView()
}
