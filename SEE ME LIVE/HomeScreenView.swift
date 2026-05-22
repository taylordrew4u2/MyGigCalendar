//
//  HomeScreenView.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/3/26.
//
//  Calendar-first dashboard. The performer's month and next dates are the
//  primary surface; flyer generation and settings are secondary actions.
//

import SwiftUI
import CoreData

// MARK: - Home Screen View

struct HomeScreenView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Show.date, ascending: true)],
        predicate: NSPredicate(format: "date >= %@", Date() as NSDate),
        animation: .default
    ) private var upcomingShows: FetchedResults<Show>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Show.date, ascending: true)],
        animation: .default
    ) private var allShows: FetchedResults<Show>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Show.date, ascending: false)],
        predicate: NSPredicate(format: "date < %@", Date() as NSDate),
        animation: .default
    ) private var pastShows: FetchedResults<Show>

    @State private var isPresentingEditor = false
    @State private var showToEdit: Show?
    @State private var toastMessage: String?
    @State private var showToast = false
    @State private var isPresentingDateSizeSheet = false
    @State private var isPresentingShareSheet = false
    @State private var isPresentingSettingsFAQ = false
    @State private var calendarMonth: Date = Date()
    @State private var selectedCalendarDate: Date?
    @State private var searchText = ""
    @State private var showPastShows = false
    @AppStorage("showDateTextSize") private var showDateTextSize: Double = 12

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Filtered Shows (Search)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var filteredUpcomingShows: [Show] {
        guard !searchText.isEmpty else { return Array(upcomingShows) }
        return upcomingShows.filter { matchesSearch($0) }
    }

    private var filteredPastShows: [Show] {
        guard !searchText.isEmpty else { return Array(pastShows) }
        return pastShows.filter { matchesSearch($0) }
    }

    private func matchesSearch(_ show: Show) -> Bool {
        let q = searchText.lowercased()
        return show.titleOrEmpty.lowercased().contains(q) ||
               show.venueOrEmpty.lowercased().contains(q)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Body
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color("AppBackground").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        monthHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 4)

                        calendarCard
                            .padding(.horizontal, 20)

                        if !allShows.isEmpty {
                            createFlyerBlock
                                .padding(.horizontal, 20)
                        }

                        if !allShows.isEmpty {
                            searchField
                                .padding(.horizontal, 20)
                        }

                        if let selected = selectedCalendarDate {
                            selectedDaySection(date: selected)
                                .padding(.horizontal, 20)
                        } else if !filteredUpcomingShows.isEmpty {
                            upcomingSection
                                .padding(.horizontal, 20)
                        }

                        if !filteredPastShows.isEmpty {
                            pastSection
                                .padding(.horizontal, 20)
                        }

                        if allShows.isEmpty {
                            emptyState
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                        }

                        if !searchText.isEmpty &&
                            filteredUpcomingShows.isEmpty &&
                            filteredPastShows.isEmpty {
                            searchEmptyState
                                .padding(.horizontal, 20)
                        }

                        settingsFAQButton
                            .padding(.horizontal, 20)
                            .padding(.top, 2)

                        Color.clear.frame(height: 40)
                    }
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)

                if showToast, let msg = toastMessage {
                    toast(msg)
                        .padding(.bottom, 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { topToolbar }
            .sheet(isPresented: $isPresentingEditor, onDismiss: {
                if showToEdit != nil {
                    showToastBriefly("Show updated")
                } else if !allShows.isEmpty {
                    showToastBriefly("Show saved")
                }
                showToEdit = nil
            }) {
                ShowEditorView(showToEdit: showToEdit)
                    .environment(\.managedObjectContext, viewContext)
            }
            .fullScreenCover(isPresented: $isPresentingShareSheet) {
                ShareImageEditorView(
                    shows: Array(allShows),
                    performerName: CalendarDisplayOptions.load().performerName
                )
            }
            .sheet(isPresented: $isPresentingDateSizeSheet) {
                DateTextSizeSheet(showDateTextSize: $showDateTextSize)
            }
            .sheet(isPresented: $isPresentingSettingsFAQ) {
                SettingsFAQView()
            }
            .task { await performBackgroundSync() }
            .refreshable {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                await performBackgroundSync()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Toolbar
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @ToolbarContentBuilder
    private var topToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.18)) {
                    calendarMonth = Date()
                    selectedCalendarDate = nil
                    searchText = ""
                    showPastShows = false
                }
            } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(red: 0.92, green: 0.14, blue: 0.16))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Home")
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isPresentingShareSheet = true
                } label: {
                    Label("Create flyer", systemImage: "doc.richtext")
                }
                .disabled(allShows.isEmpty)

                Button {
                    isPresentingDateSizeSheet = true
                } label: {
                    Label("Date text size", systemImage: "textformat.size")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .accessibilityLabel("More")
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Month Header (calendar-first eyebrow)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var monthHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Calendar")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Text(monthYearString(from: calendarMonth))
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 12)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showToEdit = nil
                isPresentingEditor = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Add show")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color("AppBackground"))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(Color.primary)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add new show")
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Calendar Card
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var calendarCard: some View {
        VStack(spacing: 0) {
            // Month nav strip
            HStack(spacing: 0) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        calendarMonth = Calendar.current.date(byAdding: .month, value: -1, to: calendarMonth) ?? calendarMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 36)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        calendarMonth = Date()
                        selectedCalendarDate = nil
                    }
                } label: {
                    Text("Today")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay(
                            Capsule().strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        calendarMonth = Calendar.current.date(byAdding: .month, value: 1, to: calendarMonth) ?? calendarMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            // Weekday headers
            let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .padding(.bottom, 6)

            // Day grid
            let days = calendarDays(for: calendarMonth)
            let showDates = showDateSet()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    CalendarDayCell(
                        day: day,
                        hasShow: day != nil && showDates.contains(calendarDayKey(day!)),
                        isSelected: day != nil && selectedCalendarDate.map { Calendar.current.isDate($0, inSameDayAs: day!) } ?? false,
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                if let d = day {
                                    if selectedCalendarDate.map({ Calendar.current.isDate($0, inSameDayAs: d) }) ?? false {
                                        selectedCalendarDate = nil
                                    } else {
                                        selectedCalendarDate = d
                                    }
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 10)
        }
        .padding(12)
        .background(Color("CardBackground"))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Search Field (hairline)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search shows", text: $searchText)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Create Flyer CTA
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var createFlyerBlock: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isPresentingShareSheet = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.92, green: 0.14, blue: 0.16))
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Create Flyer")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Turn your upcoming dates into a shareable post.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color("CardBackground"))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(RowPress())
        .accessibilityLabel("Create Flyer")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Selected Day Section
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func selectedDaySection(date: Date) -> some View {
        let dayShows = showsOn(date: date)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedDayLabel(date))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedCalendarDate = nil
                    }
                } label: {
                    Text("Clear")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if dayShows.isEmpty {
                VStack(spacing: 10) {
                    Text("No shows on this date")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showToEdit = nil
                        isPresentingEditor = true
                    } label: {
                        Text("Add a show")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
                )
            } else {
                showRowList(dayShows, dim: false)
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Upcoming Section
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("UPCOMING")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(filteredUpcomingShows.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            showRowList(filteredUpcomingShows, dim: false)
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Past Shows (collapsed by default)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var pastSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showPastShows.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text("PAST")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                    Text("\(filteredPastShows.count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Image(systemName: showPastShows ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if showPastShows {
                showRowList(filteredPastShows, dim: true)
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Show Row List (shared)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @ViewBuilder
    private func showRowList(_ shows: [Show], dim: Bool) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(shows.enumerated()), id: \.element.objectID) { idx, show in
                NavigationLink {
                    ShowDetailView(show: show) {
                        showToEdit = show
                        isPresentingEditor = true
                    }
                } label: {
                    ShowRow(show: show)
                        .opacity(dim ? 0.62 : 1.0)
                }
                .buttonStyle(RowPress())
                .contextMenu {
                    Button {
                        showToEdit = show
                        isPresentingEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deleteShow(show)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                if idx < shows.count - 1 {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Empty / Search Empty States
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("No shows yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Add your first gig to start your calendar.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showToEdit = nil
                isPresentingEditor = true
            } label: {
                Text("Add a show")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("AppBackground"))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.primary))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    private var searchEmptyState: some View {
        VStack(spacing: 8) {
            Text("No results")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            Text("No shows match \"\(searchText)\"")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Settings / FAQ
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var settingsFAQButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isPresentingSettingsFAQ = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .semibold))
                Text("Settings / FAQ")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings and FAQ")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Toast
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func toast(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
            Text(message)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(Color("AppBackground"))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.primary))
    }

    private func showToastBriefly(_ message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.4)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.25)) { showToast = false }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Calendar Helpers
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func monthYearString(from date: Date) -> String {
        Self.monthYearFormatter.string(from: date)
    }

    private func selectedDayLabel(_ date: Date) -> String {
        Self.selectedDayFormatter.string(from: date).uppercased()
    }

    private func calendarDays(for month: Date) -> [Date?] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month),
              let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: month))
        else { return [] }

        let firstWeekday = cal.component(.weekday, from: firstOfMonth) // 1 = Sunday
        let leadingBlanks = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)

        for day in range {
            if let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func calendarDayKey(_ date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        return "\(y)-\(m)-\(d)"
    }

    private func showDateSet() -> Set<String> {
        var set = Set<String>()
        for show in allShows {
            if let d = show.date {
                set.insert(calendarDayKey(d))
            }
        }
        return set
    }

    private func showsOn(date: Date) -> [Show] {
        allShows.filter { show in
            guard let d = show.date else { return false }
            return Calendar.current.isDate(d, inSameDayAs: date)
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Formatters
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let selectedDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Sync / Delete
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func performBackgroundSync() async {
        let bgContext = PersistenceController.shared.container.newBackgroundContext()
        await PublicCloudSyncService.shared.flushQueue(using: bgContext)
    }

    private func deleteShow(_ show: Show) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        PublicCloudSyncService.shared.markForDelete(show: show)
        CalendarService.shared.deleteEvent(for: show)
        viewContext.delete(show)
        PersistenceController.shared.save(context: viewContext)
        Task {
            let bgContext = PersistenceController.shared.container.newBackgroundContext()
            await PublicCloudSyncService.shared.flushQueue(using: bgContext)
        }
        showToastBriefly("Show deleted")
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Calendar Day Cell
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct CalendarDayCell: View {
    let day: Date?
    let hasShow: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        if let day = day {
            let isToday = Calendar.current.isDateInToday(day)

            Button(action: onSelect) {
                VStack(spacing: 3) {
                    Text("\(Calendar.current.component(.day, from: day))")
                        .font(.system(size: 14, weight: isToday || isSelected ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected ? Color("AppBackground") :
                            isToday ? Color.accentColor :
                            Color.primary
                        )

                    Circle()
                        .fill(hasShow ? (isSelected ? Color("AppBackground") : Color.accentColor) : Color.clear)
                        .frame(width: 4, height: 4)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.primary : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isToday && !isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear
                .frame(height: 38)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Show Row (flat, hairline)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct ShowRow: View {
    let show: Show
    @AppStorage("showDateTextSize") private var showDateTextSize: Double = 12

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 1) {
                Text(monthAbbrev(from: show.dateOrNow))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .textCase(.uppercase)
                Text(dayNumber(from: show.dateOrNow))
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
            .frame(width: 44, height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(show.titleOrEmpty)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 8) {
                    if !show.venueOrEmpty.isEmpty {
                        Text(show.venueOrEmpty)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    Text(timeString(from: show.dateOrNow))
                        .font(.system(size: showDateTextSize))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func monthAbbrev(from date: Date) -> String { ShowRow.monthAbbrevFormatter.string(from: date) }
    private func dayNumber(from date: Date) -> String { ShowRow.dayFormatter.string(from: date) }
    private func timeString(from date: Date) -> String { ShowRow.timeFormatter.string(from: date) }

    private static let monthAbbrevFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f
    }()
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Settings / FAQ Sheet
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct SettingsFAQView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    faqItem(
                        "How do I add a gig?",
                        "Tap Add show on the home screen, enter the title, venue, and date, then save."
                    )
                    faqItem(
                        "How do I make a flyer?",
                        "Add at least one show, then tap Create Flyer. You can change the format, colors, layout, and text before exporting."
                    )
                    faqItem(
                        "Why is there a watermark?",
                        "Free exports include My Gig Calendar branding. Use Remove Watermark to unlock clean HD exports."
                    )
                    faqItem(
                        "How do I restore my purchase?",
                        "Open the flyer editor, tap Remove watermark, then tap Restore Purchases."
                    )
                    faqItem(
                        "Do shows sync to my calendar?",
                        "When calendar access is enabled, saved gigs can be added to your device calendar."
                    )
                }
                .padding(20)
            }
            .background(Color("AppBackground").ignoresSafeArea())
            .navigationTitle("Settings / FAQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func faqItem(_ question: String, _ answer: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            Text(answer)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Button Styles
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct RowPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.primary.opacity(0.04) : Color.clear)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    HomeScreenView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
