//
//  ShowEditorPersistenceTests.swift
//  SEE ME LIVETests
//
//  Tests for the editor's isolated, throwing local-save boundary.
//

import XCTest
import CoreData
@testable import SEE_ME_LIVE

final class ShowEditorPersistenceTests: XCTestCase {

    private var controller: PersistenceController!
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        controller = PersistenceController(inMemory: true)
        context = ShowEditorPersistence.makeContext(for: controller.container)
    }

    override func tearDown() {
        context = nil
        controller = nil
        super.tearDown()
    }

    private func makeDraft(title: String = "Open Mic") -> ShowDraft {
        ShowDraft(title: title, venue: " The Store ",
                  date: Date(timeIntervalSince1970: 1_800_000_000),
                  addToCalendar: true, setReminder: true, flyerImageData: nil)
    }

    private func fetchShows() throws -> [Show] {
        let request: NSFetchRequest<Show> = Show.fetchRequest()
        return try context.performAndWait { try context.fetch(request) }
    }

    func testSaveNewShow_persistsTrimmedFieldsAndSyncFlag() throws {
        let now = Date()
        let result = try ShowEditorPersistence.save(makeDraft(title: " Open Mic "),
                                                    editing: nil, userID: "u1",
                                                    in: context, now: now)
        XCTAssertTrue(result.isNew)
        XCTAssertFalse(result.objectID.isTemporaryID)

        let shows = try fetchShows()
        XCTAssertEqual(shows.count, 1)
        context.performAndWait {
            let show = shows[0]
            XCTAssertEqual(show.title, "Open Mic")
            XCTAssertEqual(show.venue, "The Store")
            XCTAssertTrue(show.setReminder)
            XCTAssertTrue(show.needsPublicSync)
            XCTAssertEqual(show.userID, "u1")
            XCTAssertEqual(show.createdAt, now)
        }
    }

    func testSaveEdit_preservesLegacyFieldsAndCalendarID() throws {
        let first = try ShowEditorPersistence.save(makeDraft(), editing: nil,
                                                   userID: "u1", in: context)
        try context.performAndWait {
            let show = try context.existingObject(with: first.objectID) as! Show
            show.notes = "Old notes"
            show.calendarEventID = "event-1"
            try context.save()
        }

        var draft = makeDraft()
        draft.title = "Renamed"
        let second = try ShowEditorPersistence.save(draft, editing: first.objectID,
                                                    userID: "u1", in: context)
        XCTAssertFalse(second.isNew)
        XCTAssertEqual(second.calendarEventID, "event-1")

        let shows = try fetchShows()
        XCTAssertEqual(shows.count, 1)
        context.performAndWait {
            XCTAssertEqual(shows[0].title, "Renamed")
            XCTAssertEqual(shows[0].notes, "Old notes")
        }
    }

    func testSaveEmptyTitle_throwsAndPersistsNothing() throws {
        XCTAssertThrowsError(try ShowEditorPersistence.save(makeDraft(title: "  \n"),
                                                            editing: nil, userID: "u1",
                                                            in: context)) { error in
            XCTAssertEqual(error as? ShowEditorSaveError, .emptyTitle)
        }
        XCTAssertEqual(try fetchShows().count, 0)
    }

    func testSaveDeletedShow_throwsAndLeavesContextClean() throws {
        let first = try ShowEditorPersistence.save(makeDraft(), editing: nil,
                                                   userID: "u1", in: context)
        try context.performAndWait {
            let show = try context.existingObject(with: first.objectID)
            context.delete(show)
            try context.save()
        }

        XCTAssertThrowsError(try ShowEditorPersistence.save(makeDraft(), editing: first.objectID,
                                                            userID: "u1", in: context)) { error in
            XCTAssertEqual(error as? ShowEditorSaveError, .showNoLongerExists)
        }
        context.performAndWait { XCTAssertFalse(context.hasChanges) }
        XCTAssertEqual(try fetchShows().count, 0)
    }

    func testSave_doesNotDirtyViewContext() throws {
        _ = try ShowEditorPersistence.save(makeDraft(), editing: nil, userID: "u1", in: context)
        XCTAssertFalse(controller.container.viewContext.hasChanges)
    }

    func testSetCalendarEventID_storesIdentifier() throws {
        let result = try ShowEditorPersistence.save(makeDraft(), editing: nil,
                                                    userID: "u1", in: context)
        try ShowEditorPersistence.setCalendarEventID("event-2", for: result.objectID, in: context)
        let shows = try fetchShows()
        context.performAndWait { XCTAssertEqual(shows[0].calendarEventID, "event-2") }
    }

    func testSetCalendarEventID_nilClearsIdentifier() throws {
        let result = try ShowEditorPersistence.save(makeDraft(), editing: nil,
                                                    userID: "u1", in: context)
        try ShowEditorPersistence.setCalendarEventID("event-3", for: result.objectID, in: context)
        try ShowEditorPersistence.setCalendarEventID(nil, for: result.objectID, in: context)
        let shows = try fetchShows()
        context.performAndWait { XCTAssertNil(shows[0].calendarEventID) }
    }

    func testSetCalendarEventID_deletedShow_throws() throws {
        let result = try ShowEditorPersistence.save(makeDraft(), editing: nil,
                                                    userID: "u1", in: context)
        try context.performAndWait {
            let show = try context.existingObject(with: result.objectID)
            context.delete(show)
            try context.save()
        }
        XCTAssertThrowsError(try ShowEditorPersistence.setCalendarEventID("event-4",
                                                                         for: result.objectID,
                                                                         in: context))
    }
}
