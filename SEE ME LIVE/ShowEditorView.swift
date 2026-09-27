//
//  ShowEditorView.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/3/26.
//

import SwiftUI
import CoreData
import PhotosUI

// MARK: - Show Editor View
/// A beautifully styled modal form for adding or editing a show.
/// Includes calendar event creation and CloudKit sync.

struct ShowEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let showToEdit: Show?
    /// Called once, only after the show was saved locally. `true` for a new show.
    var onSaved: ((Bool) -> Void)? = nil

    // MARK: Form State
    @State private var title = ""
    @State private var venue = ""
    @State private var date = ShowDraft.newShow().date
    @State private var addToCalendar = true
    @State private var setReminder = false
    @State private var flyerPhotoItem: PhotosPickerItem?
    @State private var flyerImageData: Data?
    @State private var flyerPreviewImage: UIImage?
    @State private var isExtractingFlyerText = false
    @State private var flyerExtractionMessage: String?
    @State private var flyerImport = FlyerImportGeneration()

    /// The form as first shown; `nil` until the first appearance.
    @State private var baseline: ShowDraft?

    // Alerts
    @State private var showDiscardConfirmation = false
    @State private var isSaving = false
    @State private var didSave = false
    @State private var saveErrorMessage: String?
    @State private var postSaveNotice: PostSaveNotice?

    @FocusState private var focusedField: EditorField?

    private let userID = UserIdentityService.shared.userID

    private enum EditorField {
        case title, venue
    }

    /// Shown after a successful local save when Calendar needs attention.
    /// Dismissing it closes the editor.
    private struct PostSaveNotice {
        let title: String
        let message: String
        let offersSettings: Bool
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
                    .disabled(isSaving || postSaveNotice != nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                // Snapshot once; a repeat appearance must not reset the form.
                guard baseline == nil else { return }
                let initial = initialDraft()
                apply(initial)
                baseline = initial
                // Auto-focus the title field for new shows
                if showToEdit == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        focusedField = .title
                    }
                }
            }
            .alert("Couldn't Save Gig",
                   isPresented: Binding(
                    get: { saveErrorMessage != nil },
                    set: { if !$0 { saveErrorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
            .alert(postSaveNotice?.title ?? "",
                   isPresented: Binding(
                    get: { postSaveNotice != nil },
                    set: { _ in })) {
                if postSaveNotice?.offersSettings == true {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                        finishAfterNotice()
                    }
                }
                Button("OK", role: .cancel) { finishAfterNotice() }
            } message: {
                Text(postSaveNotice?.message ?? "")
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
        .interactiveDismissDisabled(blocksInteractiveDismiss)
    }

    // Extracted main content to help the type-checker
    private var content: some View {
        VStack(spacing: 24) {
            flyerImportSection
                .padding(.top, 8)

            formFields

            calendarToggles

            saveButton
                .padding(.top, 4)
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 16)
        .safeAreaPadding(.bottom, 20)
    }

    private var flyerImportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                flyerPreview

                VStack(alignment: .leading, spacing: 6) {
                    PhotosPicker(selection: $flyerPhotoItem, matching: .images) {
                        Label(flyerImageData == nil ? "Import Flyer" : "Change Flyer",
                              systemImage: "photo.badge.plus")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)

                    if isExtractingFlyerText {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Reading flyer text...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else if let flyerExtractionMessage {
                        Text(flyerExtractionMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            if flyerImageData != nil || isExtractingFlyerText {
                Button(role: .destructive) {
                    // Any import still running must not apply its results.
                    flyerImport.invalidate()
                    isExtractingFlyerText = false
                    flyerPhotoItem = nil
                    flyerImageData = nil
                    flyerPreviewImage = nil
                    flyerExtractionMessage = nil
                } label: {
                    Label("Remove Flyer", systemImage: "trash")
                        .font(.footnote.weight(.semibold))
                }
            }
        }
        .padding(16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
        )
        .task(id: flyerPhotoItem) {
            await importFlyer(from: flyerPhotoItem)
        }
    }

    private var flyerPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.12))

            if let flyerPreviewImage {
                Image(uiImage: flyerPreviewImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc.text.image")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .accessibilityLabel(flyerPreviewImage == nil ? "No flyer selected" : "Selected flyer")
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
                .font(.body)
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
                    .font(.body)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if addToCalendar {
                Divider()
                    .padding(.leading, 52)
                Toggle(isOn: $setReminder) {
                    Label("Reminder (1 hr before)", systemImage: "bell.fill")
                        .font(.body)
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
        let titleEmpty = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isDisabled = titleEmpty || isSaving || didSave || isExtractingFlyerText
        return VStack(spacing: 8) {
            Button {
                Task { await saveShow() }
            } label: {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(showToEdit == nil ? "Save Show" : "Update Show")
                        .font(.headline)
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
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Every editable field as one value.
    private var currentDraft: ShowDraft {
        ShowDraft(title: title,
                  venue: venue,
                  date: date,
                  addToCalendar: addToCalendar,
                  setReminder: setReminder,
                  flyerImageData: flyerImageData)
    }

    /// Whether the form differs from what it showed when it opened.
    private var hasUnsavedChanges: Bool {
        guard let baseline, !didSave else { return false }
        return currentDraft.hasChanges(from: baseline)
    }

    /// Swipe-to-dismiss would silently drop work or skip a result notice.
    private var blocksInteractiveDismiss: Bool {
        hasUnsavedChanges || isExtractingFlyerText || isSaving || postSaveNotice != nil
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
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            TextField(placeholder, text: text)
                .focused($focusedField, equals: field)
                .textInputAutocapitalization(autocapitalization ? capitalization : .never)
                .keyboardType(keyboardType)
                .autocorrectionDisabled(keyboardType == .URL)
                .font(.body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Populate (Edit Mode)

    /// The saved show's values, or the form's defaults for a new show.
    private func initialDraft() -> ShowDraft {
        guard let show = showToEdit else { return currentDraft }
        return ShowDraft(title: show.titleOrEmpty,
                         venue: show.venueOrEmpty,
                         date: show.dateOrNow,
                         addToCalendar: show.addToCalendar,
                         setReminder: show.setReminder,
                         flyerImageData: show.flyerImageData)
    }

    private func apply(_ draft: ShowDraft) {
        title = draft.title
        venue = draft.venue
        date = draft.date
        addToCalendar = draft.addToCalendar
        setReminder = draft.setReminder
        flyerImageData = draft.flyerImageData
        flyerPreviewImage = draft.flyerImageData.flatMap { UIImage(data: $0) }
    }

    // MARK: - Flyer Import

    @MainActor
    private func importFlyer(from item: PhotosPickerItem?) async {
        guard let item else { return }

        let token = flyerImport.begin()
        let dateAtImportStart = date
        /// False once this import was cancelled, replaced, or removed.
        func isStillCurrent() -> Bool {
            !Task.isCancelled && flyerImport.isCurrent(token)
        }

        isExtractingFlyerText = true
        flyerExtractionMessage = nil
        defer {
            if flyerImport.isCurrent(token) { isExtractingFlyerText = false }
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw FlyerTextExtractionError.invalidImage
            }
            guard isStillCurrent() else { return }

            let storedData = image.jpegData(compressionQuality: 0.82) ?? data
            flyerImageData = storedData
            flyerPreviewImage = UIImage(data: storedData)

            let details = try await FlyerTextExtractionService.extractShowDetails(from: storedData)
            guard isStillCurrent() else { return }

            let updated = currentDraft.applyingExtracted(title: details.title,
                                                         venue: details.venue,
                                                         date: details.date,
                                                         dateAtImportStart: dateAtImportStart)
            title = updated.title
            venue = updated.venue
            date = updated.date
            flyerExtractionMessage = details.hasValues
                ? "Flyer details filled in. Review before saving."
                : "Flyer imported, but no show details were found."
        } catch {
            guard isStillCurrent() else { return }
            flyerExtractionMessage = error.localizedDescription
        }
    }

    // MARK: - Save

    @MainActor
    private func saveShow() async {
        guard !isSaving, !didSave else { return }
        isSaving = true
        defer { isSaving = false }

        let draft = currentDraft
        let container = PersistenceController.shared.container
        let context = ShowEditorPersistence.makeContext(for: container)

        // 1. Local save first. On failure keep the draft and stop here, so
        //    nothing is written to Calendar or the public database.
        let result: ShowEditorPersistence.SaveResult
        do {
            result = try ShowEditorPersistence.save(draft,
                                                    editing: showToEdit?.objectID,
                                                    userID: userID,
                                                    in: context)
        } catch {
            print("⚠️ Core Data save error: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            saveErrorMessage = error.localizedDescription
            return
        }

        didSave = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        reportSaved(isNew: result.isNew)

        // 2. Calendar, only after the gig is safely stored.
        let notice = await syncCalendar(for: draft, result: result, context: context)

        // 3. Public sync in the background (non-blocking).
        let objectID = result.objectID
        Task.detached {
            let bgContext = PersistenceController.shared.container.newBackgroundContext()
            bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            await PublicCloudSyncService.shared.saveOrUpdate(objectID: objectID, in: bgContext)
        }

        if let notice {
            postSaveNotice = notice
        } else {
            dismiss()
        }
    }

    /// Creates, updates, or removes the calendar event for a saved show.
    /// A failed EventKit call keeps the stored identifier and returns a notice.
    @MainActor
    private func syncCalendar(for draft: ShowDraft,
                              result: ShowEditorPersistence.SaveResult,
                              context: NSManagedObjectContext) async -> PostSaveNotice? {
        let calendar = CalendarService.shared
        let existingID = result.calendarEventID

        guard draft.addToCalendar else {
            guard let existingID else { return nil }
            do {
                try calendar.removeEvent(identifier: existingID)
            } catch {
                print("⚠️ Failed to delete calendar event: \(error)")
                return calendarFailureNotice(
                    "Your gig was saved, but its Calendar event couldn't be removed. Remove it in the Calendar app.")
            }
            return storeEventID(nil, for: result.objectID, context: context)
        }

        var authorized = calendar.isAuthorized
        if !authorized {
            authorized = await calendar.requestAccess()
        }
        guard authorized else {
            return PostSaveNotice(
                title: "Calendar Access Denied",
                message: "Your gig was saved, but My Gig Calendar needs calendar access to add it to Calendar. Please enable it in Settings.",
                offersSettings: true)
        }

        let eventID: String
        do {
            eventID = try calendar.saveEvent(existingIdentifier: existingID,
                                             title: draft.trimmedTitle,
                                             venue: draft.trimmedVenue,
                                             date: draft.date,
                                             setReminder: draft.setReminder)
        } catch {
            print("⚠️ Failed to save calendar event: \(error)")
            return calendarFailureNotice(
                "Your gig was saved, but Calendar couldn't be updated. Edit the gig later to try again.")
        }
        return storeEventID(eventID, for: result.objectID, context: context)
    }

    @MainActor
    private func storeEventID(_ eventID: String?,
                              for objectID: NSManagedObjectID,
                              context: NSManagedObjectContext) -> PostSaveNotice? {
        do {
            try ShowEditorPersistence.setCalendarEventID(eventID, for: objectID, in: context)
            return nil
        } catch {
            print("⚠️ Failed to store calendar event ID: \(error)")
            return calendarFailureNotice(
                "Your gig and Calendar were updated, but the link between them couldn't be saved. Check the Calendar app before editing this gig again to avoid a duplicate event.")
        }
    }

    private func calendarFailureNotice(_ message: String) -> PostSaveNotice {
        PostSaveNotice(title: "Calendar Not Updated", message: message, offersSettings: false)
    }

    /// Reports success to the presenter at most once.
    @MainActor
    private func reportSaved(isNew: Bool) {
        guard let onSaved else { return }
        onSaved(isNew)
    }

    @MainActor
    private func finishAfterNotice() {
        postSaveNotice = nil
        dismiss()
    }
}

#Preview {
    ShowEditorView(showToEdit: nil)
        .environment(\.managedObjectContext,
                      PersistenceController.preview.container.viewContext)
}
