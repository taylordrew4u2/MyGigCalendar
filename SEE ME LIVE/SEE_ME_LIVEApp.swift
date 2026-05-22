//
//  SEE_ME_LIVEApp.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/3/26.
//

import SwiftUI
import CoreData
import CloudKit

@main
struct SEE_ME_LIVEApp: App {
    let persistenceController = PersistenceController.shared

    /// Ensure the user ID is generated on first launch.
    private let _userID = UserIdentityService.shared.userID

    @State private var showSplash = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashScreenView {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                } else {
                    if hasCompletedOnboarding {
                        HomeScreenView()
                            .transition(.opacity)
                    } else {
                        OnboardingWalkthroughView {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                hasCompletedOnboarding = true
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
            .environment(\.managedObjectContext,
                          persistenceController.container.viewContext)
            .tint(Color.accentColor)
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.willEnterForegroundNotification)) { _ in
                Task.detached {
                    let bgContext = persistenceController.container.newBackgroundContext()
                    await PublicCloudSyncService.shared.startSyncIfAvailable(using: bgContext)
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: .CKAccountChanged)) { _ in
                Task.detached {
                    let bgContext = persistenceController.container.newBackgroundContext()
                    await PublicCloudSyncService.shared.startSyncIfAvailable(using: bgContext)
                }
            }
        }
    }
}
