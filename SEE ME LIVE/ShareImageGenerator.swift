//
//  ShareImageGenerator.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/3/26.
//

import UIKit

// MARK: - Social Size Preset

enum SocialSizePreset: String, CaseIterable, Identifiable, Codable {
    case instagramStory = "IG Story"
    case instagramPost  = "IG Post"
    case tiktok         = "TikTok"
    case twitter        = "X / Twitter"
    case facebook       = "Facebook"
    case ogCard         = "Link Preview"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .instagramStory: return "IG Story (9:16)"
        case .instagramPost:  return "IG Post (1:1)"
        case .tiktok:         return "TikTok (9:16)"
        case .twitter:        return "X / Twitter (16:9)"
        case .facebook:       return "Facebook (1.91:1)"
        case .ogCard:         return "Link Preview (1.91:1)"
        }
    }

    var size: CGSize {
        switch self {
        case .instagramStory, .tiktok: return CGSize(width: 1080, height: 1920)
        case .instagramPost:           return CGSize(width: 1080, height: 1080)
        case .twitter:                 return CGSize(width: 1600, height: 900)
        case .facebook:                return CGSize(width: 1200, height: 628)
        case .ogCard:                  return CGSize(width: 1200, height: 630)
        }
    }

    var icon: String {
        switch self {
        case .instagramStory, .instagramPost: return "camera.fill"
        case .tiktok:                         return "music.note"
        case .twitter:                        return "message.fill"
        case .facebook:                       return "person.2.fill"
        case .ogCard:                         return "link"
        }
    }

    var isVertical: Bool { size.height >= size.width }
}

// MARK: - Background Style

enum BackgroundStyle: String, CaseIterable, Identifiable, Codable {
    case gradient = "Gradient"
    case dark     = "Dark"
    case light    = "Light"
    case custom   = "Custom"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .gradient: return "paintpalette.fill"
        case .dark:     return "moon.fill"
        case .light:    return "sun.max.fill"
        case .custom:   return "wand.and.stars"
        }
    }
}

// MARK: - Custom Background Descriptor

struct CustomBackground: Codable {
    enum Kind: Codable { case solidColor, gradient, photo }
    var kind: Kind = .solidColor
    var solidHex: String = "#1A0A00"
    var gradientFromHex: String = "#1A0A00"
    var gradientToHex: String = "#3D1C00"
    var photoData: Data? = nil
}

// MARK: - Text Overlay Descriptor

struct TextOverlay: Identifiable, Codable {
    let id: UUID
    var text: String
    var fontName: String = "System"
    var fontSize: CGFloat = 0.08
    var fontWeight: String = "bold"
    var colorHex: String = "#FFFFFF"
    var positionX: CGFloat = 0.5
    var positionY: CGFloat = 0.10
    var rotation: Double = 0
    var shadowEnabled: Bool = true
    var shadowOpacity: Double = 0.5
    var outlineEnabled: Bool = false
    var outlineColorHex: String = "#000000"
    var alignment: TextAlignment = .center
    
    init(
        id: UUID = UUID(),
        text: String,
        fontName: String = "System",
        fontSize: CGFloat = 0.08,
        fontWeight: String = "bold",
        colorHex: String = "#FFFFFF",
        positionX: CGFloat = 0.5,
        positionY: CGFloat = 0.10,
        rotation: Double = 0,
        shadowEnabled: Bool = true,
        shadowOpacity: Double = 0.5,
        outlineEnabled: Bool = false,
        outlineColorHex: String = "#000000",
        alignment: TextAlignment = .center
    ) {
        self.id = id
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.colorHex = colorHex
        self.positionX = positionX
        self.positionY = positionY
        self.rotation = rotation
        self.shadowEnabled = shadowEnabled
        self.shadowOpacity = shadowOpacity
        self.outlineEnabled = outlineEnabled
        self.outlineColorHex = outlineColorHex
        self.alignment = alignment
    }

    enum TextAlignment: String, CaseIterable, Codable {
        case left = "Left"
        case center = "Center"
        case right = "Right"
    }
}

// MARK: - Card Style

enum CardStyle: String, CaseIterable, Identifiable, Codable {
    case rounded  = "Rounded"
    case sharp    = "Sharp"
    case minimal  = "Minimal"
    case outlined = "Outlined"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .rounded:  return "rectangle.roundedtop"
        case .sharp:    return "rectangle"
        case .minimal:  return "rectangle.dashed"
        case .outlined: return "rectangle.inset.filled"
        }
    }
}

// MARK: - Header Style

enum HeaderStyle: String, CaseIterable, Identifiable, Codable {
    case left     = "Left"
    case centered = "Centered"
    case minimal  = "Minimal"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .left:     return "text.alignleft"
        case .centered: return "text.aligncenter"
        case .minimal:  return "minus"
        }
    }
}

// MARK: - Font Style

enum FontStyle: String, CaseIterable, Identifiable, Codable {
    case system  = "Default"
    case rounded = "Rounded"
    case serif   = "Serif"
    case mono    = "Mono"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .system:  return "textformat"
        case .rounded: return "textformat.abc"
        case .serif:   return "textformat.alt"
        case .mono:    return "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - Date Format Style

enum DateFormatStyle: String, CaseIterable, Identifiable, Codable {
    case short    = "Short"      // Mar 15 · 8 PM
    case full     = "Full"       // Saturday, March 15
    case relative = "Relative"   // In 3 days
    case timeOnly = "Time Only"  // 8:00 PM
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .short:    return "calendar"
        case .full:     return "calendar.day.timeline.left"
        case .relative: return "clock.arrow.circlepath"
        case .timeOnly: return "clock"
        }
    }
}

// MARK: - Layout Template

enum LayoutTemplate: String, CaseIterable, Identifiable, Codable {
    case classic    = "Classic"      // Date badge left, text right
    case minimal    = "Minimal"      // Simple text list, no badges
    case bold       = "Bold"         // Large date on top, text below
    case compact    = "Compact"      // Small cards, more shows visible
    case stacked    = "Stacked"      // One-line per show, all details inline
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .classic: return "rectangle.split.2x1"
        case .minimal: return "list.bullet"
        case .bold:    return "calendar"
        case .compact: return "square.grid.3x3"
        case .stacked: return "line.3.horizontal"
        }
    }
    
    var description: String {
        switch self {
        case .classic: return "Date badge with show details"
        case .minimal: return "Clean text-only layout"
        case .bold:    return "Large prominent dates"
        case .compact: return "Fit more shows"
        case .stacked: return "All details on one line"
        }
    }
}

// MARK: - Export Options

struct ExportOptions: Codable {
    var sizePreset:      SocialSizePreset = .instagramPost
    var backgroundStyle: BackgroundStyle  = .gradient
    var accentHex:       String           = "#CC7057"
    var textColorHex:    String?          = nil       // nil = auto (white/dark based on background)
    
    // Content toggles
    var showVenue:       Bool             = true
    var showDate:        Bool             = true
    var showTime:        Bool             = true
    var showHeader:      Bool             = false     // No header by default
    
    // Layout
    var layoutTemplate:  LayoutTemplate   = .classic
    var cardStyle:       CardStyle        = .rounded
    var columns:         Int              = 0        // 0 = auto
    var cardOpacity:     Double           = 1.0      // 0…1
    var headerStyle:     HeaderStyle      = .left
    var fontStyle:       FontStyle        = .system

