//
//  HTMLExportService.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/3/26.
//

import Foundation

// MARK: - Calendar Display Options
/// Controls how the exported / shared HTML calendar looks.
struct CalendarDisplayOptions: Codable, Equatable {

    enum Theme: String, CaseIterable, Codable, Identifiable {
        case warm   = "Warm"
        case dark   = "Dark"
        case neon   = "Neon"
        case minimal = "Minimal"
        var id: String { rawValue }
    }

    enum Layout: String, CaseIterable, Codable, Identifiable {
        case list = "List"
        case grid = "Grid"
        var id: String { rawValue }
    }

    var theme: Theme         = .warm
    var layout: Layout       = .list
    var showPastShows: Bool  = false
    var accentHex: String    = "#9A6544"   // warm brown default
    var performerName: String = ""

    // Persist to UserDefaults
    static let defaultsKey = "calendarDisplayOptions"

    static func load() -> CalendarDisplayOptions {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let opts = try? JSONDecoder().decode(CalendarDisplayOptions.self, from: data)
        else { return CalendarDisplayOptions() }
        return opts
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: CalendarDisplayOptions.defaultsKey)
        }
    }
}

// MARK: - HTML Export Service
/// Generates a beautiful, static HTML page with all upcoming shows.

enum HTMLExportService {

