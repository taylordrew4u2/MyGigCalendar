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
    @State private var calendarStatusText: String?

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
                    if selectedPage == pages.count - 1 {
                        calendarActions
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                selectedPage += 1
                            }
                        } label: {
                            primaryButtonLabel("Continue")
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        onComplete()
                    } label: {
                        Text(selectedPage == pages.count - 1 ? "Finish" : "Skip")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            calendarStatusText = CalendarService.shared.isAuthorized ? "Calendar access is already enabled." : nil
        }
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

            if selectedPage == pages.count - 1, let calendarStatusText {
                Text(calendarStatusText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.top, 4)
            }

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 24)
    }

    private var calendarActions: some View {
        VStack(spacing: 10) {
            Button {
                Task { await enableCalendarAccess() }
            } label: {
                HStack(spacing: 8) {
                    if isRequestingCalendar {
                        ProgressView()
                    } else {
                        Image(systemName: CalendarService.shared.isAuthorized ? "checkmark.circle.fill" : "calendar.badge.plus")
                            .font(.headline)
                    }
                    Text(CalendarService.shared.isAuthorized ? "Calendar Enabled" : "Enable Calendar")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Color("AppBackground"))
                .background(Color.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isRequestingCalendar || CalendarService.shared.isAuthorized)

            Button {
                onComplete()
            } label: {
                primaryButtonLabel("Start using My Gig Calendar")
            }
            .buttonStyle(.plain)
        }
    }

    private func primaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func enableCalendarAccess() async {
        guard !CalendarService.shared.isAuthorized else {
            calendarStatusText = "Calendar access is already enabled."
            return
        }

        isRequestingCalendar = true
        let granted = await CalendarService.shared.requestAccess()
        isRequestingCalendar = false
        calendarStatusText = granted
            ? "Calendar access is enabled. New gigs can be added to your calendar when you save them."
            : "Calendar access was not enabled. You can still use the app and add access later in Settings."
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
            message: "Enable calendar access so saved gigs can appear in your device calendar and stay easier to track."
        )
    ]
}

#Preview {
    OnboardingWalkthroughView {}
}
