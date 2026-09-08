//
//  FlyerTextExtractionServiceTests.swift
//  SEE ME LIVETests
//
//  Tests for flyer OCR parsing heuristics.
//

import XCTest
@testable import SEE_ME_LIVE

final class FlyerTextExtractionServiceTests: XCTestCase {

    func testParseShowDetails_extractsTitleVenueAndDate() throws {
        let now = try XCTUnwrap(makeDate(year: 2026, month: 9, day: 8, hour: 12))

        let details = FlyerTextExtractionService.parseShowDetails(
            from: [
                "Taylor Drew Live",
                "Friday Sep 18 8:00 PM",
                "At The Comedy Cellar",
                "Tickets at example.com"
            ],
            now: now
        )

        XCTAssertEqual(details.title, "Taylor Drew Live")
        XCTAssertEqual(details.venue, "The Comedy Cellar")

        let date = try XCTUnwrap(details.date)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: date)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.day, 18)
        XCTAssertEqual(components.hour, 20)
    }

    func testParseShowDetails_usesVenueCueWhenAvailable() {
        let details = FlyerTextExtractionService.parseShowDetails(
            from: [
                "Late Show",
                "Venue: Blue Room",
                "Doors 7 PM"
            ]
        )

        XCTAssertEqual(details.title, "Late Show")
        XCTAssertEqual(details.venue, "Blue Room")
    }

    func testParseShowDetails_doesNotUseTicketLineAsTitle() {
        let details = FlyerTextExtractionService.parseShowDetails(
            from: [
                "Tickets On Sale Now",
                "Downtown Showcase",
                "Main Street Theater"
            ]
        )

        XCTAssertEqual(details.title, "Downtown Showcase")
        XCTAssertEqual(details.venue, "Main Street Theater")
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components)
    }
}
