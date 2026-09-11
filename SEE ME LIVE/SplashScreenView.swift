import SwiftUI

/// Calendar outline, date grid, then a booked day — finished in 1.15 seconds.
struct SplashScreenView: View {
    var onFinish: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    private let brandRed = Color(red: 201 / 255.0, green: 63 / 255.0, blue: 54 / 255.0)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 22) {
                AnimatedCalendarMark(phase: reduceMotion ? 3 : phase, reduceMotion: reduceMotion)
                    .frame(width: 144, height: 144)
                    .accessibilityHidden(true)

                Text("My Gig Calendar")
                    .font(.system(.title, design: .default, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(brandRed)
                    .multilineTextAlignment(.center)
                    .opacity(phase >= 2 || reduceMotion ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: phase)
            }
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("My Gig Calendar is starting up")
        .task(id: reduceMotion) {
            do {
                if reduceMotion {
                    phase = 3
                    try await Task.sleep(for: .milliseconds(350))
                } else {
                    phase = 1
                    try await Task.sleep(for: .milliseconds(250))
                    phase = 2
                    try await Task.sleep(for: .milliseconds(350))
                    phase = 3
                    try await Task.sleep(for: .milliseconds(550))
                }
            } catch {
                return // Disappearing views cancel the sequence and callback.
            }
            guard !Task.isCancelled else { return }
            onFinish()
        }
    }
}

/// Coordinates match the approved 120-point calendar SVG exactly.
private struct AnimatedCalendarMark: View {
    let phase: Int
    let reduceMotion: Bool
    private let red = Color(red: 201 / 255.0, green: 63 / 255.0, blue: 54 / 255.0)

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 13)
                .trim(from: 0, to: phase >= 1 ? 1 : 0)
                .stroke(red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 84, height: 90)
                .offset(x: 18, y: 18)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: phase)

            CalendarHeader()
                .fill(red)
                .opacity(phase >= 1 ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: phase)

            // Fixed positions form the nine permanent cells, not a mutable collection.
            ForEach(0..<9) { day in
                Rectangle()
                    .fill(red)
                    .frame(width: 10, height: 10)
                    .scaleEffect(phase >= 2 ? 1 : 0.5)
                    .opacity(day != 4 && phase >= 2 ? 1 : 0)
                    .offset(x: CGFloat(28 + (day % 3) * 27), y: CGFloat(51 + (day / 3) * 19))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.18).delay(Double(day) * 0.025), value: phase)
            }

            RoundedRectangle(cornerRadius: 6)
                .fill(red)
                .frame(width: 20, height: 20)
                .overlay { Circle().fill(.white).frame(width: 6, height: 6) }
                .scaleEffect(phase >= 3 ? 1 : 0.25)
                .opacity(phase >= 3 ? 1 : 0)
                .offset(x: 50, y: 65)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: phase)
        }
        .frame(width: 120, height: 120)
        .scaleEffect(1.2)
        .frame(width: 144, height: 144)
    }
}

private struct CalendarHeader: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 31, y: 18))
            p.addLine(to: CGPoint(x: 89, y: 18))
            p.addQuadCurve(to: CGPoint(x: 102, y: 31), control: CGPoint(x: 102, y: 18))
            p.addLine(to: CGPoint(x: 102, y: 40))
            p.addLine(to: CGPoint(x: 18, y: 40))
            p.addLine(to: CGPoint(x: 18, y: 31))
            p.addQuadCurve(to: CGPoint(x: 31, y: 18), control: CGPoint(x: 18, y: 18))
            p.closeSubpath()
        }
    }
}

#Preview("Animated launch") {
    SplashScreenView()
}

#Preview("Reduce Motion") {
    AnimatedCalendarMark(phase: 3, reduceMotion: true)
        .padding(40)
        .background(.white)
}