    // Customizable text
    var subtitleText:    String           = ""

    // Scrim (background overlay darkness)
    var scrimIntensity:  Double           = 0.55     // 0…1

    // Grid gap multiplier
    var gridGap:         Double           = 1.0      // 0.5…2.0

    // Text scale multiplier
    var textScale:       Double           = 1.0      // 0.7…1.5

    // Padding inside cards
    var showPadding:     Double           = 1.0      // 0.5…2.0

    // Max rows (0 = show all)
    var maxRows:         Int              = 0

    // Show list position & scale (drag/resize on canvas)
    var listOffsetX:     Double           = 0.0      // -0.5…0.5 (fraction of canvas width)
    var listOffsetY:     Double           = 0.0      // -0.5…0.5 (fraction of canvas height)
    var listScale:       Double           = 1.0      // 0.3…2.0

    var customBackground: CustomBackground = CustomBackground()
    var textOverlays: [TextOverlay] = []
}

// MARK: - Show Snapshot (thread-safe)

struct ShowSnapshot: Sendable {
    let title: String
    let venue: String
    let date: Date

    var titleOrEmpty: String   { title }
    var venueOrEmpty: String   { venue }
    var dateOrNow: Date        { date }

    var dateFormatted: String {
        "\(Self.dayFormatter.string(from: date)) · \(Self.timeFormatter.string(from: date))"
    }

    var monthAbbrev: String {
        Self.monthAbbrevFormatter.string(from: date).uppercased()
    }

    var dayNumber: String {
        Self.dayNumFormatter.string(from: date)
    }

    var timeString: String {
        Self.timeFormatter.string(from: date)
    }

    func formattedDate(style: DateFormatStyle) -> String {
        switch style {
        case .short:
            return "\(Self.shortDateFormatter.string(from: date)) · \(Self.timeFormatter.string(from: date))"
        case .full:
            return "\(Self.fullDateFormatter.string(from: date)) · \(Self.timeFormatter.string(from: date))"
        case .relative:
            return "\(Self.shortDateFormatter.string(from: date)) · \(Self.timeFormatter.string(from: date))"
        case .timeOnly:
            return Self.timeFormatter.string(from: date)
        }
    }

    // MARK: - Shared Formatters
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()
    private static let monthAbbrevFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f
    }()
    private static let dayNumFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"; return f
    }()

    init(from show: Show) {
        self.title = show.title ?? ""
        self.venue = show.venue ?? ""
        self.date = show.date ?? Date()
    }
}

// MARK: - Share Image Generator

enum ShareImageGenerator {
    private static let appWatermarkText = "Created with My Gig Calendar"

    enum WatermarkStyle {
        case subtlePreview
        case export
    }

    /// Generate from Core Data Show objects (snapshots them on the calling thread).
    static func generate(shows: [Show], performerName: String, options: ExportOptions,
                         showsWatermark: Bool = true, watermarkStyle: WatermarkStyle = .export) -> UIImage {
        let snapshots = shows.map { ShowSnapshot(from: $0) }
        return generate(snapshots: snapshots, performerName: performerName, options: options,
                        showsWatermark: showsWatermark, watermarkStyle: watermarkStyle)
    }

    /// Generate from thread-safe ShowSnapshot values. Safe to call from any thread.
    static func generate(snapshots: [ShowSnapshot], performerName: String, options: ExportOptions,
                         showsWatermark: Bool = true, watermarkStyle: WatermarkStyle = .export) -> UIImage {
        let size = options.sizePreset.size
        return render(snapshots: snapshots, performerName: performerName, options: options, size: size,
                      showsWatermark: showsWatermark, watermarkStyle: watermarkStyle)
    }

    /// Generate a lower-memory preview while preserving the selected export aspect ratio.
    static func generatePreview(snapshots: [ShowSnapshot], performerName: String, options: ExportOptions,
                                maxPixelDimension: CGFloat = 720, showsWatermark: Bool = true,
                                watermarkStyle: WatermarkStyle = .subtlePreview) -> UIImage {
        let exportSize = options.sizePreset.size
        let largestSide = max(exportSize.width, exportSize.height)
        let scale = min(1, maxPixelDimension / largestSide)
        let previewSize = CGSize(width: max(1, exportSize.width * scale),
                                 height: max(1, exportSize.height * scale))
        return render(snapshots: snapshots, performerName: performerName, options: options, size: previewSize,
                      showsWatermark: showsWatermark, watermarkStyle: watermarkStyle)
    }

