//
//  ShowExtensionsTests.swift
//  SEE ME LIVETests
//
//  Tests for Show+Extensions computed properties.
//

import XCTest
import CoreData
@testable import SEE_ME_LIVE

final class ShowExtensionsTests: XCTestCase {

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

    // MARK: - Helper

    private func makeShow(
        title: String? = nil, venue: String? = nil, date: Date? = nil
    ) -> Show {
        let show = Show(context: context)
        show.title = title
        show.venue = venue
        show.date = date
        return show
    }

    // MARK: - Safe Accessors

    func testTitleOrEmpty_whenNil_returnsEmpty() {
        let show = makeShow()
        XCTAssertEqual(show.titleOrEmpty, "")
    }

    func testTitleOrEmpty_whenSet_returnsValue() {
        let show = makeShow(title: "Comedy Night")
        XCTAssertEqual(show.titleOrEmpty, "Comedy Night")
    }

    func testVenueOrEmpty_whenNil_returnsEmpty() {
        let show = makeShow()
        XCTAssertEqual(show.venueOrEmpty, "")
    }

    func testDateOrNow_whenNil_returnsCurrentDate() {
        let show = makeShow()
        let now = Date()
        XCTAssertEqual(show.dateOrNow.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1.0)
    }

    func testDateOrNow_whenSet_returnsSetDate() {
        let d = Date(timeIntervalSince1970: 1_000_000)
        let show = makeShow(date: d)
        XCTAssertEqual(show.dateOrNow, d)
    }

    // MARK: - Relative Date Label

    func testRelativeDateLabel_today() {
        let show = makeShow(date: Date())
        XCTAssertEqual(show.relativeDateLabel, "Today")
    }

    func testRelativeDateLabel_tomorrow() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let show = makeShow(date: tomorrow)
        XCTAssertEqual(show.relativeDateLabel, "Tomorrow")
    }

    func testRelativeDateLabel_in3Days() {
        // Use noon today as anchor to avoid edge cases near midnight
        let cal = Calendar.current
        let noonToday = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let future = cal.date(byAdding: .day, value: 3, to: noonToday)!
        let show = makeShow(date: future)
        let label = show.relativeDateLabel
        // Should be "In 2 days" or "In 3 days" depending on current time
        XCTAssertTrue(label.hasPrefix("In ") && label.hasSuffix(" days"),
                      "Expected 'In N days' format, got '\(label)'")
    }

    func testRelativeDateLabel_moreThan7Days_returnsEmpty() {
        let future = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let show = makeShow(date: future)
        XCTAssertEqual(show.relativeDateLabel, "")
    }

    func testRelativeDateLabel_pastDate_returnsEmpty() {
        let past = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let show = makeShow(date: past)
        XCTAssertEqual(show.relativeDateLabel, "")
    }

    // MARK: - Date Formatting

    func testDateFormatted_containsDotSeparator() {
        let show = makeShow(date: Date())
        XCTAssertTrue(show.dateFormatted.contains("·"), "Expected date format like 'EEE, MMM d · h:mm a'")
    }
}
