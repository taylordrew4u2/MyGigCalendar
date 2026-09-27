//
//  ShowEditorSupportTests.swift
//  SEE ME LIVETests
//
//  Tests for the editor draft comparison, Siri handoff queue, and flyer
//  import generation token.
//

import XCTest
@testable import SEE_ME_LIVE

final class ShowEditorSupportTests: XCTestCase {

    private let baseDate = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeDraft() -> ShowDraft {
        ShowDraft(title: "Open Mic", venue: "The Store", date: baseDate,
                  addToCalendar: true, setReminder: false, flyerImageData: nil)
    }

    // MARK: - Draft Comparison

    func testUnchangedDraft_hasNoChanges() {
        XCTAssertFalse(makeDraft().hasChanges(from: makeDraft()))
    }

    func testWhitespaceOnlyEdits_areNotChanges() {
        var draft = makeDraft()
        draft.title = "  Open Mic \n"
        draft.venue = " The Store "
        XCTAssertFalse(draft.hasChanges(from: makeDraft()))
    }

    func testDateOnlyChange_isDetected() {
        var draft = makeDraft()
        draft.date = baseDate.addingTimeInterval(3600)
        XCTAssertTrue(draft.hasChanges(from: makeDraft()))
    }

    func testCalendarOnlyChange_isDetected() {
        var draft = makeDraft()
        draft.addToCalendar = false
        XCTAssertTrue(draft.hasChanges(from: makeDraft()))
    }

    func testReminderOnlyChange_isDetected() {
        var draft = makeDraft()
        draft.setReminder = true
        XCTAssertTrue(draft.hasChanges(from: makeDraft()))
    }

    func testFlyerChange_isDetected() {
        var draft = makeDraft()
        draft.flyerImageData = Data([1, 2, 3])
        XCTAssertTrue(draft.hasChanges(from: makeDraft()))
    }

    func testNewShowDefaults_areUnchangedAgainstThemselves() {
        let now = Date()
        let draft = ShowDraft.newShow(now: now)
        XCTAssertFalse(draft.hasChanges(from: ShowDraft.newShow(now: now)))
        XCTAssertTrue(draft.addToCalendar)
        XCTAssertFalse(draft.setReminder)
        XCTAssertEqual(Calendar.current.component(.hour, from: draft.date), 20)
    }

    // MARK: - Flyer Extraction Merge

    func testExtracted_fillsOnlyEmptyTitleAndVenue() {
        var draft = makeDraft()
        draft.venue = "  "
        let merged = draft.applyingExtracted(title: "Flyer Title", venue: "Flyer Venue",
                                             date: nil, dateAtImportStart: baseDate)
        XCTAssertEqual(merged.title, "Open Mic")
        XCTAssertEqual(merged.venue, "Flyer Venue")
    }

    func testExtractedDate_appliesWhenDateUnchangedDuringImport() {
        let flyerDate = baseDate.addingTimeInterval(86_400)
        let merged = makeDraft().applyingExtracted(title: nil, venue: nil,
                                                   date: flyerDate, dateAtImportStart: baseDate)
        XCTAssertEqual(merged.date, flyerDate)
    }

    func testExtractedDate_doesNotOverwriteDateChangedDuringImport() {
        var draft = makeDraft()
        let userDate = baseDate.addingTimeInterval(7200)
        draft.date = userDate
        let merged = draft.applyingExtracted(title: nil, venue: nil,
                                             date: baseDate.addingTimeInterval(86_400),
                                             dateAtImportStart: baseDate)
        XCTAssertEqual(merged.date, userDate)
    }

    // MARK: - Add Gig Handoff

    func testHandoff_noRequest_isNotTaken() {
        var queue = AddGigHandoffQueue()
        XCTAssertFalse(queue.take(canPresent: true))
    }

    func testHandoff_staysPendingWhileBusy() {
        var queue = AddGigHandoffQueue()
        queue.request()
        XCTAssertFalse(queue.take(canPresent: false))
        XCTAssertTrue(queue.isPending)
        XCTAssertTrue(queue.take(canPresent: true))
        XCTAssertFalse(queue.isPending)
    }

    func testHandoff_repeatedRequestsCoalesce() {
        var queue = AddGigHandoffQueue()
        queue.request()
        queue.request()
        XCTAssertTrue(queue.take(canPresent: true))
        XCTAssertFalse(queue.take(canPresent: true))
    }

    // MARK: - Flyer Import Generation

    func testImportToken_isCurrentUntilSuperseded() {
        var generation = FlyerImportGeneration()
        let first = generation.begin()
        XCTAssertTrue(generation.isCurrent(first))
        let second = generation.begin()
        XCTAssertFalse(generation.isCurrent(first))
        XCTAssertTrue(generation.isCurrent(second))
    }

    func testImportToken_invalidatedByRemoval() {
        var generation = FlyerImportGeneration()
        let token = generation.begin()
        generation.invalidate()
        XCTAssertFalse(generation.isCurrent(token))
    }
}
