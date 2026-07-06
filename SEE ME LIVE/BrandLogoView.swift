//
//  BrandLogoView.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/5/26.
//

import SwiftUI

// MARK: - Brand Logo View
/// Clean, flat, modern app icon — calendar with stage curtains.
/// Red/White/Black brand. Scales to any size.

struct BrandLogoView: View {
    var size: CGFloat = 120

    private var s: CGFloat { size / 120 }
    private let red    = Color(red: 0.92, green: 0.14, blue: 0.16)
    private let white  = Color.white
    private let canvas = Color(red: 0.08, green: 0.08, blue: 0.10)
    private let darkRed = Color(red: 0.60, green: 0.06, blue: 0.08)

    var body: some View {
        ZStack {
            // iOS-style squircle background
            RoundedRectangle(cornerRadius: 26 * s, style: .continuous)
                .fill(canvas)

            calendarBody
            curtains
        }
        .frame(width: size, height: size)
        .compositingGroup()
    }

    // MARK: - Calendar Body

    private var calendarBody: some View {
        let pad: CGFloat     = 14 * s
        let w                = size - pad * 2
        let h                = w * 0.90
        let headerH: CGFloat = 20 * s
        let r: CGFloat       = 10 * s

        return ZStack(alignment: .top) {
            // White page
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(white)
                .frame(width: w, height: h)

            // Red header band
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [red, darkRed],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: w, height: headerH + r)
                    .padding(.bottom, -r)
                Spacer()
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))

            // Two ring pegs on header
            HStack(spacing: 26 * s) {
                RingPeg(s: s, red: red, canvas: canvas)
                RingPeg(s: s, red: red, canvas: canvas)
            }
            .offset(y: -(7 * s))

            // Stage floor line near bottom
            VStack {
                Spacer()
                Rectangle()
                    .fill(red.opacity(0.18))
                    .frame(width: w - 20 * s, height: 1.5 * s)
                    .padding(.bottom, 14 * s)
            }
            .frame(height: h)
        }
        .offset(y: 5 * s)
    }

    // MARK: - Stage Curtains (drawn INSIDE the calendar white area)

    private var curtains: some View {
        let pad: CGFloat     = 14 * s
        let w                = size - pad * 2
        let h                = w * 0.90
        let headerH: CGFloat = 20 * s
        let r: CGFloat       = 10 * s

        // Curtain area starts below the red header
        let curtainTop  = headerH + 6 * s
        let curtainH    = h - headerH - 22 * s
        let curtainW    = (w / 2) - 4 * s

        return ZStack {
            // Left curtain
            CurtainShape(side: .left, s: s)
                .fill(
                    LinearGradient(
                        colors: [red, darkRed, red.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: curtainW, height: curtainH)
                .offset(
                    x: -(w / 2 - curtainW / 2),
                    y: curtainTop - h / 2 + curtainH / 2 + 5 * s
                )

            // Right curtain
            CurtainShape(side: .right, s: s)
                .fill(
                    LinearGradient(
                        colors: [red.opacity(0.85), darkRed, red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: curtainW, height: curtainH)
                .offset(
                    x: (w / 2 - curtainW / 2),
                    y: curtainTop - h / 2 + curtainH / 2 + 5 * s
                )

            // Valance (top drape bar between curtains)
            Valance(s: s)
                .fill(darkRed)
                .frame(width: w - 12 * s, height: 10 * s)
                .offset(y: curtainTop - h / 2 + 5 * s + 5 * s)

            // Stage glow (spotlight on floor)
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 18 * s
                    )
                )
                .frame(width: 36 * s, height: 10 * s)
                .offset(y: curtainTop - h / 2 + curtainH + 7 * s)
        }
        // Clip entire curtain assembly to white area of calendar
        .clipShape(
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .offset(y: 5 * s)
        )
        .offset(y: 5 * s)
    }
}

// MARK: - Curtain Shape

private enum CurtainSide { case left, right }

private struct CurtainShape: Shape {
    let side: CurtainSide
    let s: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let foldDepth = w * 0.28   // how far folds sweep inward

        if side == .left {
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: w, y: 0))
            // Scalloped inner edge (folds)
            let folds = 3
            let foldH = h / CGFloat(folds)
            for i in 0..<folds {
                let yTop    = CGFloat(i) * foldH
                let yMid    = yTop + foldH * 0.5
                let yBottom = yTop + foldH
                let inward  = (i % 2 == 0) ? w - foldDepth : w
                p.addQuadCurve(
                    to: CGPoint(x: inward, y: yMid),
                    control: CGPoint(x: w, y: yTop + foldH * 0.25)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w, y: yBottom),
                    control: CGPoint(x: inward, y: yMid + foldH * 0.35)
                )
            }
            p.addLine(to: CGPoint(x: 0, y: h))
            p.closeSubpath()
        } else {
            p.move(to: CGPoint(x: w, y: 0))
            p.addLine(to: CGPoint(x: 0, y: 0))
            let folds = 3
            let foldH = h / CGFloat(folds)
            for i in 0..<folds {
                let yTop    = CGFloat(i) * foldH
                let yMid    = yTop + foldH * 0.5
                let yBottom = yTop + foldH
                let inward  = (i % 2 == 0) ? foldDepth : 0
                p.addQuadCurve(
                    to: CGPoint(x: inward, y: yMid),
                    control: CGPoint(x: 0, y: yTop + foldH * 0.25)
                )
                p.addQuadCurve(
                    to: CGPoint(x: 0, y: yBottom),
                    control: CGPoint(x: inward, y: yMid + foldH * 0.35)
                )
            }
            p.addLine(to: CGPoint(x: w, y: h))
            p.closeSubpath()
        }
        return p
    }
}

// MARK: - Valance (swag drape at top)

private struct Valance: Shape {
    let s: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let scallops = 4
        let sw = w / CGFloat(scallops)

        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w, y: h * 0.4))

        for i in stride(from: scallops, to: 0, by: -1) {
            let x0 = CGFloat(i - 1) * sw
            let cx = x0 + sw / 2
            p.addQuadCurve(
                to: CGPoint(x: x0, y: h * 0.4),
                control: CGPoint(x: cx, y: h * 1.6)
            )
        }
        p.addLine(to: CGPoint(x: 0, y: 0))
        p.closeSubpath()
        return p
    }
}

// MARK: - Ring Peg

private struct RingPeg: View {
    let s: CGFloat
    let red: Color
    let canvas: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(canvas)
                .frame(width: 12 * s, height: 12 * s)
            Circle()
                .stroke(red.opacity(0.7), lineWidth: 2 * s)
                .frame(width: 8 * s, height: 8 * s)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        BrandLogoView(size: 256)
        HStack(spacing: 24) {
            BrandLogoView(size: 120)
            BrandLogoView(size: 80)
            BrandLogoView(size: 60)
        }
    }
    .padding(40)
    .background(Color(.systemGroupedBackground))
}
