//
//  HTMLExportServiceTests.swift
//  SEE ME LIVETests
//
//  Tests for HTMLExportService and CalendarDisplayOptions.
//

import XCTest
import CoreData
@testable import SEE_ME_LIVE

final class HTMLExportServiceTests: XCTestCase {

    var container: NSPersistentContainer!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        container = NSPersistentCloudKitContainer(name: "SEE_ME_LIVE")
        let desc = NSPersistentStoreDescription()
        desc.url = URL(fileURLWithPath: "/dev/null")
        desc.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [desc]

        let expectation = expectation(description: "Store loaded")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        context = container.viewContext
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // MARK: - CalendarDisplayOptions

    func testCalendarDisplayOptions_defaults() {
        let opts = CalendarDisplayOptions()
        XCTAssertEqual(opts.theme, .warm)
        XCTAssertEqual(opts.layout, .list)
        XCTAssertFalse(opts.showPastShows)
        XCTAssertEqual(opts.accentHex, "#9A6544")
        XCTAssertEqual(opts.performerName, "")
    }

    func testCalendarDisplayOptions_themes_allCases() {
        XCTAssertEqual(CalendarDisplayOptions.Theme.allCases.count, 4)
    }

    func testCalendarDisplayOptions_codable() throws {
        var opts = CalendarDisplayOptions()
        opts.theme = .dark
        opts.performerName = "Test Performer"
        opts.showPastShows = true

        let data = try JSONEncoder().encode(opts)
        let decoded = try JSONDecoder().decode(CalendarDisplayOptions.self, from: data)

        XCTAssertEqual(decoded.theme, .dark)
        XCTAssertEqual(decoded.performerName, "Test Performer")
        XCTAssertTrue(decoded.showPastShows)
    }

    // MARK: - HTML Generation

    func testGenerateHTML_emptyShows_containsEmptyState() {
        let html = HTMLExportService.generateHTML(shows: [], performerName: "")
        XCTAssertTrue(html.contains("No Shows Yet"))
        XCTAssertTrue(html.contains("My Gig Calendar"))
    }

    func testGenerateHTML_withShows_containsShowTitle() {
        let show = Show(context: context)
        show.title = "Comedy Night Special"
        show.venue = "Laugh Factory"
        show.date = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        let html = HTMLExportService.generateHTML(shows: [show], performerName: "")
        XCTAssertTrue(html.contains("Comedy Night Special"))
        XCTAssertTrue(html.contains("Laugh Factory"))
    }

    func testGenerateHTML_withPerformerName_showsInTitle() {
        let html = HTMLExportService.generateHTML(shows: [], performerName: "Taylor")
        XCTAssertTrue(html.contains("Taylor's Shows"))
    }

    func testGenerateHTML_emptyPerformerName_showsDefault() {
        let html = HTMLExportService.generateHTML(shows: [], performerName: "")
        XCTAssertTrue(html.contains("Performance Calendar"))
    }

    func testGenerateHTML_performerNameMy_showsDefault() {
        let html = HTMLExportService.generateHTML(shows: [], performerName: "My")
        XCTAssertTrue(html.contains("Performance Calendar"))
    }

    func testGenerateHTML_isValidHTML() {
        let html = HTMLExportService.generateHTML(shows: [], performerName: "")
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("<html"))
        XCTAssertTrue(html.contains("</html>"))
        XCTAssertTrue(html.contains("<head>"))
        XCTAssertTrue(html.contains("<body>"))
    }

    func testGenerateHTML_darkTheme() {
        var opts = CalendarDisplayOptions()
        opts.theme = .dark
        let html = HTMLExportService.generateHTML(shows: [], options: opts)
        XCTAssertTrue(html.contains("#0F0F0F"), "Dark theme should use dark background")
    }

    func testGenerateHTML_neonTheme() {
        var opts = CalendarDisplayOptions()
        opts.theme = .neon
        let html = HTMLExportService.generateHTML(shows: [], options: opts)
        XCTAssertTrue(html.contains("#0A0A12"), "Neon theme should use dark purple background")
    }

    func testGenerateHTML_minimalTheme() {
        var opts = CalendarDisplayOptions()
        opts.theme = .minimal
        let html = HTMLExportService.generateHTML(shows: [], options: opts)
        XCTAssertTrue(html.contains("#FAFAFA"), "Minimal theme should use light background")
    }

    // MARK: - Hidden Legacy Fields

    func testGenerateHTML_withTicketLink_hidesTicketButton() {
        let show = Show(context: context)
        show.title = "Show"
        show.venue = "Venue"
        show.date = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        show.ticketLink = "https://tickets.example.com"

        let html = HTMLExportService.generateHTML(shows: [show], performerName: "")
        XCTAssertFalse(html.contains("Get Tickets"))
        XCTAssertFalse(html.contains("https://tickets.example.com"))
    }

    func testGenerateHTML_withPrice_hidesPrice() {
        let show = Show(context: context)
        show.title = "Paid Show"
        show.venue = "Club"
        show.date = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        show.price = 20.0

        let html = HTMLExportService.generateHTML(shows: [show], performerName: "")
        XCTAssertFalse(html.contains("$20.00"))
    }

    // MARK: - Past Shows Filter

    func testGenerateHTML_pastShows_hiddenByDefault() {
        let show = Show(context: context)
        show.title = "Old Show"
        show.venue = "Old Venue"
        show.date = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

        var opts = CalendarDisplayOptions()
        opts.showPastShows = false
        let html = HTMLExportService.generateHTML(shows: [show], options: opts)
        XCTAssertFalse(html.contains("Old Show"), "Past shows should be hidden by default")
    }

    func testGenerateHTML_pastShows_shownWhenEnabled() {
        let show = Show(context: context)
        show.title = "Old Show Visible"
        show.venue = "Old Venue"
        show.date = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

        var opts = CalendarDisplayOptions()
        opts.showPastShows = true
        let html = HTMLExportService.generateHTML(shows: [show], options: opts)
        XCTAssertTrue(html.contains("Old Show Visible"))
    }

    // MARK: - Save HTML to File

    func testSaveHTMLToFile_createsFile() {
        let html = "<html><body>Test</body></html>"
        let url = HTMLExportService.saveHTMLToFile(html: html)
        XCTAssertNotNil(url)

        if let url = url {
            let content = try? String(contentsOf: url, encoding: .utf8)
            XCTAssertEqual(content, html)
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Calendar.startOfMonth

    func testStartOfMonth_returnsFirstDay() {
        let cal = Calendar.current
        let date = cal.date(from: DateComponents(year: 2026, month: 4, day: 15))!
        let start = cal.startOfMonth(for: date)
        let comps = cal.dateComponents([.year, .month, .day], from: start)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 4)
        XCTAssertEqual(comps.day, 1)
    }
}
