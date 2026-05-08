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
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("showDateTextSize") private var showDateTextSize: Double = 12

    let onEdit: () -> Void

    @State private var showDeleteConfirmation = false
    @State private var showFullScreenImage = false
    @State private var appeared = false
    @State private var headerUIImage: UIImage? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: Header Image
                headerImage

                VStack(alignment: .leading, spacing: 24) {
                    // MARK: Title & Role
                    VStack(alignment: .leading, spacing: 8) {
                        Text(show.titleOrEmpty)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.primary)
                            .tracking(-0.3)

                        if !show.roleOrEmpty.isEmpty {
                            Text(show.roleOrEmpty)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 24)

                    // MARK: Info Cards Grid
                    infoCardsGrid

                    // MARK: Ticket Button
                    if show.hasTicketLink, let url = show.normalizedTicketURL {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            UIApplication.shared.open(url)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "ticket.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Get Tickets")
                                    .font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .opacity(0.7)
                            }
                            .foregroundStyle(Color("AppBackground"))
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary)
                            )
                        }
                        .buttonStyle(DetailCardPress())
                    }

                    // MARK: Notes
                    if !show.notesOrEmpty.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Notes", systemImage: "note.text")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            Text(show.notesOrEmpty)
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                                .lineSpacing(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(18)
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
                        )
                    }

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
                            .buttonStyle(DetailCardPress())
                        }

                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Show", systemImage: "trash")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
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
        .fullScreenCover(isPresented: $showFullScreenImage) {
            fullScreenImageViewer
        }
        .onAppear {
            if let data = show.flyerImageData {
                Task.detached(priority: .userInitiated) {
                    let uiImage = UIImage(data: data)
                    await MainActor.run {
                        self.headerUIImage = uiImage
                    }
                }
            }
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }

    // MARK: - Header Image

    @ViewBuilder
    private var headerImage: some View {
        if let uiImage = headerUIImage {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showFullScreenImage = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .clear, Color("AppBackground").opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Tap-to-expand hint
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("View Flyer")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(16)
                }
            }
            .buttonStyle(DetailCardPress())
        } else if show.flyerImageData != nil {
            // Loading state or placeholder while decompressing
            Color.gray.opacity(0.1)
                .frame(height: 300)
        } else {
            // Subtle placeholder — don't waste vertical space
            HStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color.accentColor.opacity(0.5))
                Text("No flyer added")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.06), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
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
            InfoCard(icon: "tag.fill", label: "Price", value: show.priceFormatted)
            if !show.roleOrEmpty.isEmpty {
                InfoCard(icon: "person.fill", label: "Role", value: show.roleOrEmpty)
            }
        }
    }

    // MARK: - Full-Screen Image Viewer

    private var fullScreenImageViewer: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let data = show.flyerImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea(edges: .horizontal)
            }

            VStack {
                HStack {
                    Text(show.titleOrEmpty)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                    Button {
                        showFullScreenImage = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                if let data = show.flyerImageData, let uiImage = UIImage(data: data) {
                    HStack {
                        Spacer()
                        ShareLink(item: Image(uiImage: uiImage),
                                  preview: SharePreview(show.titleOrEmpty, image: Image(uiImage: uiImage))) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Share Flyer")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 13)
                            .background(.ultraThinMaterial, in: Capsule())
                        }
                        Spacer()
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Delete

    private func deleteShow() {
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.warning)
        PublicCloudSyncService.shared.markForDelete(show: show)
        CalendarService.shared.deleteEvent(for: show)
        viewContext.delete(show)
        PersistenceController.shared.save(context: viewContext)
        Task {
            let bgContext = PersistenceController.shared.container.newBackgroundContext()
            await PublicCloudSyncService.shared.flushQueue(using: bgContext)
        }
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
        if show.price > 0 {
            parts.append("🎟 \(show.priceFormatted)")
        }
        if show.hasTicketLink, let url = show.normalizedTicketURL {
            parts.append("🔗 \(url.absoluteString)")
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
    @Environment(\.colorScheme) private var colorScheme

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
                s.role = "Headliner"
                s.date = Date()
                s.price = 25
                s.ticketLink = "https://example.com"
                s.notes = "Doors open at 7 PM. Bring your friends and get ready for an unforgettable evening of laughs!"
                s.userID = "preview"
                s.createdAt = Date()
                s.updatedAt = Date()
                return s
            }(),
            onEdit: {}
        )
    }
}
