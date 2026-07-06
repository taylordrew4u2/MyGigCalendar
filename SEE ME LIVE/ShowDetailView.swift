//
//  ShowDetailView.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/3/26.
//

import SwiftUI
import CoreData

// MARK: - Show Detail View

struct ShowDetailView: View {
    @ObservedObject var show: Show
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared
    @AppStorage("showDateTextSize") private var showDateTextSize: Double = 12

    let onEdit: () -> Void

    @State private var showDeleteConfirmation = false
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text(show.titleOrEmpty)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .tracking(-0.3)
                    }
                    .padding(.top, 24)

                    // MARK: Info Cards Grid
                    infoCardsGrid

                    // MARK: Action Buttons
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onEdit()
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(.primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Color.secondary.opacity(0.22), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(DetailCardPress())

                            ShareLink(item: shareText) {
                                shareButtonLabel
                            }
                            .buttonStyle(DetailCardPress())
                        }

                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Show", systemImage: "trash")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
        }
        .scrollIndicators(.hidden)
        .background(Color("AppBackground").ignoresSafeArea())
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this show?",
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteShow() }
        } message: {
            Text("This will remove the show from your calendar and public listing.")
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
        .task {
            await purchaseManager.checkCurrentEntitlements()
        }
    }

    private var shareButtonLabel: some View {
        Label("Share", systemImage: "square.and.arrow.up")
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.22), lineWidth: 1)
            )
    }

    // MARK: - Info Cards Grid

    private var infoCardsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            if !show.venueOrEmpty.isEmpty {
                InfoCard(icon: "mappin.and.ellipse", label: "Venue", value: show.venueOrEmpty)
            }
            InfoCard(icon: "calendar", label: "Date & Time", value: show.dateFormatted, valueFontSize: showDateTextSize)
        }
    }

    // MARK: - Delete

    private func deleteShow() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        PersistenceController.shared.delete(show, in: viewContext)
        dismiss()
    }

    // MARK: - Share Text

    private var shareText: String {
        var parts: [String] = []
        parts.append("🎤 \(show.titleOrEmpty)")
        if !show.venueOrEmpty.isEmpty {
            parts.append("📍 \(show.venueOrEmpty)")
        }
        parts.append("📅 \(show.dateFormatted)")
        if !purchaseManager.hasRemovedWatermark {
            parts.append("Created with My Gig Calendar")
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Info Card

private struct InfoCard: View {
    let icon: String
    let label: String
    let value: String
    let valueFontSize: Double?

    init(icon: String, label: String, value: String, valueFontSize: Double? = nil) {
        self.icon = icon
        self.label = label
        self.value = value
        self.valueFontSize = valueFontSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(value)
                .font(.system(size: valueFontSize ?? 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }
}

// MARK: - Detail Card Press Style

private struct DetailCardPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        ShowDetailView(
            show: {
                let ctx = PersistenceController.preview.container.viewContext
                let s = Show(context: ctx)
                s.title = "Comedy Night"
                s.venue = "The Laugh Factory"
                s.date = Date()
                s.userID = "preview"
                s.createdAt = Date()
                s.updatedAt = Date()
                return s
            }(),
            onEdit: {}
        )
    }
}