    /// Generates HTML with full CalendarDisplayOptions support.
    static func generateHTML(shows: [Show], options: CalendarDisplayOptions = CalendarDisplayOptions(),
                             showsWatermark: Bool = true) -> String {
        let filtered = options.showPastShows
            ? shows.sorted { $0.dateOrNow < $1.dateOrNow }
            : shows.filter { $0.dateOrNow >= Date() }.sorted { $0.dateOrNow < $1.dateOrNow }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let generatedDate = dateFormatter.string(from: Date())

        let accent = options.accentHex
        let css = buildCSS(options: options)

        let titleText = {
            let trimmed = options.performerName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "My" {
                return "Performance Calendar"
            }
            return "\(trimmed)'s Shows"
        }()

        // Group shows by month
        let cal = Calendar.current
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"

        // Determine which months to render
        var monthStarts: [Date] = []
        if filtered.isEmpty {
            // Show current + next 2 months even if empty
            let now = Date()
            for offset in 0..<3 {
                if let m = cal.date(byAdding: .month, value: offset, to: cal.startOfMonth(for: now)) {
                    monthStarts.append(m)
                }
            }
        } else {
            // Collect all months that contain shows
            var seen = Set<String>()
            for show in filtered {
                let start = cal.startOfMonth(for: show.dateOrNow)
                let key = monthFormatter.string(from: start)
                if seen.insert(key).inserted { monthStarts.append(start) }
            }
            monthStarts.sort()
        }

        let calendarsHTML = monthStarts.map { monthStart in
            buildMonthCalendar(monthStart: monthStart, shows: filtered, options: options, cal: cal, monthFormatter: monthFormatter)
        }.joined(separator: "\n")

        let detailListHTML = filtered.isEmpty ? emptyStateHTML : buildDetailList(shows: filtered, options: options)

        let appIconSVG = buildAppIconSVG(accent: accent)
        let watermarkHTML = showsWatermark
            ? "<p class=\"watermark\">Created with My Gig Calendar</p>"
            : ""

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>My Gig Calendar - \(titleText)</title>
            <style>
        \(css)
            </style>
        </head>
        <body>
            <div class="container">
                <header>
                    <div class="app-icon">\(appIconSVG)</div>
                    <h1>My Gig Calendar</h1>
                    <p class="sub">\(titleText)</p>
                    <p class="gen">Updated \(generatedDate)</p>
                </header>

                <main>
                    \(calendarsHTML)
                    <section class="detail-section">
                        <h2 class="section-title">📋 Show Details</h2>
                        \(detailListHTML)
                    </section>
                </main>

                <footer>
                    \(watermarkHTML)
                </footer>
            </div>
        </body>
        </html>
        """
    }

    // MARK: - Legacy convenience wrapper (keeps existing callers building)
    static func generateHTML(shows: [Show], performerName: String = "",
                             showsWatermark: Bool = true) -> String {
        var opts = CalendarDisplayOptions()
        opts.performerName = performerName
        return generateHTML(shows: shows, options: opts, showsWatermark: showsWatermark)
    }

    /// Saves HTML to a temporary file and returns the URL
    static func saveHTMLToFile(html: String) -> URL? {
        let fileName = "My_Gig_Calendar_\(Date().timeIntervalSince1970).html"
        let tempDir  = FileManager.default.temporaryDirectory
        let fileURL  = tempDir.appendingPathComponent(fileName)
        do {
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving HTML file: \(error)")
            return nil
        }
    }

    // MARK: - CSS

    private static func buildCSS(options: CalendarDisplayOptions) -> String {
        let accent = options.accentHex

        switch options.theme {
        case .warm:
            return warmCSS(accent: accent)
        case .dark:
            return darkCSS(accent: accent)
        case .neon:
            return neonCSS(accent: accent)
        case .minimal:
            return minimalCSS(accent: accent)
        }
    }

    // Shared structural CSS + theme-specific colours ─────────────────────────

    private static func sharedCSS(
        bg: String, cardBg: String, headerBg: String,
        text: String, subText: String, border: String,
        accent: String, shadow: String,
        calEmptyBg: String, calTodayRing: String,
        calHasShowBg: String, calPastText: String
    ) -> String {
        return """
        * { margin:0; padding:0; box-sizing:border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: \(bg);
            color: \(text);
            line-height: 1.5;
            padding: 20px;
            min-height: 100vh;
        }
        .container { max-width: 780px; margin: 0 auto; }
        .watermark {
            text-align: center;
            color: \(subText);
            font-size: 0.82rem;
            font-weight: 600;
            opacity: 0.78;
            padding: 18px 0 6px;
        }

        /* ── Header ── */
        header {
            text-align: center;
            padding: 36px 20px 28px;
            background: \(headerBg);
            border-radius: 20px;
            box-shadow: 0 4px 24px \(shadow);
            margin-bottom: 32px;
            border: 1.5px solid \(border);
        }
        .app-icon {
            display: inline-block;
            margin-bottom: 12px;
            filter: drop-shadow(0 4px 12px \(accent)55);
        }
        header h1 {
            font-size: 2rem;
            font-weight: 800;
            color: \(accent);
            letter-spacing: 0.04em;
            font-family: Georgia, serif;
        }
        header .sub { font-size: 1.05rem; color: \(subText); margin-top: 5px; }
        header .gen { font-size: 0.8rem; color: \(subText); margin-top: 8px; font-style: italic; opacity: 0.7; }

        /* ── Calendar section ── */
        .cal-section {
            background: \(cardBg);
            border-radius: 18px;
            border: 1.5px solid \(border);
            box-shadow: 0 2px 16px \(shadow);
            margin-bottom: 28px;
            overflow: hidden;
        }
        .cal-month-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 16px 20px;
            background: \(accent)18;
            border-bottom: 1.5px solid \(border);
        }
        .cal-month-label {
            font-size: 1.2rem;
            font-weight: 700;
            color: \(accent);
            font-family: Georgia, serif;
        }
        .cal-show-count {
            font-size: 0.78rem;
            font-weight: 600;
            color: \(subText);
            background: \(accent)22;
            padding: 4px 10px;
            border-radius: 20px;
        }
        .cal-grid {
            display: grid;
            grid-template-columns: repeat(7, 1fr);
            padding: 12px;
            gap: 4px;
        }
        .cal-dow {
            text-align: center;
            font-size: 0.72rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.06em;
            color: \(subText);
            padding: 6px 0;
        }
        .cal-day {
            aspect-ratio: 1;
            border-radius: 10px;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 3px;
            cursor: default;
            transition: background 0.15s ease;
            position: relative;
            padding: 4px 2px;
            min-width: 0;
        }
        .cal-empty { background: transparent !important; }
        .cal-day-num {
            font-size: 0.9rem;
            font-weight: 500;
            line-height: 1;
        }
        .cal-past .cal-day-num { color: \(calPastText); }
        .cal-today {
            background: \(calTodayRing);
            border: 2px solid \(accent);
        }
        .cal-today .cal-day-num { color: \(accent); font-weight: 800; }
        .cal-has-show {
            background: \(calHasShowBg);
        }
        .cal-has-show .cal-day-num { font-weight: 700; color: \(accent); }
        .cal-dots {
            display: flex;
            gap: 2px;
            align-items: center;
            justify-content: center;
            flex-wrap: nowrap;
        }
        .cal-dot {
            width: 5px;
            height: 5px;
            border-radius: 50%;
            background: \(accent);
            display: inline-block;
            flex-shrink: 0;
        }
        .cal-dot-extra {
            font-size: 0.55rem;
            font-weight: 700;
            color: \(accent);
        }

