//
//  ShowEditorView.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/3/26.
//

import SwiftUI
import CoreData

// MARK: - Show Editor View
/// A beautifully styled modal form for adding or editing a show.
/// Includes calendar event creation and CloudKit sync.

struct ShowEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let showToEdit: Show?

    // MARK: Form State
    @State private var title = ""
    @State private var venue = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 7,
        to: Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!)!
    @State private var addToCalendar = true
    @State private var setReminder = false

    // Alerts
    @State private var showCalendarDeniedAlert = false
    @State private var showDiscardConfirmation = false
    @State private var isSaving = false

    @FocusState private var focusedField: EditorField?

    private let userID = UserIdentityService.shared.userID

    private enum EditorField {
        case title, venue
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                content
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color("AppBackground"))
            .navigationTitle(showToEdit == nil ? "Add New Gig" : "Edit Gig")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                populateFromExisting()
                // Auto-focus the title field for new shows
                if showToEdit == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        focusedField = .title
                    }
                }
            }
            .alert("Calendar Access Denied",
                   isPresented: $showCalendarDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("My Gig Calendar needs calendar access to add your gigs. Please enable it in Settings.")
            }
            .confirmationDialog("Discard Changes?",
                                isPresented: $showDiscardConfirmation,
                                titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes that will be lost.")
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(isSaving)
    }

    // Extracted main content to help the type-checker
    private var content: some View {
        VStack(spacing: 24) {
            formFields
                .padding(.top, 8)

            calendarToggles

            saveButton
                .padding(.top, 4)
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 16)
        .safeAreaPadding(.bottom, 20)
    }

    // Extracted form fields
    private var formFields: some View {
        VStack(spacing: 0) {
            editorField(
                icon: "text.quote",
                placeholder: "Show title (required)",
                text: $title,
                field: .title,
                capitalization: .words
            )
            .submitLabel(.next)
            .onSubmit { focusedField = .venue }
            
            Divider().padding(.leading, 52)

            editorField(
                icon: "mappin.and.ellipse",
                placeholder: "Venue name",
                text: $venue,
                field: .venue,
                capitalization: .words
            )
            .submitLabel(.done)
            .onSubmit { focusedField = nil }
            
            Divider().padding(.leading, 52)

            dateTimePicker
        }
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }

    // Extracted date/time picker
    private var dateTimePicker: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 17))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            DatePicker("Date & Time",
                       selection: $date,
                       displayedComponents: [.date, .hourAndMinute])
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // Extracted toggles
    private var calendarToggles: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $addToCalendar) {
                Label("Add to Calendar", systemImage: "calendar.badge.plus")
                    .font(.system(size: 17))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if addToCalendar {
                Divider()
                    .padding(.leading, 52)
                Toggle(isOn: $setReminder) {
                    Label("Reminder (1 hr before)", systemImage: "bell.fill")
                        .font(.system(size: 17))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: addToCalendar)
    }

    // Extracted save button
    private var saveButton: some View {
        let titleEmpty = title.trimmingCharacters(in: .whitespaces).isEmpty
        let isDisabled = titleEmpty || isSaving
        return VStack(spacing: 8) {
            Button {
                let impact = UINotificationFeedbackGenerator()
                impact.notificationOccurred(.success)
                Task { await saveShow() }
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(showToEdit == nil ? "Save Show" : "Update Show")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isDisabled ? Color.secondary.opacity(0.25) : Color.primary)
                )
                .foregroundStyle(Color("AppBackground"))
            }
            .disabled(isDisabled)

            if titleEmpty {
                Text("Enter a show title to save")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Whether the form has unsaved changes worth warning about.
    private var hasUnsavedChanges: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        if let show = showToEdit {
            // Editing: check if anything changed
            return trimmedTitle != show.titleOrEmpty ||
                   venue != show.venueOrEmpty
        }
        // New show: has the user typed anything?
        return !trimmedTitle.isEmpty || !venue.isEmpty
    }

    // MARK: - Editor Field

    @ViewBuilder
    private func editorField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: EditorField,
        capitalization: TextInputAutocapitalization = .never,
        keyboardType: UIKeyboardType = .default,
        autocapitalization: Bool = true
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            TextField(placeholder, text: text)
                .focused($focusedField, equals: field)
                .textInputAutocapitalization(autocapitalization ? capitalization : .never)
                .keyboardType(keyboardType)
                .autocorrectionDisabled(keyboardType == .URL)
                .font(.system(size: 17))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Populate (Edit Mode)

    private func populateFromExisting() {
        guard let show = showToEdit else { return }
        title = show.titleOrEmpty
        venue = show.venueOrEmpty
        date = show.dateOrNow
        addToCalendar = show.addToCalendar
        setReminder = show.setReminder
    }

    // MARK: - Save

    @MainActor
    private func saveShow() async {
        isSaving = true
        defer { isSaving = false }

        let isNew = (showToEdit == nil)
        let show: Show
        if let existing = showToEdit {
            show = existing
        } else {
            show = Show(context: viewContext)
        }
        let now = Date()

        show.title = title.trimmingCharacters(in: .whitespaces)
        show.role = ""
        show.venue = venue.trimmingCharacters(in: .whitespaces)
        show.date = date
        show.price = 0
        show.ticketLink = ""
        if isNew {
            show.notes = ""
        }
        show.flyerImageData = nil
        show.addToCalendar = addToCalendar
        show.setReminder = setReminder
        show.userID = userID
        show.updatedAt = now
        if isNew {
            show.createdAt = now
        }

        // Calendar integration.
        if addToCalendar {
            if CalendarService.shared.isAuthorized {
                let eventID = CalendarService.shared.createOrUpdateEvent(for: show)
                show.calendarEventID = eventID
            } else {
                let granted = await CalendarService.shared.requestAccess()
                if granted {
                    let eventID = CalendarService.shared.createOrUpdateEvent(for: show)
                    show.calendarEventID = eventID
                } else {
                    showCalendarDeniedAlert = true
                }
            }
        } else {
            if show.calendarEventID != nil {
                CalendarService.shared.deleteEvent(for: show)
                show.calendarEventID = nil
            }
        }

        show.needsPublicSync = true

        // Save Core Data synchronously to ensure persistence before dismissing.
        do {
            if viewContext.hasChanges {
                try viewContext.save()
            }
        } catch {
            print("⚠️ Core Data save error: \(error)")
        }

        // Dismiss immediately after local save so the UI updates.
        dismiss()

        // Sync to CloudKit in the background (non-blocking).
        let objectID = show.objectID
        Task.detached {
            let bgContext = PersistenceController.shared.container.newBackgroundContext()
            bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            await PublicCloudSyncService.shared.saveOrUpdate(objectID: objectID, in: bgContext)
        }
    }
}

#Preview {
    ShowEditorView(showToEdit: nil)
        .environment(\.managedObjectContext,
                      PersistenceController.preview.container.viewContext)
}
