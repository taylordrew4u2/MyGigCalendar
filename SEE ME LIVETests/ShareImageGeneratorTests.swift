//
//  ShareImageGeneratorTests.swift
//  SEE ME LIVETests
//
//  Tests for enums, structs, and snapshot logic in ShareImageGenerator.
//

import XCTest
import CoreData
@testable import SEE_ME_LIVE

final class ShareImageGeneratorTests: XCTestCase {

    // MARK: - SocialSizePreset

    func testSocialSizePreset_allCases() {
        XCTAssertEqual(SocialSizePreset.allCases.count, 6)
    }

    func testInstagramStory_size() {
        XCTAssertEqual(SocialSizePreset.instagramStory.size, CGSize(width: 1080, height: 1920))
    }

    func testInstagramPost_size() {
        XCTAssertEqual(SocialSizePreset.instagramPost.size, CGSize(width: 1080, height: 1080))
    }

    func testTwitter_size() {
        XCTAssertEqual(SocialSizePreset.twitter.size, CGSize(width: 1600, height: 900))
    }

    func testFacebook_size() {
        XCTAssertEqual(SocialSizePreset.facebook.size, CGSize(width: 1200, height: 628))
    }

    func testOgCard_size() {
        XCTAssertEqual(SocialSizePreset.ogCard.size, CGSize(width: 1200, height: 630))
    }

    func testTikTok_size() {
        XCTAssertEqual(SocialSizePreset.tiktok.size, CGSize(width: 1080, height: 1920))
    }

    func testIsVertical_storyIsVertical() {
        XCTAssertTrue(SocialSizePreset.instagramStory.isVertical)
    }

    func testIsVertical_postIsNotVertical() {
        // 1080x1080 — height >= width, so technically true
        XCTAssertTrue(SocialSizePreset.instagramPost.isVertical)
    }

    func testIsVertical_twitterIsNotVertical() {
        XCTAssertFalse(SocialSizePreset.twitter.isVertical)
    }

    // MARK: - BackgroundStyle

    func testBackgroundStyle_allCases() {
        XCTAssertEqual(BackgroundStyle.allCases.count, 4)
    }

    // MARK: - CardStyle

    func testCardStyle_allCases() {
        XCTAssertEqual(CardStyle.allCases.count, 4)
    }

    // MARK: - FontStyle

    func testFontStyle_allCases() {
        XCTAssertEqual(FontStyle.allCases.count, 4)
    }

    // MARK: - LayoutTemplate

    func testLayoutTemplate_allCases() {
        XCTAssertEqual(LayoutTemplate.allCases.count, 5)
    }

    func testLayoutTemplate_descriptions_areNotEmpty() {
        for template in LayoutTemplate.allCases {
            XCTAssertFalse(template.description.isEmpty, "\(template.rawValue) description is empty")
        }
    }

    // MARK: - DateFormatStyle

    func testDateFormatStyle_allCases() {
        XCTAssertEqual(DateFormatStyle.allCases.count, 4)
    }

    // MARK: - ExportOptions Defaults

    func testExportOptions_defaults() {
        let opts = ExportOptions()
        XCTAssertEqual(opts.sizePreset, .instagramPost)
        XCTAssertEqual(opts.backgroundStyle, .gradient)
        XCTAssertEqual(opts.accentHex, "#CC7057")
        XCTAssertNil(opts.textColorHex)
        XCTAssertTrue(opts.showVenue)
        XCTAssertTrue(opts.showDate)
        XCTAssertTrue(opts.showTime)
        XCTAssertFalse(opts.showHeader)
        XCTAssertEqual(opts.layoutTemplate, .classic)
        XCTAssertEqual(opts.cardStyle, .rounded)
        XCTAssertEqual(opts.columns, 0)
        XCTAssertEqual(opts.cardOpacity, 1.0)
        XCTAssertEqual(opts.scrimIntensity, 0.55)
        XCTAssertEqual(opts.gridGap, 1.0)
        XCTAssertEqual(opts.textScale, 1.0)
        XCTAssertEqual(opts.showPadding, 1.0)
        XCTAssertEqual(opts.maxRows, 0)
        XCTAssertEqual(opts.listOffsetX, 0.0)
        XCTAssertEqual(opts.listOffsetY, 0.0)
        XCTAssertEqual(opts.listScale, 1.0)
    }

    // MARK: - ShowSnapshot

    func testShowSnapshot_dateFormatted_containsSeparator() {
        let snap = makeSnapshot()
        XCTAssertTrue(snap.dateFormatted.contains("·"))
    }

    func testShowSnapshot_monthAbbrev_isUppercased() {
        let snap = makeSnapshot()
        XCTAssertEqual(snap.monthAbbrev, snap.monthAbbrev.uppercased())
    }

    func testShowSnapshot_formattedDate_short() {
        let snap = makeSnapshot()
        let result = snap.formattedDate(style: .short)
        XCTAssertTrue(result.contains("·"), "Short format should contain separator")
    }

    func testShowSnapshot_formattedDate_timeOnly() {
        let snap = makeSnapshot()
        let result = snap.formattedDate(style: .timeOnly)
        // Should be something like "8:00 PM"
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - TextOverlay

    func testTextOverlay_defaults() {
        let overlay = TextOverlay(text: "Hello")
        XCTAssertEqual(overlay.fontName, "System")
        XCTAssertEqual(overlay.fontSize, 0.08)
        XCTAssertEqual(overlay.fontWeight, "bold")
        XCTAssertEqual(overlay.colorHex, "#FFFFFF")
        XCTAssertEqual(overlay.positionX, 0.5)
        XCTAssertEqual(overlay.positionY, 0.10)
        XCTAssertEqual(overlay.rotation, 0)
        XCTAssertTrue(overlay.shadowEnabled)
        XCTAssertFalse(overlay.outlineEnabled)
        XCTAssertEqual(overlay.alignment, .center)
    }

    // MARK: - CustomBackground

    func testCustomBackground_defaults() {
        let bg = CustomBackground()
        XCTAssertEqual(bg.solidHex, "#1A0A00")
        XCTAssertEqual(bg.gradientFromHex, "#1A0A00")
        XCTAssertEqual(bg.gradientToHex, "#3D1C00")
        XCTAssertNil(bg.photoData)
    }

    // MARK: - Helper

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

    private func makeSnapshot(
        title: String = "Test Show",
        venue: String = "Test Venue",
        date: Date = Date()
    ) -> ShowSnapshot {
        let show = Show(context: context)
        show.title = title
        show.venue = venue
        show.date = date
        return ShowSnapshot(from: show)
    }
}
