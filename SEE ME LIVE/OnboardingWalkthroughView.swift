//
//  OnboardingWalkthroughView.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 5/9/26.
//

import SwiftUI

struct OnboardingWalkthroughView: View {
    let onComplete: () -> Void

    @State private var selectedPage = 0
    @State private var isRequestingCalendar = false
    /// Once the calendar explanation has been shown, Skip is gone for good so
    /// the message can't be dismissed without reaching the system prompt.
    @State private var hasSeenCalendarPage = false

    private let pages = OnboardingPage.pages

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        onboardingPage(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                VStack(spacing: 12) {
                    if isLastPage {
                        // The calendar page always continues straight to the
                        // system permission prompt (App Review 5.1.1(iv)).
                        Button {
                            Task { await continueToCalendarRequest() }
                        } label: {
                            primaryButtonLabel("Continue", showsProgress: isRequestingCalendar)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRequestingCalendar)
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                selectedPage += 1
                            }
                        } label: {
                            primaryButtonLabel("Continue")
                        }
                        .buttonStyle(.plain)

                        if !hasSeenCalendarPage {
                            Button {
                                onComplete()
                            } label: {
                                Text("Skip")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .onChange(of: selectedPage) {
            if isLastPage { hasSeenCalendarPage = true }
        }
    }

    private var isLastPage: Bool {
        selectedPage == pages.count - 1
    }

    private func onboardingPage(_ page: OnboardingPage) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 24)

            Image(systemName: page.symbol)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 84, height: 84)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text(page.title)
                    .font(.title.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 10)
            }

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 24)
    }

    private func primaryButtonLabel(_ title: String, showsProgress: Bool = false) -> some View {
        HStack(spacing: 8) {
            if showsProgress {
                ProgressView()
                    .tint(.white)
            }
            Text(title)
                .font(.headline)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Shows the system calendar prompt, then enters the app whatever the answer.
    /// If the user already decided, iOS returns immediately without a prompt.
    private func continueToCalendarRequest() async {
        isRequestingCalendar = true
        if !CalendarService.shared.isAuthorized {
            _ = await CalendarService.shared.requestAccess()
        }
        isRequestingCalendar = false
        onComplete()
    }
}

private struct OnboardingPage {
    let symbol: String
    let title: String
    let message: String

    static let pages = [
        OnboardingPage(
            symbol: "calendar",
            title: "Build your gig calendar",
            message: "Add upcoming shows, keep past dates organized, and see your schedule at a glance."
        ),
        OnboardingPage(
            symbol: "square.and.arrow.up",
            title: "Share clean flyers",
            message: "Turn your dates into a social post, customize the layout, and export when it is ready."
        ),
        OnboardingPage(
            symbol: "arrow.triangle.2.circlepath.icloud",
            title: "Sync with your calendar",
            message: "My Gig Calendar uses calendar access to add the gigs you save to your device calendar. You can change this anytime in Settings."
        )
    ]
}

#Preview {
    OnboardingWalkthroughView {}
}