    private static func render(snapshots: [ShowSnapshot], performerName: String, options: ExportOptions,
                               size: CGSize, showsWatermark: Bool, watermarkStyle: WatermarkStyle) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return autoreleasepool {
            renderer.image { ctx in
                drawCanvas(in: ctx.cgContext, size: size, snapshots: snapshots,
                           performerName: performerName, options: options)
                if showsWatermark {
                    drawWatermark(in: ctx.cgContext, size: size, options: options, style: watermarkStyle)
                }
            }
        }
    }

    // MARK: - Font Resolver

    private static func resolvedFont(size: CGFloat, weight: UIFont.Weight, style: FontStyle) -> UIFont {
        switch style {
        case .system:
            return UIFont.systemFont(ofSize: size, weight: weight)
        case .rounded:
            let desc = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
                .withDesign(.rounded) ?? UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
            return UIFont(descriptor: desc, size: size)
        case .serif:
            let desc = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
                .withDesign(.serif) ?? UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
            return UIFont(descriptor: desc, size: size)
        case .mono:
            let desc = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
                .withDesign(.monospaced) ?? UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
            return UIFont(descriptor: desc, size: size)
        }
    }

    // MARK: - Main Canvas

    private static func drawCanvas(in ctx: CGContext, size: CGSize, snapshots: [ShowSnapshot],
                                    performerName: String, options: ExportOptions) {
        let rect = CGRect(origin: .zero, size: size)
        let allShows = snapshots.sorted { $0.dateOrNow < $1.dateOrNow }
        let featured = allShows.first
        let accent = UIColor(hex: options.accentHex)
        let isLight = options.backgroundStyle == .light

        // 1. Background
        drawBackground(ctx: ctx, rect: rect, featured: featured,
                       style: options.backgroundStyle, customBG: options.customBackground)

        // 2. Scrim overlay for readability
        let scrimAlpha: CGFloat = isLight ? options.scrimIntensity * 0.1 : options.scrimIntensity
        ctx.setFillColor(UIColor.black.withAlphaComponent(scrimAlpha).cgColor)
        ctx.fill(rect)

        // 3. Colors
        let textColor: UIColor
        if let customHex = options.textColorHex {
            textColor = UIColor(hex: customHex)
        } else {
            textColor = isLight ? UIColor(hex: "#1A1A1A") : .white
        }
        let subColor: UIColor = textColor.withAlphaComponent(0.65)

        // Card background with user opacity
        let baseCardAlpha: CGFloat = isLight ? 0.85 : 0.08
        let cardBG: UIColor
        let cardBorder: UIColor
        switch options.cardStyle {
        case .rounded, .sharp:
            cardBG = isLight
                ? UIColor.white.withAlphaComponent(baseCardAlpha * options.cardOpacity)
                : UIColor.white.withAlphaComponent(baseCardAlpha * options.cardOpacity)
            cardBorder = isLight
                ? UIColor.black.withAlphaComponent(0.06 * options.cardOpacity)
                : UIColor.white.withAlphaComponent(0.12 * options.cardOpacity)
        case .minimal:
            cardBG = UIColor.clear
            cardBorder = UIColor.clear
        case .outlined:
            cardBG = UIColor.clear
            cardBorder = isLight
                ? UIColor.black.withAlphaComponent(0.15)
                : UIColor.white.withAlphaComponent(0.25)
        }

        // 4. Layout metrics
        let pad = size.width * 0.05
        let headerH: CGFloat = options.showHeader ? (options.headerStyle == .minimal ? size.width * 0.10 : size.width * 0.14) : 0
        let baseGridTop = pad + headerH
        let baseGridBottom = size.height - pad * 0.5
        let baseGridH = baseGridBottom - baseGridTop
        let baseGridW = size.width - pad * 2

        // Apply user offset & scale
        let scale = CGFloat(options.listScale)
        let gridW = baseGridW * scale
        let gridH = baseGridH * scale
        let gridCenterX = pad + baseGridW * 0.5 + CGFloat(options.listOffsetX) * size.width
        let gridCenterY = baseGridTop + baseGridH * 0.5 + CGFloat(options.listOffsetY) * size.height
        let gridOriginX = gridCenterX - gridW * 0.5
        let gridOriginY = gridCenterY - gridH * 0.5

        // 5. Header (only if enabled)
        if options.showHeader {
            drawHeader(ctx: ctx, size: size, pad: pad, performerName: performerName,
                       options: options, accent: accent, textColor: textColor, subColor: subColor)
        }

        // 6. Stacked layout gets its own path (single-column, one-line rows)
        if options.layoutTemplate == .stacked {
            drawStackedList(ctx: ctx, allShows: allShows, options: options,
                            gridOrigin: CGPoint(x: gridOriginX, y: gridOriginY),
                            gridSize: CGSize(width: gridW, height: gridH),
                            accent: accent, textColor: textColor, subColor: subColor, isLight: isLight)
        } else {
            // 6b. Card grid — user-defined or auto columns
            let cols: Int
            if options.columns > 0 {
                cols = options.columns
            } else {
                cols = options.sizePreset.isVertical ? 2 : 3
            }
            drawCardGrid(ctx: ctx, allShows: allShows, options: options,
                         gridOrigin: CGPoint(x: gridOriginX, y: gridOriginY),
                         gridSize: CGSize(width: gridW, height: gridH),
                         cols: cols, accent: accent, textColor: textColor,
                         subColor: subColor, cardBG: cardBG, cardBorder: cardBorder, isLight: isLight)
        }

        // 7. Custom text overlays (if any)
        if !options.textOverlays.isEmpty {
            drawTextOverlays(options.textOverlays, in: size, ctx: ctx)
        }
    }

    // MARK: - Header

    private static func drawHeader(ctx: CGContext, size: CGSize, pad: CGFloat,
                                    performerName: String, options: ExportOptions,
                                    accent: UIColor, textColor: UIColor, subColor: UIColor) {
        let topY = pad
        let rawName = performerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (rawName.isEmpty || rawName == "My" || rawName == "My Shows") ? "Shows" : rawName
        let fontSt = options.fontStyle

        switch options.headerStyle {
        case .left:
            // Performer name — large, left-aligned
            let nameSz = size.width * 0.065
            let nameFont = resolvedFont(size: nameSz, weight: .bold, style: fontSt)
            drawText(name, at: CGPoint(x: pad, y: topY), font: nameFont,
                     color: textColor, maxWidth: size.width * 0.8, canvasHeight: size.height)

            // Subtitle line
            let subY = topY + nameSz * 1.35
            let subSz = size.width * 0.026
            let subFont = resolvedFont(size: subSz, weight: .medium, style: fontSt)
            if !options.subtitleText.isEmpty {
                drawText(options.subtitleText, at: CGPoint(x: pad, y: subY), font: subFont,
                         color: subColor, maxWidth: size.width * 0.5, canvasHeight: size.height)
            }

        case .centered:
            let nameSz = size.width * 0.07
            let nameFont = resolvedFont(size: nameSz, weight: .bold, style: fontSt)
            let nameAttrs: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: textColor]
            let nameSize = (name as NSString).size(withAttributes: nameAttrs)
            let nx = (size.width - nameSize.width) / 2
            UIGraphicsPushContext(ctx)
            (name as NSString).draw(at: CGPoint(x: nx, y: topY), withAttributes: nameAttrs)
            UIGraphicsPopContext()

            let subY = topY + nameSize.height + size.width * 0.01
            let subSz = size.width * 0.024
            let subFont = resolvedFont(size: subSz, weight: .medium, style: fontSt)
            let subAttrs: [NSAttributedString.Key: Any] = [.font: subFont, .foregroundColor: subColor]
            let subText = options.subtitleText as NSString
            let subSize = subText.size(withAttributes: subAttrs)
            let sx = (size.width - subSize.width) / 2
            UIGraphicsPushContext(ctx)
            subText.draw(at: CGPoint(x: sx, y: subY), withAttributes: subAttrs)
            UIGraphicsPopContext()

        case .minimal:
            // Just the performer name, small, left-aligned
            let nameSz = size.width * 0.04
            let nameFont = resolvedFont(size: nameSz, weight: .semibold, style: fontSt)
            drawText(name, at: CGPoint(x: pad, y: topY), font: nameFont,
                     color: textColor, maxWidth: size.width * 0.5, canvasHeight: size.height)
        }
    }

    // MARK: - Card Grid

    private static func drawCardGrid(ctx: CGContext, allShows: [ShowSnapshot],
                                      options: ExportOptions,
                                      gridOrigin: CGPoint, gridSize: CGSize,
                                      cols: Int, accent: UIColor, textColor: UIColor,
                                      subColor: UIColor, cardBG: UIColor,
                                      cardBorder: UIColor, isLight: Bool) {

        guard !allShows.isEmpty else {
            let emptyFont = UIFont.systemFont(ofSize: gridSize.width * 0.04, weight: .medium)
            drawText("No shows scheduled yet",
                     at: CGPoint(x: gridOrigin.x, y: gridOrigin.y + gridSize.height * 0.4),
                     font: emptyFont, color: subColor,
                     maxWidth: gridSize.width, canvasHeight: gridOrigin.y + gridSize.height)
            return
        }

        let fontSt  = options.fontStyle
        let template = options.layoutTemplate
        let shows   = options.maxRows > 0 ? Array(allShows.prefix(options.maxRows * cols)) : allShows
        let count   = shows.count
        
        // Adjust columns for compact template
        let safeCols: Int
        switch template {
        case .compact:
            safeCols = max(1, cols + 1)  // More columns for compact
        default:
            safeCols = max(1, cols)
        }

        // Gap between cards
        let gapMultiplier: CGFloat = template == .compact ? 0.5 : 1.0
        let gap = gridSize.width * 0.025 * options.gridGap * gapMultiplier

        // Card width from column count
        let cardW = (gridSize.width - gap * CGFloat(safeCols - 1)) / CGFloat(safeCols)

        // Determine row count and card height
        let rows = Int(ceil(Double(count) / Double(safeCols)))
        let rowGap = gap
        let cardH: CGFloat
        if rows > 0 {
            let totalRowGaps = rowGap * CGFloat(max(rows - 1, 0))
            cardH = max(1, (gridSize.height - totalRowGaps) / CGFloat(rows))
        } else {
            cardH = gridSize.height
        }

        // Fonts scaled to card size - adjust for template
        let ts = options.textScale
        let compactScale: CGFloat = template == .compact ? 0.85 : 1.0
        let innerPad  = cardW * 0.07 * options.showPadding
        let titleSz   = max(10, cardH * 0.22 * ts * compactScale)
        let detailSz  = max(8,  cardH * 0.15 * ts * compactScale)
        let dateSz    = max(8,  cardH * 0.13 * ts * compactScale)
        let monthSz   = max(7,  cardH * 0.11 * ts * compactScale)

        for (i, show) in shows.enumerated() {
            let col = i % safeCols
            let row = i / safeCols

            let cardX = gridOrigin.x + CGFloat(col) * (cardW + gap)
            let cardY = gridOrigin.y + CGFloat(row)  * (cardH + rowGap)
            let cardRect = CGRect(x: cardX, y: cardY, width: cardW, height: cardH)

            switch template {
            case .classic:
                // Date badge left, text right
                drawClassicCard(ctx: ctx, show: show, cardRect: cardRect, innerPad: innerPad,
                               titleSz: titleSz, detailSz: detailSz, dateSz: dateSz, monthSz: monthSz,
                               fontSt: fontSt, accent: accent, textColor: textColor, subColor: subColor, options: options)
                
            case .minimal:
                // Simple text list, no date badge
                drawMinimalCard(ctx: ctx, show: show, cardRect: cardRect, innerPad: innerPad,
                               titleSz: titleSz, detailSz: detailSz,
                               fontSt: fontSt, textColor: textColor, subColor: subColor, options: options)
                
            case .bold:
                // Large date on top, text below
                drawBoldCard(ctx: ctx, show: show, cardRect: cardRect, innerPad: innerPad,
                            titleSz: titleSz, detailSz: detailSz, dateSz: dateSz, monthSz: monthSz,
                            fontSt: fontSt, accent: accent, textColor: textColor, subColor: subColor, options: options)
                
            case .compact:
                // Small cards, tight layout
                drawCompactCard(ctx: ctx, show: show, cardRect: cardRect, innerPad: innerPad,
                               titleSz: titleSz, detailSz: detailSz, monthSz: monthSz,
                               fontSt: fontSt, accent: accent, textColor: textColor, subColor: subColor, options: options)
            case .stacked:
                // Handled separately via drawStackedList; fallback to minimal
                drawMinimalCard(ctx: ctx, show: show, cardRect: cardRect, innerPad: innerPad,
                               titleSz: titleSz, detailSz: detailSz,
                               fontSt: fontSt, textColor: textColor, subColor: subColor, options: options)
            }
        }
    }

    // MARK: - Card Templates

    /// Classic: Date badge on left, show details on right
    private static func drawClassicCard(ctx: CGContext, show: ShowSnapshot, cardRect: CGRect,
                                         innerPad: CGFloat, titleSz: CGFloat, detailSz: CGFloat,
                                         dateSz: CGFloat, monthSz: CGFloat, fontSt: FontStyle,
                                         accent: UIColor, textColor: UIColor, subColor: UIColor,
                                         options: ExportOptions) {
        let cardX = cardRect.minX
        let cardY = cardRect.minY
        let cardW = cardRect.width
        let cardH = cardRect.height
        
        // Date badge (left strip)
        let badgeW = cardW * 0.22
        let badgeX = cardX + innerPad * 0.5
        let badgeY = cardY + cardH * 0.15

        if options.showDate {
            // Month
            let monthFont = resolvedFont(size: monthSz, weight: .bold, style: fontSt)
            let monthAttrs: [NSAttributedString.Key: Any] = [.font: monthFont, .foregroundColor: accent]
            let monthStr = show.monthAbbrev as NSString
            let monthSize = monthStr.size(withAttributes: monthAttrs)
            UIGraphicsPushContext(ctx)
            monthStr.draw(at: CGPoint(x: badgeX + (badgeW - monthSize.width) / 2, y: badgeY), withAttributes: monthAttrs)
            UIGraphicsPopContext()

            // Day number
            let dayFont = resolvedFont(size: dateSz * 1.5, weight: .heavy, style: fontSt)
            let dayAttrs: [NSAttributedString.Key: Any] = [.font: dayFont, .foregroundColor: textColor]
            let dayStr = show.dayNumber as NSString
            let daySize = dayStr.size(withAttributes: dayAttrs)
            UIGraphicsPushContext(ctx)
            dayStr.draw(at: CGPoint(x: badgeX + (badgeW - daySize.width) / 2, y: badgeY + monthSize.height + 1), withAttributes: dayAttrs)
            UIGraphicsPopContext()
        }

        // Text content (right of date badge)
        let textX = options.showDate ? cardX + badgeW + innerPad : cardX + innerPad
        let textW = options.showDate ? max(1, cardW - badgeW - innerPad * 1.5) : max(1, cardW - innerPad * 2)
        
        // Calculate available height for text content
        let textStartY = cardY + innerPad * 0.5
        let textAvailableH = cardH - innerPad
        
        // Count how many elements we need to show
        var elementCount = 1 // Title always shown
        if options.showVenue && !show.venueOrEmpty.isEmpty { elementCount += 1 }
        if options.showTime { elementCount += 1 }
        
        // Distribute space - title gets more space
        let titleRatio: CGFloat = 0.45
        let detailRatio: CGFloat = (1.0 - titleRatio) / CGFloat(max(1, elementCount - 1))
        
        let titleMaxH = textAvailableH * titleRatio
        let detailMaxH = textAvailableH * detailRatio
        
        var currentY = textStartY

        // Title - adaptive sizing
        let titleFont = resolvedFont(size: titleSz, weight: .bold, style: fontSt)
        let titleH = drawTextReturningHeight(show.titleOrEmpty, at: CGPoint(x: textX, y: currentY),
                                              font: titleFont, color: textColor,
                                              maxWidth: textW, maxHeight: titleMaxH, maxLines: 2)
        currentY += titleH + innerPad * 0.3

        // Venue - adaptive sizing
        if options.showVenue, !show.venueOrEmpty.isEmpty {
            let venueFont = resolvedFont(size: detailSz, weight: .medium, style: fontSt)
            let venueH = drawTextReturningHeight(show.venueOrEmpty, at: CGPoint(x: textX, y: currentY),
                                                  font: venueFont, color: subColor,
                                                  maxWidth: textW, maxHeight: detailMaxH, maxLines: 1)
            currentY += venueH + innerPad * 0.2
        }

        // Time
        if options.showTime {
            let timeFont = resolvedFont(size: detailSz * 0.9, weight: .regular, style: fontSt)
            _ = drawTextReturningHeight(show.timeString, at: CGPoint(x: textX, y: currentY),
                                        font: timeFont, color: subColor.withAlphaComponent(0.75),
                                        maxWidth: textW, maxHeight: detailMaxH, maxLines: 1)
        }
    }

    /// Minimal: Clean text-only, no date badge
    private static func drawMinimalCard(ctx: CGContext, show: ShowSnapshot, cardRect: CGRect,
                                         innerPad: CGFloat, titleSz: CGFloat, detailSz: CGFloat,
                                         fontSt: FontStyle, textColor: UIColor, subColor: UIColor,
                                         options: ExportOptions) {
        let cardX = cardRect.minX
        let cardY = cardRect.minY
        let cardW = cardRect.width
        let cardH = cardRect.height
        
        let textX = cardX + innerPad
        let textW = max(1, cardW - innerPad * 2)
        let textAvailableH = cardH - innerPad * 2
        
        // Count elements
        var elementCount = 1 // Title
        if options.showDate { elementCount += 1 }
        if options.showVenue && !show.venueOrEmpty.isEmpty { elementCount += 1 }
        
        // Space distribution
        let titleRatio: CGFloat = 0.5
        let detailRatio: CGFloat = (1.0 - titleRatio) / CGFloat(max(1, elementCount - 1))
        
        let titleMaxH = textAvailableH * titleRatio
        let detailMaxH = textAvailableH * detailRatio
        
        var currentY = cardY + innerPad

        // Title
        let titleFont = resolvedFont(size: titleSz, weight: .bold, style: fontSt)
        let titleH = drawTextReturningHeight(show.titleOrEmpty, at: CGPoint(x: textX, y: currentY),
                                              font: titleFont, color: textColor,
                                              maxWidth: textW, maxHeight: titleMaxH, maxLines: 2)
        currentY += titleH + innerPad * 0.3

        // Date inline
        if options.showDate {
            let dateFont = resolvedFont(size: detailSz, weight: .medium, style: fontSt)
            let dateStr = "\(show.monthAbbrev) \(show.dayNumber)" + (options.showTime ? " · \(show.timeString)" : "")
            let dateH = drawTextReturningHeight(dateStr, at: CGPoint(x: textX, y: currentY),
                                                 font: dateFont, color: subColor,
                                                 maxWidth: textW, maxHeight: detailMaxH, maxLines: 1)
            currentY += dateH + innerPad * 0.2
        }

        // Venue
        if options.showVenue, !show.venueOrEmpty.isEmpty {
            let venueFont = resolvedFont(size: detailSz * 0.9, weight: .regular, style: fontSt)
            _ = drawTextReturningHeight(show.venueOrEmpty, at: CGPoint(x: textX, y: currentY),
                                        font: venueFont, color: subColor.withAlphaComponent(0.7),
                                        maxWidth: textW, maxHeight: detailMaxH, maxLines: 1)
        }
    }

    /// Bold: Large date on top, details below
    private static func drawBoldCard(ctx: CGContext, show: ShowSnapshot, cardRect: CGRect,
                                      innerPad: CGFloat, titleSz: CGFloat, detailSz: CGFloat,
                                      dateSz: CGFloat, monthSz: CGFloat, fontSt: FontStyle,
                                      accent: UIColor, textColor: UIColor, subColor: UIColor,
                                      options: ExportOptions) {
        let cardX = cardRect.minX
        let cardY = cardRect.minY
        let cardW = cardRect.width
        let cardH = cardRect.height
        
        let textW = max(1, cardW - innerPad * 2)
        let textAvailableH = cardH - innerPad
        
        // Count elements for space distribution
        var elementCount = 1 // Title always
        if options.showDate { elementCount += 1 }
        if options.showVenue && !show.venueOrEmpty.isEmpty { elementCount += 1 }
        if options.showTime { elementCount += 1 }
        
        // Date gets more space if shown, title gets bulk of remaining
        let dateRatio: CGFloat = options.showDate ? 0.35 : 0
        let remainingRatio = 1.0 - dateRatio
        let titleRatio: CGFloat = remainingRatio * 0.5
        let detailRatio: CGFloat = remainingRatio * 0.25
        
        var currentY = cardY + innerPad * 0.5

        // Large date at top (centered)
        if options.showDate {
            let dateMaxH = textAvailableH * dateRatio
            let bigDateSz = min(dateSz * 2.5, dateMaxH * 0.7)
            let dateFont = resolvedFont(size: bigDateSz, weight: .heavy, style: fontSt)
            let dateStr = "\(show.monthAbbrev) \(show.dayNumber)"
            let dateH = drawTextReturningHeight(dateStr, at: CGPoint(x: cardX + innerPad, y: currentY),
                                                 font: dateFont, color: accent,
                                                 maxWidth: textW, maxHeight: dateMaxH, maxLines: 1, centered: true)
            currentY += dateH + innerPad * 0.3
        }

        // Title centered
        let titleMaxH = textAvailableH * titleRatio
        let titleFont = resolvedFont(size: titleSz, weight: .bold, style: fontSt)
        let titleH = drawTextReturningHeight(show.titleOrEmpty, at: CGPoint(x: cardX + innerPad, y: currentY),
                                              font: titleFont, color: textColor,
                                              maxWidth: textW, maxHeight: titleMaxH, maxLines: 2, centered: true)
        currentY += titleH + innerPad * 0.2

        // Venue centered
        if options.showVenue, !show.venueOrEmpty.isEmpty {
            let venueMaxH = textAvailableH * detailRatio
            let venueFont = resolvedFont(size: detailSz, weight: .medium, style: fontSt)
            let venueH = drawTextReturningHeight(show.venueOrEmpty, at: CGPoint(x: cardX + innerPad, y: currentY),
                                                  font: venueFont, color: subColor,
                                                  maxWidth: textW, maxHeight: venueMaxH, maxLines: 1, centered: true)
            currentY += venueH + innerPad * 0.2
        }

        // Time centered
        if options.showTime {
            let timeMaxH = textAvailableH * detailRatio
            let timeFont = resolvedFont(size: detailSz * 0.9, weight: .regular, style: fontSt)
            _ = drawTextReturningHeight(show.timeString, at: CGPoint(x: cardX + innerPad, y: currentY),
                                        font: timeFont, color: subColor.withAlphaComponent(0.7),
                                        maxWidth: textW, maxHeight: timeMaxH, maxLines: 1, centered: true)
        }
    }

    /// Compact: Small cards with essential info
    private static func drawCompactCard(ctx: CGContext, show: ShowSnapshot, cardRect: CGRect,
                                         innerPad: CGFloat, titleSz: CGFloat, detailSz: CGFloat,
                                         monthSz: CGFloat, fontSt: FontStyle,
                                         accent: UIColor, textColor: UIColor, subColor: UIColor,
                                         options: ExportOptions) {
        let cardX = cardRect.minX
        let cardY = cardRect.minY
        let cardW = cardRect.width
        let cardH = cardRect.height
        
        let textX = cardX + innerPad * 0.5
        let textW = max(1, cardW - innerPad)
        let textAvailableH = cardH - innerPad
        
        // Count elements
        var elementCount = 1 // Title
        if options.showDate { elementCount += 1 }
        if options.showVenue && !show.venueOrEmpty.isEmpty { elementCount += 1 }
        
        // Space distribution for compact
        let dateRatio: CGFloat = options.showDate ? 0.2 : 0
        let titleRatio: CGFloat = 0.45
        let venueRatio: CGFloat = 0.25
        
        var currentY = cardY + innerPad * 0.3

        // Date small inline
        if options.showDate {
            let dateMaxH = textAvailableH * dateRatio
            let dateFont = resolvedFont(size: monthSz, weight: .bold, style: fontSt)
            let dateStr = "\(show.monthAbbrev) \(show.dayNumber)"
            let dateH = drawTextReturningHeight(dateStr, at: CGPoint(x: textX, y: currentY),
                                                 font: dateFont, color: accent,
                                                 maxWidth: textW, maxHeight: dateMaxH, maxLines: 1)
            currentY += dateH + innerPad * 0.15
        }

        // Title
        let titleMaxH = textAvailableH * titleRatio
        let titleFont = resolvedFont(size: titleSz * 0.9, weight: .bold, style: fontSt)
        let titleH = drawTextReturningHeight(show.titleOrEmpty, at: CGPoint(x: textX, y: currentY),
                                              font: titleFont, color: textColor,
                                              maxWidth: textW, maxHeight: titleMaxH, maxLines: 2)
        currentY += titleH + innerPad * 0.1

        // Venue (smaller)
        if options.showVenue, !show.venueOrEmpty.isEmpty {
            let venueMaxH = textAvailableH * venueRatio
            let venueFont = resolvedFont(size: detailSz * 0.8, weight: .regular, style: fontSt)
            _ = drawTextReturningHeight(show.venueOrEmpty, at: CGPoint(x: textX, y: currentY),
                                        font: venueFont, color: subColor.withAlphaComponent(0.7),
                                        maxWidth: textW, maxHeight: venueMaxH, maxLines: 1)
        }
    }

    // MARK: - Stacked List (One-Line Per Show)

    /// Stacked: Each show is a single horizontal row with all details inline.
    /// Layout: `DATE · TITLE · VENUE · TIME`  stacked vertically with thin separators.
    private static func drawStackedList(ctx: CGContext, allShows: [ShowSnapshot],
                                         options: ExportOptions,
                                         gridOrigin: CGPoint, gridSize: CGSize,
                                         accent: UIColor, textColor: UIColor,
                                         subColor: UIColor, isLight: Bool) {
        guard !allShows.isEmpty else {
            let emptyFont = UIFont.systemFont(ofSize: gridSize.width * 0.04, weight: .medium)
            drawText("No shows scheduled yet",
                     at: CGPoint(x: gridOrigin.x, y: gridOrigin.y + gridSize.height * 0.4),
                     font: emptyFont, color: subColor,
                     maxWidth: gridSize.width, canvasHeight: gridOrigin.y + gridSize.height)
            return
        }

        let fontSt = options.fontStyle
        let ts = options.textScale
        let shows = options.maxRows > 0 ? Array(allShows.prefix(options.maxRows)) : allShows
        let count = shows.count

        let rowGap = gridSize.width * 0.012 * options.gridGap
        let totalGaps = rowGap * CGFloat(max(count - 1, 0))
        let rowH = max(1, (gridSize.height - totalGaps) / CGFloat(count))
        let innerPad = gridSize.width * 0.025 * options.showPadding

        // Font sizes scaled to row
        let mainSz = max(10, rowH * 0.38 * ts)
        let dateSz = max(9, rowH * 0.32 * ts)
        let dotSz  = max(8, rowH * 0.26 * ts)

        let dividerColor = isLight
            ? UIColor.black.withAlphaComponent(0.08)
            : UIColor.white.withAlphaComponent(0.12)

        for (i, show) in shows.enumerated() {
            let rowY = gridOrigin.y + CGFloat(i) * (rowH + rowGap)
            let rowRect = CGRect(x: gridOrigin.x, y: rowY, width: gridSize.width, height: rowH)

            // Build the one-line string: "MAR 15 · Title · Venue · 8:00 PM"
            var parts: [String] = []

            if options.showDate {
                parts.append("\(show.monthAbbrev) \(show.dayNumber)")
            }

            parts.append(show.titleOrEmpty)

            if options.showVenue, !show.venueOrEmpty.isEmpty {
                parts.append(show.venueOrEmpty)
            }

            if options.showTime {
                parts.append(show.timeString)
            }

            // Draw the composed line
            let textX = rowRect.minX + innerPad
            let textW = max(1, rowRect.width - innerPad * 2)

            // Build and auto-scale the one-line attributed string to fit without truncation
            var scaleFactor: CGFloat = 1.0
            let minScale: CGFloat = 0.25 // Allow scaling down to 25% of original size
            var composed = NSMutableAttributedString()
            var measuredWidth: CGFloat = .greatestFiniteMagnitude

            // Iteratively scale fonts down until the line fits the available width
            while scaleFactor >= minScale {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byClipping

                composed = NSMutableAttributedString()
                for (pi, part) in parts.enumerated() {
                    let isDate = pi == 0 && options.showDate
                    let isTitle = (options.showDate && pi == 1) || (!options.showDate && pi == 0)

                    let color: UIColor = isDate ? accent : (isTitle ? textColor : subColor)
                    let weight: UIFont.Weight = isTitle ? .bold : (isDate ? .heavy : .regular)
                    let size: CGFloat = (isDate ? dateSz : (isTitle ? mainSz : dotSz)) * scaleFactor

                    let font = resolvedFont(size: max(6, size), weight: weight, style: fontSt)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: font, .foregroundColor: color, .paragraphStyle: paragraph
                    ]
                    composed.append(NSAttributedString(string: part, attributes: attrs))

                    // Add separator dot
                    if pi < parts.count - 1 {
                        let dotFont = resolvedFont(size: max(6, dotSz * scaleFactor), weight: .regular, style: fontSt)
                        let dotAttrs: [NSAttributedString.Key: Any] = [
                            .font: dotFont,
                            .foregroundColor: subColor.withAlphaComponent(0.4),
                            .paragraphStyle: paragraph
                        ]
                        composed.append(NSAttributedString(string: "  ·  ", attributes: dotAttrs))
                    }
                }

                // Measure single-line width
                let measured = composed.boundingRect(
                    with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                measuredWidth = measured.width

                if measuredWidth <= textW { break }
                scaleFactor -= 0.05
            }

            let scaledMainSz = mainSz * max(scaleFactor, minScale)
            let textY = rowRect.minY + (rowH - scaledMainSz * 1.3) * 0.5
            let drawRect = CGRect(x: textX, y: textY, width: textW, height: scaledMainSz * 1.6)
            UIGraphicsPushContext(ctx)
            composed.draw(in: drawRect)
            UIGraphicsPopContext()

            // Thin divider between rows (not after last)
            if i < shows.count - 1 {
                let divY = rowRect.maxY + rowGap * 0.5
                ctx.setStrokeColor(dividerColor.cgColor)
                ctx.setLineWidth(1)
                ctx.move(to: CGPoint(x: gridOrigin.x + innerPad, y: divY))
                ctx.addLine(to: CGPoint(x: gridOrigin.x + gridSize.width - innerPad, y: divY))
                ctx.strokePath()
            }
        }
    }

    // MARK: - Background

    private static func drawBackground(ctx: CGContext, rect: CGRect,
                                       featured: ShowSnapshot?, style: BackgroundStyle,
                                       customBG: CustomBackground? = nil) {
        switch style {
        case .custom:
            if let bg = customBG {
                switch bg.kind {
                case .solidColor:
                    ctx.setFillColor(UIColor(hex: bg.solidHex).cgColor)
                    ctx.fill(rect)
                case .gradient:
                    let space = CGColorSpaceCreateDeviceRGB()
                    let cgc = [UIColor(hex: bg.gradientFromHex).cgColor,
                               UIColor(hex: bg.gradientToHex).cgColor] as CFArray
                    if let grad = CGGradient(colorsSpace: space, colors: cgc, locations: [0, 1]) {
                        ctx.drawLinearGradient(grad, start: .zero,
                                               end: CGPoint(x: 0, y: rect.height), options: [])
                    }
                case .photo:
                    if let data = bg.photoData, let img = UIImage(data: data) {
                        drawImageFill(img, in: rect, ctx: ctx)
                    } else {
                        ctx.setFillColor(UIColor(hex: "#111111").cgColor); ctx.fill(rect)
                    }
                }
            } else {
                ctx.setFillColor(UIColor(hex: "#111111").cgColor); ctx.fill(rect)
            }
        case .gradient:
            let space = CGColorSpaceCreateDeviceRGB()
            let cgc = [UIColor(hex: "#1A0A00").cgColor, UIColor(hex: "#3D1C00").cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: space, colors: cgc, locations: [0, 1]) {
                ctx.drawLinearGradient(grad, start: .zero,
                                       end: CGPoint(x: 0, y: rect.height), options: [])
            }
        case .dark:
            ctx.setFillColor(UIColor(hex: "#111111").cgColor); ctx.fill(rect)
        case .light:
            ctx.setFillColor(UIColor(hex: "#F5F5F0").cgColor); ctx.fill(rect)
        }
    }

    // MARK: - Text Overlays

    private static func drawTextOverlays(_ overlays: [TextOverlay], in size: CGSize, ctx: CGContext) {
        for overlay in overlays {
            let resolvedSize = overlay.fontSize * size.width
            let font: UIFont
            if overlay.fontName == "System" {
                font = UIFont.systemFont(ofSize: resolvedSize, weight: uiFontWeight(overlay.fontWeight))
            } else {
                font = UIFont(name: overlay.fontName, size: resolvedSize)
                    ?? UIFont.systemFont(ofSize: resolvedSize, weight: uiFontWeight(overlay.fontWeight))
            }
            let color = UIColor(hex: overlay.colorHex)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let text = overlay.text as NSString
            let textSize = text.size(withAttributes: attrs)
            let cx = overlay.positionX * size.width
            let cy = overlay.positionY * size.height

            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            if overlay.rotation != 0 { ctx.rotate(by: overlay.rotation * .pi / 180) }

            let drawRect = CGRect(x: -textSize.width / 2, y: -textSize.height / 2,
                                  width: textSize.width, height: textSize.height)
            UIGraphicsPushContext(ctx)
            text.draw(in: drawRect, withAttributes: attrs)
            UIGraphicsPopContext()
            ctx.restoreGState()
        }
    }

    // MARK: - Watermark

    private static func drawWatermark(in ctx: CGContext, size: CGSize, options: ExportOptions, style: WatermarkStyle) {
        switch style {
        case .subtlePreview:
            drawSubtlePreviewWatermark(in: ctx, size: size, options: options)
        case .export:
            drawExportWatermark(in: ctx, size: size, options: options)
        }
    }

    private static func drawSubtlePreviewWatermark(in ctx: CGContext, size: CGSize, options: ExportOptions) {
        let text = appWatermarkText
        let fontSize = max(9, min(size.width, size.height) * 0.022)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.72)
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let horizontalPadding = fontSize * 0.7
        let verticalPadding = fontSize * 0.38
        let margin = max(10, min(size.width, size.height) * 0.024)
        let watermarkSize = CGSize(
            width: textSize.width + horizontalPadding * 2,
            height: textSize.height + verticalPadding * 2
        )

        let rect = CGRect(x: size.width - watermarkSize.width - margin,
                          y: size.height - watermarkSize.height - margin,
                          width: watermarkSize.width,
                          height: watermarkSize.height)

        ctx.saveGState()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2)
        ctx.setShadow(offset: CGSize(width: 0, height: 1), blur: fontSize * 0.25,
                      color: UIColor.black.withAlphaComponent(0.25).cgColor)
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.28).cgColor)
        ctx.addPath(path.cgPath)
        ctx.fillPath()

        UIGraphicsPushContext(ctx)
        (text as NSString).draw(
            at: CGPoint(x: rect.minX + horizontalPadding, y: rect.minY + verticalPadding),
            withAttributes: attributes
        )
        UIGraphicsPopContext()
        ctx.restoreGState()
    }

    private static func estimatedImportantRects(size: CGSize, options: ExportOptions) -> [CGRect] {
        let pad = size.width * 0.05
        let headerH: CGFloat = options.showHeader ? (options.headerStyle == .minimal ? size.width * 0.10 : size.width * 0.14) : 0
        let baseGridTop = pad + headerH
        let baseGridBottom = size.height - pad * 0.5
        let baseGridH = baseGridBottom - baseGridTop
        let baseGridW = size.width - pad * 2

        let scale = CGFloat(options.listScale)
        let gridW = baseGridW * scale
        let gridH = baseGridH * scale
        let gridCenterX = pad + baseGridW * 0.5 + CGFloat(options.listOffsetX) * size.width
        let gridCenterY = baseGridTop + baseGridH * 0.5 + CGFloat(options.listOffsetY) * size.height
        var rects = [
            CGRect(x: gridCenterX - gridW * 0.5,
                   y: gridCenterY - gridH * 0.5,
                   width: gridW,
                   height: gridH).insetBy(dx: -pad * 0.2, dy: -pad * 0.2)
        ]

        if options.showHeader {
            rects.append(CGRect(x: 0, y: 0, width: size.width, height: baseGridTop + pad * 0.35))
        }

        for overlay in options.textOverlays where !overlay.text.isEmpty {
            let overlayFontSize = overlay.fontSize * size.width
            let estimatedWidth = min(size.width * 0.9, max(overlayFontSize * 4, CGFloat(overlay.text.count) * overlayFontSize * 0.55))
            let estimatedHeight = overlayFontSize * 1.6
            rects.append(CGRect(
                x: overlay.positionX * size.width - estimatedWidth * 0.5,
                y: overlay.positionY * size.height - estimatedHeight * 0.5,
                width: estimatedWidth,
                height: estimatedHeight
            ).insetBy(dx: -pad * 0.2, dy: -pad * 0.2))
        }

        return rects
    }

    private static func totalIntersectionArea(_ rect: CGRect, with protectedRects: [CGRect]) -> CGFloat {
        protectedRects.reduce(0) { total, protectedRect in
            let intersection = rect.intersection(protectedRect)
            guard !intersection.isNull else { return total }
            return total + intersection.width * intersection.height
        }
    }

    private static func drawExportWatermark(in ctx: CGContext, size: CGSize, options: ExportOptions) {
        let text = appWatermarkText
        UIGraphicsPushContext(ctx)

        let tileFontSize = max(22, min(size.width, size.height) * 0.044)
        let tileFont = UIFont.systemFont(ofSize: tileFontSize, weight: .heavy)
        let tileAttributes: [NSAttributedString.Key: Any] = [
            .font: tileFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.24)
        ]
        let tileStepY = tileFontSize * 3.6
        let tileStepX = max(size.width * 0.82, tileFontSize * 15)
        for y in stride(from: size.height * 0.08, through: size.height * 0.95, by: tileStepY) {
            for x in stride(from: -size.width * 0.22, through: size.width * 1.05, by: tileStepX) {
                ctx.saveGState()
                ctx.translateBy(x: x, y: y)
                ctx.rotate(by: -.pi / 7)
                (text as NSString).draw(at: .zero, withAttributes: tileAttributes)
                ctx.restoreGState()
            }
        }

        let fontSize = max(20, min(size.width, size.height) * 0.034)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.96)
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let horizontalPadding = fontSize * 0.9
        let verticalPadding = fontSize * 0.52
        let margin = max(20, min(size.width, size.height) * 0.035)
        let rect = CGRect(
            x: (size.width - textSize.width - horizontalPadding * 2) / 2,
            y: size.height - textSize.height - verticalPadding * 2 - margin,
            width: textSize.width + horizontalPadding * 2,
            height: textSize.height + verticalPadding * 2
        )

        let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2)
        UIColor.black.withAlphaComponent(0.62).setFill()
        path.fill()
        (text as NSString).draw(at: CGPoint(x: rect.minX + horizontalPadding,
                                            y: rect.minY + verticalPadding),
                                withAttributes: attributes)
        UIGraphicsPopContext()
    }

    private static func uiFontWeight(_ name: String) -> UIFont.Weight {
        switch name.lowercased() {
        case "ultralight": return .ultraLight
        case "thin":       return .thin
        case "light":      return .light
        case "regular":    return .regular
        case "medium":     return .medium
        case "semibold":   return .semibold
        case "bold":       return .bold
        case "heavy":      return .heavy
        case "black":      return .black
        default:           return .bold
        }
    }

    // MARK: - Primitives

    /// Draw image filling the rect (aspect-fill, centered crop).
    private static func drawImageFill(_ image: UIImage, in rect: CGRect, ctx: CGContext) {
        let imgAspect = image.size.width / image.size.height
        let rectAspect = rect.width / rect.height
        var drawRect = rect
        if imgAspect > rectAspect {
            let w = rect.height * imgAspect
            drawRect = CGRect(x: rect.midX - w / 2, y: rect.minY, width: w, height: rect.height)
        } else {
            let h = rect.width / imgAspect
            drawRect = CGRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h)
        }
        ctx.saveGState()
        ctx.clip(to: rect)
        UIGraphicsPushContext(ctx)
        image.draw(in: drawRect)
        UIGraphicsPopContext()
        ctx.restoreGState()
    }

    private static func drawText(_ text: String, at origin: CGPoint, font: UIFont,
                                   color: UIColor, maxWidth: CGFloat, canvasHeight: CGFloat,
                                   lineSpacing: CGFloat = 0,
                                   maxLines: Int = 2, centered: Bool = false) {
        guard !text.isEmpty else { return }
        
        let drawWidth = max(1, maxWidth)
        let drawHeight = max(1, canvasHeight - origin.y)
        
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = lineSpacing
        ps.lineBreakMode = .byWordWrapping  // Never truncate with "..."
        if centered {
            ps.alignment = .center
        }
        
        var usedFont = font
        var fontSize = font.pointSize
        let minFontSize: CGFloat = max(6, font.pointSize * 0.25) // Allow scaling down to 25% of original
        
        // Calculate the maximum height we want (based on maxLines)
        var singleLineHeight = font.lineHeight
        var maxAllowedHeight = min(drawHeight, singleLineHeight * CGFloat(maxLines) + lineSpacing * CGFloat(maxLines - 1))
        
        var attrString = NSAttributedString(string: text, attributes: [.font: usedFont, .foregroundColor: color, .paragraphStyle: ps])
        var bounding = attrString.boundingRect(with: CGSize(width: drawWidth, height: .greatestFiniteMagnitude), 
                                                options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        
        // Always scale down if text doesn't fit within maxLines height
        while bounding.height > maxAllowedHeight && fontSize > minFontSize {
            fontSize -= 0.5
            usedFont = font.withSize(fontSize)
            let newPs = NSMutableParagraphStyle()
            newPs.lineSpacing = lineSpacing * (fontSize / font.pointSize)
            newPs.lineBreakMode = .byWordWrapping
            if centered { newPs.alignment = .center }
            attrString = NSAttributedString(string: text, attributes: [.font: usedFont, .foregroundColor: color, .paragraphStyle: newPs])
            bounding = attrString.boundingRect(with: CGSize(width: drawWidth, height: .greatestFiniteMagnitude), 
                                                 options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            singleLineHeight = usedFont.lineHeight
            maxAllowedHeight = min(drawHeight, singleLineHeight * CGFloat(maxLines) + lineSpacing * CGFloat(maxLines - 1))
        }
        
        // Draw the text
        let drawRect = CGRect(x: origin.x, y: origin.y, width: drawWidth, height: min(bounding.height + 4, drawHeight))
        UIGraphicsPushContext(UIGraphicsGetCurrentContext()!)
        attrString.draw(in: drawRect)
        UIGraphicsPopContext()
    }
    
    /// Draws text and returns the actual height used
    private static func drawTextReturningHeight(_ text: String, at origin: CGPoint, font: UIFont,
                                                 color: UIColor, maxWidth: CGFloat, maxHeight: CGFloat,
                                                 lineSpacing: CGFloat = 0, maxLines: Int = 2,
                                                 centered: Bool = false) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        
        let drawWidth = max(1, maxWidth)
        
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = lineSpacing
        ps.lineBreakMode = .byWordWrapping
        if centered { ps.alignment = .center }
        
        var usedFont = font
        var fontSize = font.pointSize
        let minFontSize: CGFloat = max(6, font.pointSize * 0.25) // Allow scaling down to 25% of original
        
        var singleLineHeight = font.lineHeight
        var maxAllowedHeight = min(maxHeight, singleLineHeight * CGFloat(maxLines) + lineSpacing * CGFloat(maxLines - 1))
        
        var currentPs = ps
        var attrString = NSAttributedString(string: text, attributes: [.font: usedFont, .foregroundColor: color, .paragraphStyle: currentPs])
        var bounding = attrString.boundingRect(with: CGSize(width: drawWidth, height: .greatestFiniteMagnitude),
                                                options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        
        // Scale down if needed — check both height overflow and single-line width for maxLines==1
        while bounding.height > maxAllowedHeight && fontSize > minFontSize {
            fontSize -= 0.5
            usedFont = font.withSize(fontSize)
            currentPs = NSMutableParagraphStyle()
            currentPs.lineSpacing = lineSpacing * (fontSize / font.pointSize)
            currentPs.lineBreakMode = .byWordWrapping
            if centered { currentPs.alignment = .center }
            attrString = NSAttributedString(string: text, attributes: [.font: usedFont, .foregroundColor: color, .paragraphStyle: currentPs])
            bounding = attrString.boundingRect(with: CGSize(width: drawWidth, height: .greatestFiniteMagnitude),
                                                options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            singleLineHeight = usedFont.lineHeight
            maxAllowedHeight = min(maxHeight, singleLineHeight * CGFloat(maxLines) + lineSpacing * CGFloat(maxLines - 1))
        }
        
        let finalHeight = min(bounding.height, maxAllowedHeight)
        let drawRect = CGRect(x: origin.x, y: origin.y, width: drawWidth, height: finalHeight + 2)
        UIGraphicsPushContext(UIGraphicsGetCurrentContext()!)
        attrString.draw(in: drawRect)
        UIGraphicsPopContext()
        
        return finalHeight
    }
}

// MARK: - UIColor hex init

private extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(red:   CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8)  & 0xFF) / 255,
                  blue:  CGFloat( rgb        & 0xFF) / 255,
                  alpha: 1)
    }
}
