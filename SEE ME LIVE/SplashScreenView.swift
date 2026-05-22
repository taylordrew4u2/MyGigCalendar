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
                .frame(width: 260, height: 220)
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
    private let ink = Color(red: 0.08, green: 0.08, blue: 0.10)

    var body: some View {
        ZStack {
            spotlight(angle: isAnimating ? -19 : -34, x: -54, opacity: 0.34)
            spotlight(angle: isAnimating ? 19 : 34, x: 54, opacity: 0.34)
            spotlight(angle: isAnimating ? 0 : 8, x: 0, opacity: 0.22)

            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    ForEach(0..<7, id: \.self) { index in
                        marqueeLight(index: index)
                    }
                }
                .padding(.top, 18)

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(ink)
                        .frame(width: 184, height: 82)
                        .overlay(alignment: .top) {
                            HStack(spacing: 14) {
                                ForEach(0..<4, id: \.self) { index in
                                    Capsule()
                                        .fill(red.opacity(0.9))
                                        .frame(width: 18, height: isAnimating ? 58 : 34)
                                        .offset(y: isAnimating ? CGFloat(index.isMultiple(of: 2) ? -8 : 4) : 8)
                                        .animation(
                                            .easeInOut(duration: 0.52)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(index) * 0.08),
                                            value: isAnimating
                                        )
                                }
                            }
                            .padding(.top, 12)
                        }

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [red.opacity(0), red, gold, red, red.opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 218, height: 8)
                        .offset(y: isAnimating ? 5 : 12)
                        .animation(.spring(response: 0.45, dampingFraction: 0.58), value: isAnimating)
                }
            }
        }
        .scaleEffect(isAnimating ? 1 : 0.92)
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

    private func marqueeLight(index: Int) -> some View {
        Circle()
            .fill(index.isMultiple(of: 2) ? gold : red)
            .frame(width: 16, height: 16)
            .shadow(color: (index.isMultiple(of: 2) ? gold : red).opacity(0.75), radius: isAnimating ? 10 : 2)
            .offset(y: isAnimating ? CGFloat(index.isMultiple(of: 2) ? -9 : 7) : 7)
            .animation(
                .easeInOut(duration: 0.42)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.06),
                value: isAnimating
            )
    }
}

#Preview {
    SplashScreenView()
}
