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
    @State private var roastWorkspace = RoastWorkspace()
    @State private var newKnownBullet = ""
    @State private var selectedJokeText = ""
    @State private var saveRoastWorkItem: DispatchWorkItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text(show.titleOrEmpty)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.primary)
                            .tracking(-0.3)
                    }
                    .padding(.top, 24)

                    // MARK: Info Cards Grid
                    infoCardsGrid

                    roastWorkspaceSection

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
                                .foregroundStyle(.red.opacity(0.7))
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
            roastWorkspace = show.roastWorkspace
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
        .onDisappear {
            persistRoastWorkspace()
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

    // MARK: - Roast Workspace

    private var roastWorkspaceSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Roast Mode")
                        .font(.system(size: 18, weight: .bold))
                    Text("Target notes, joke drafts, and ready lines")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            knownFactsSection
            jokeNotepadSection
            roastsSection
        }
        .padding(16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }

    private var knownFactsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Things You Know", icon: "list.bullet")

            if roastWorkspace.knownBullets.isEmpty {
                Text("Add facts, habits, stories, tells, or details about this target.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(roastWorkspace.knownBullets.enumerated()), id: \.offset) { index, bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                            Text(bullet)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                            Button {
                                roastWorkspace.knownBullets.remove(at: index)
                                persistRoastWorkspace()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary.opacity(0.55))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Add something you know", text: $newKnownBullet)
                    .font(.system(size: 14))
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onSubmit(addKnownBullet)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button(action: addKnownBullet) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 38, height: 38)
                        .foregroundStyle(Color("AppBackground"))
                        .background(Color.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(newKnownBullet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(newKnownBullet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
        }
    }

    private var jokeNotepadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Joke Notepad", icon: "square.and.pencil")

            SelectableNotepadTextView(
                text: Binding(
                    get: { roastWorkspace.jokePad },
                    set: { newValue in
                        roastWorkspace.jokePad = newValue
                        persistRoastWorkspaceDebounced()
                    }
                ),
                selectedText: $selectedJokeText
            )
            .frame(minHeight: 150)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    promoteSelectedJokeText()
                } label: {
                    Label("Promote Selection", systemImage: "arrow.up.doc.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(Color("AppBackground"))
                        .background(Color.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(selectedJokeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(selectedJokeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)

                Button {
                    roastWorkspace.jokePad = ""
                    selectedJokeText = ""
                    persistRoastWorkspace()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 42, height: 42)
                        .foregroundStyle(.red.opacity(0.75))
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(roastWorkspace.jokePad.isEmpty)
            }
        }
    }

    private var roastsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Roasts", icon: "quote.bubble.fill")

            if roastWorkspace.roasts.isEmpty {
                Text("Highlight text in the notepad and promote it when a line is ready.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(roastWorkspace.roasts.enumerated()), id: \.offset) { index, roast in
                        HStack(alignment: .top, spacing: 10) {
                            Text(roast)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                roastWorkspace.roasts.remove(at: index)
                                persistRoastWorkspace()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary.opacity(0.55))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    private func addKnownBullet() {
        let trimmed = newKnownBullet.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        roastWorkspace.knownBullets.append(trimmed)
        newKnownBullet = ""
        persistRoastWorkspace()
    }

    private func promoteSelectedJokeText() {
        let trimmed = selectedJokeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        roastWorkspace.roasts.append(trimmed)
        selectedJokeText = ""
        persistRoastWorkspace()
    }

    private func persistRoastWorkspaceDebounced() {
        saveRoastWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            persistRoastWorkspace()
        }
        saveRoastWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func persistRoastWorkspace() {
        saveRoastWorkItem?.cancel()
        show.roastWorkspace = roastWorkspace
        show.updatedAt = Date()
        PersistenceController.shared.save(context: viewContext)
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

private struct SelectableNotepadTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedText: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .label
        textView.tintColor = UIColor(Color.accentColor)
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableNotepadTextView

        init(parent: SelectableNotepadTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            updateSelection(from: textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            updateSelection(from: textView)
        }

        private func updateSelection(from textView: UITextView) {
            guard let range = Range(textView.selectedRange, in: textView.text),
                  !range.isEmpty else {
                parent.selectedText = ""
                return
            }
            parent.selectedText = String(textView.text[range])
        }
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