        /* ── Detail Section ── */
        .detail-section { margin-bottom: 40px; }
        .section-title {
            font-size: 1.05rem;
            font-weight: 700;
            color: \(subText);
            margin-bottom: 14px;
            letter-spacing: 0.03em;
        }
        .detail-card {
            display: flex;
            gap: 16px;
            background: \(cardBg);
            border-radius: 14px;
            border: 1.5px solid \(border);
            box-shadow: 0 2px 10px \(shadow);
            padding: 16px;
            margin-bottom: 14px;
            transition: transform 0.15s ease;
        }
        .detail-card:hover { transform: translateY(-2px); }
        .detail-past { opacity: 0.6; }
        .detail-date-col {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-width: 52px;
            background: \(accent)18;
            border-radius: 10px;
            padding: 10px 6px;
            border: 1.5px solid \(accent)33;
            flex-shrink: 0;
        }
        .detail-day-num {
            font-size: 1.7rem;
            font-weight: 800;
            color: \(accent);
            line-height: 1;
        }
        .detail-month-abbr {
            font-size: 0.65rem;
            font-weight: 700;
            color: \(subText);
            letter-spacing: 0.08em;
            margin-top: 2px;
        }
        .detail-body { flex: 1; min-width: 0; }
        .detail-title {
            font-size: 1.1rem;
            font-weight: 700;
            color: \(text);
            font-family: Georgia, serif;
            margin-bottom: 5px;
        }
        .detail-venue {
            font-size: 0.88rem;
            color: \(subText);
            margin-bottom: 3px;
        }
        .detail-datetime {
            font-size: 0.84rem;
            color: \(subText);
            margin-bottom: 8px;
        }
        .detail-chips { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; }
        .detail-chip {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 20px;
            font-size: 0.7rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.04em;
        }
        .urgent-chip { background: \(accent); color: #fff; }
        .past-chip   { background: #88888833; color: #888; }

        /* ── Empty state ── */
        .empty-state {
            text-align: center;
            padding: 60px 20px;
            background: \(cardBg);
            border-radius: 14px;
            border: 2px dashed \(border);
            margin-bottom: 14px;
        }
        .empty-state-icon { font-size: 3.5rem; margin-bottom: 16px; opacity: 0.4; }
        .empty-state h2 { color: \(accent); font-size: 1.5rem; font-family: Georgia, serif; margin-bottom: 6px; }
        .empty-state p  { color: \(subText); }

        footer { text-align: center; padding: 28px 20px 12px; color: \(subText); font-size: 0.82rem; }
        .brand { color: \(accent); font-weight: 700; }

        @media (max-width: 520px) {
            header h1 { font-size: 1.5rem; }
            body { padding: 10px; }
            .cal-grid { padding: 6px; gap: 2px; }
            .cal-day-num { font-size: 0.78rem; }
            .detail-day-num { font-size: 1.3rem; }
        }
        """
    }

    private static func warmCSS(accent: String) -> String {
        sharedCSS(
            bg: "linear-gradient(135deg, #F4EAE2 0%, #EAD9CC 100%)",
            cardBg: "#FCF2EE",
            headerBg: "#FCF2EE",
            text: "#3B2F2F",
            subText: "#7A6B5D",
            border: "\(accent)33",
            accent: accent,
            shadow: "rgba(0,0,0,0.08)",
            calEmptyBg: "transparent",
            calTodayRing: "\(accent)12",
            calHasShowBg: "\(accent)18",
            calPastText: "#B0A090"
        )
    }

    private static func darkCSS(accent: String) -> String {
        sharedCSS(
            bg: "#0F0F0F",
            cardBg: "#1C1C1E",
            headerBg: "#1C1C1E",
            text: "#E5E5E7",
            subText: "#8E8E93",
            border: "\(accent)44",
            accent: accent,
            shadow: "rgba(0,0,0,0.45)",
            calEmptyBg: "transparent",
            calTodayRing: "\(accent)20",
            calHasShowBg: "\(accent)25",
            calPastText: "#555"
        )
    }

    private static func neonCSS(accent: String) -> String {
        sharedCSS(
            bg: "linear-gradient(135deg, #0A0A12 0%, #0D0D20 100%)",
            cardBg: "#12121F",
            headerBg: "#12121F",
            text: "#E0E0FF",
            subText: "#9090CC",
            border: "\(accent)66",
            accent: accent,
            shadow: "\(accent)44",
            calEmptyBg: "transparent",
            calTodayRing: "\(accent)22",
            calHasShowBg: "\(accent)30",
            calPastText: "#555"
        ) + """
        .cal-section { box-shadow: 0 0 18px \(accent)33; }
        header { box-shadow: 0 0 24px \(accent)44; }
        .cal-has-show { box-shadow: 0 0 8px \(accent)44; }
        """
    }

    private static func minimalCSS(accent: String) -> String {
        sharedCSS(
            bg: "#FAFAFA",
            cardBg: "#FFFFFF",
            headerBg: "#FFFFFF",
            text: "#1C1C1E",
            subText: "#6C6C70",
            border: "#E5E5EA",
            accent: accent,
            shadow: "rgba(0,0,0,0.04)",
            calEmptyBg: "transparent",
            calTodayRing: "\(accent)10",
            calHasShowBg: "\(accent)12",
            calPastText: "#C7C7CC"
        ) + """
        .cal-section { border-radius: 12px; }
        header { border-radius: 12px; }
        """
    }

    // MARK: - Month Calendar Grid

    private static func buildMonthCalendar(
        monthStart: Date, shows: [Show],
        options: CalendarDisplayOptions,
        cal: Calendar,
        monthFormatter: DateFormatter
    ) -> String {
        let monthLabel = monthFormatter.string(from: monthStart)

        let dayNames = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        let dayHeaders = dayNames.map { "<div class=\"cal-dow\">\($0)</div>" }.joined()

        let firstWeekday = (cal.component(.weekday, from: monthStart) - 1 + 7) % 7
        let daysInMonth = (cal.range(of: .day, in: .month, for: monthStart)?.count) ?? 28
        let today = cal.startOfDay(for: Date())

        var showsByDay: [Int: [Show]] = [:]
        for show in shows {
            let comps = cal.dateComponents([.year, .month, .day], from: show.dateOrNow)
            let monthComps = cal.dateComponents([.year, .month], from: monthStart)
            if comps.year == monthComps.year && comps.month == monthComps.month {
                let d = comps.day ?? 0
                showsByDay[d, default: []].append(show)
            }
        }

        var cells = (0..<firstWeekday).map { _ in "<div class=\"cal-day cal-empty\"></div>" }

        for day in 1...daysInMonth {
            guard let dayDate = cal.date(from: DateComponents(
                year: cal.component(.year, from: monthStart),
                month: cal.component(.month, from: monthStart),
                day: day
            )) else { continue }

            let isToday = cal.isDate(dayDate, inSameDayAs: today)
            let dayShows = showsByDay[day] ?? []
            let hasShow = !dayShows.isEmpty
            let isPastDay = dayDate < today && !isToday

            var classes = "cal-day"
            if isToday    { classes += " cal-today" }
            if hasShow    { classes += " cal-has-show" }
            if isPastDay  { classes += " cal-past" }

            var dotsHTML = ""
            if hasShow {
                let dotCount = min(dayShows.count, 3)
                let dots = (0..<dotCount).map { _ in "<span class=\"cal-dot\"></span>" }.joined()
                let extra = dayShows.count > 3 ? "<span class=\"cal-dot-extra\">+\(dayShows.count - 3)</span>" : ""
                dotsHTML = "<div class=\"cal-dots\">\(dots)\(extra)</div>"
                let titles = dayShows.map { $0.titleOrEmpty }.joined(separator: ", ")
                    .replacingOccurrences(of: "\"", with: "&quot;")
                cells.append("<div class=\"\(classes)\" title=\"\(titles)\"><span class=\"cal-day-num\">\(day)</span>\(dotsHTML)</div>")
            } else {
                cells.append("<div class=\"\(classes)\"><span class=\"cal-day-num\">\(day)</span></div>")
            }
        }

        let totalCells = cells.count
        let remainder = totalCells % 7
        if remainder != 0 {
            for _ in 0..<(7 - remainder) {
                cells.append("<div class=\"cal-day cal-empty\"></div>")
            }
        }

        let totalShows = showsByDay.values.flatMap { $0 }.count
        let showWord   = totalShows == 1 ? "show" : "shows"

        return """
        <section class="cal-section">
            <div class="cal-month-header">
                <span class="cal-month-label">\(monthLabel)</span>
                <span class="cal-show-count">\(totalShows) \(showWord)</span>
            </div>
            <div class="cal-grid">
                \(dayHeaders)
                \(cells.joined(separator: "\n"))
            </div>
        </section>
        """
    }

    // MARK: - Detail List

    private static func buildDetailList(shows: [Show], options: CalendarDisplayOptions) -> String {
        shows.map { buildDetailCard(show: $0, options: options) }.joined(separator: "\n")
    }

    private static func buildDetailCard(show: Show, options: CalendarDisplayOptions) -> String {
        let isPast = show.dateOrNow < Date()

        let df = DateFormatter()
        df.dateFormat = "EEEE, MMMM d · h:mm a"
        let formattedDate = df.string(from: show.dateOrNow)

        let pastBadge = isPast ? "<span class=\"detail-chip past-chip\">Past</span>" : ""
        let urgBadge  = !isPast && !show.relativeDateLabel.isEmpty ? "<span class=\"detail-chip urgent-chip\">\(show.relativeDateLabel)</span>" : ""

        return """
        <div class="detail-card\(isPast ? " detail-past" : "")">
            <div class="detail-date-col">
                <span class="detail-day-num">\(Calendar.current.component(.day, from: show.dateOrNow))</span>
                <span class="detail-month-abbr">\(monthAbbr(from: show.dateOrNow))</span>
            </div>
            <div class="detail-body">
                <div class="detail-title">\(show.titleOrEmpty)</div>
                <div class="detail-venue">📍 \(show.venueOrEmpty)</div>
                <div class="detail-datetime">🗓 \(formattedDate)</div>
                <div class="detail-chips">\(urgBadge)\(pastBadge)</div>
            </div>
        </div>
        """
    }

    private static func monthAbbr(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date).uppercased()
    }

    // MARK: - App Icon SVG

    private static func buildAppIconSVG(accent: String) -> String {
        return """
        <svg width="72" height="72" viewBox="0 0 72 72" fill="none" xmlns="http://www.w3.org/2000/svg">
          <rect width="72" height="72" rx="16" fill="\(accent)"/>
          <rect x="29" y="13" width="14" height="25" rx="7" fill="white"/>
          <path d="M20 36 Q20 52 36 52 Q52 52 52 36" stroke="white" stroke-width="3.5" fill="none" stroke-linecap="round"/>
          <line x1="36" y1="52" x2="36" y2="59" stroke="white" stroke-width="3.5" stroke-linecap="round"/>
          <line x1="26" y1="59" x2="46" y2="59" stroke="white" stroke-width="3.5" stroke-linecap="round"/>
        </svg>
        """
    }

    // MARK: - Empty state

    private static var emptyStateHTML: String {
        """
        <div class="empty-state">
            <div class="empty-state-icon">🎭</div>
            <h2>No Shows Yet</h2>
            <p>Check back soon for new performances!</p>
        </div>
        """
    }
}

// MARK: - Calendar extension

extension Calendar {
    /// The first moment of the month containing `date`.
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
