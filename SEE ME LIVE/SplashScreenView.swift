//
//  SplashScreenView.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/3/26.
//
//  Quick launch animation. The performer should be using the app within a
//  second of opening it; this surface is decoration, not a destination.
//

import SwiftUI

struct SplashScreenView: View {
    var onFinish: () -> Void = {}

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            SplashStageAnimation(isAnimating: isAnimating)
                .frame(width: 300, height: 330)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("My Gig Calendar is starting up")
        .onAppear {
            isAnimating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { onFinish() }
        }
    }
}

private struct SplashStageAnimation: View {
    let isAnimating: Bool

    private let red = Color(red: 0.92, green: 0.14, blue: 0.16)
    private let gold = Color(red: 1.0, green: 0.82, blue: 0.28)

    var body: some View {
        ZStack {
            spotlight(angle: isAnimating ? -16 : -30, x: -68, opacity: 0.30)
            spotlight(angle: isAnimating ? 16 : 30, x: 68, opacity: 0.30)

            Image("SplashIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 230, height: 230)
                .shadow(color: red.opacity(isAnimating ? 0.26 : 0.06), radius: isAnimating ? 28 : 10)
                .shadow(color: gold.opacity(isAnimating ? 0.20 : 0.04), radius: isAnimating ? 42 : 12)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [red.opacity(0), red, gold, red, red.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: isAnimating ? 252 : 120, height: 6)
                .offset(y: 146)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isAnimating)
        }
        .scaleEffect(isAnimating ? 1 : 0.94)
        .opacity(isAnimating ? 1 : 0)
        .animation(.easeOut(duration: 0.28), value: isAnimating)
    }

    private func spotlight(angle: Double, x: CGFloat, opacity: Double) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [gold.opacity(opacity), gold.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 58, height: 190)
            .rotationEffect(.degrees(angle))
            .offset(x: x, y: 12)
            .blur(radius: 1.5)
            .animation(.easeInOut(duration: 0.62).repeatForever(autoreverses: true), value: isAnimating)
    }

}

#Preview {
    SplashScreenView()
}
