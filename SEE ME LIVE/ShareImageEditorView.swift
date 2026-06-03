//
//  ShareImageEditorView.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 3/5/26.
//

import SwiftUI
import PhotosUI
import CoreImage
import AVFoundation
import CoreTransferable
import UniformTypeIdentifiers

// MARK: - Color Hex Init

private extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }

        guard h.count == 6, let rgb = UInt64(h, radix: 16) else {
            return nil
        }

        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

// MARK: - Editor Tab

private enum EditorTab: String, CaseIterable {
    case presets  = "Style"
    case layout   = "Layout"
    case text     = "Text"
    case colors   = "Colors"
    case elements = "Fine-tune"

    var icon: String {
        switch self {
        case .presets:  return "paintbrush.pointed"
        case .layout:   return "square.grid.2x2"
        case .text:     return "textformat"
        case .colors:   return "paintpalette"
        case .elements: return "slider.horizontal.3"
        }
    }
}

// MARK: - Share Image Editor View

struct ShareImageEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared

    let shows: [Show]
    let performerName: String

    // ── Preset palette (curated) ──
    private static let presetColors: [String] = [
        "#FFFFFF", "#F5F5F5", "#000000", "#1C1C1E",
        "#EB2429", "#007AFF", "#34C759", "#FFCC00"
    ]

    private static let gradientPresets: [(from: String, to: String, label: String, icon: String)] = [
        ("#000000", "#434343", "Noir",   "moon.fill"),
        ("#1A0A00", "#3D1C00", "Amber",  "flame"),
        ("#141E30", "#243B55", "Royal",  "crown"),
        ("#FF416C", "#FF4B2B", "Sunset", "sun.horizon"),
    ]

    private static let fontWeights: [(weight: String, label: String)] = [
        ("light", "Light"), ("regular", "Regular"), ("medium", "Medium"),
        ("semibold", "Semi"), ("bold", "Bold"), ("heavy", "Heavy"), ("black", "Black")
    ]

    private static let fontFamilies: [(name: String, label: String, preview: String)] = [
        ("System", "System", "Aa"),
        ("HelveticaNeue", "Helvetica", "Aa"),
        ("Avenir-Heavy", "Avenir", "Aa"),
        ("Georgia", "Georgia", "Aa"),
        ("GillSans", "Gill Sans", "Aa"),
        ("Futura-Medium", "Futura", "Aa"),
        ("Didot", "Didot", "Aa"),
        ("Copperplate", "Copperplate", "Aa"),
        ("Menlo-Regular", "Menlo", "Aa"),
    ]

    private static let flyerPresets: [(name: String, icon: String, apply: (inout ExportOptions) -> Void)] = [
        ("Clean", "sparkles", { opts in
            opts.layoutTemplate = .minimal
            opts.cardStyle = .minimal
            opts.showHeader = false
            opts.scrimIntensity = 0.45
            opts.textScale = 1.0
            opts.fontStyle = .system
        }),
        ("Bold", "flame", { opts in
            opts.layoutTemplate = .bold
            opts.cardStyle = .rounded
            opts.showHeader = true
            opts.headerStyle = .centered
            opts.textScale = 1.15
            opts.fontStyle = .system
        }),
        ("Classic", "book.closed", { opts in
            opts.layoutTemplate = .classic
            opts.cardStyle = .rounded
            opts.showHeader = true
            opts.headerStyle = .left
            opts.textScale = 1.0
            opts.fontStyle = .system
        }),
        ("Dramatic", "theatermasks", { opts in
            opts.layoutTemplate = .bold
            opts.cardStyle = .outlined
            opts.showHeader = true
            opts.headerStyle = .centered
            opts.scrimIntensity = 0.7
            opts.textScale = 1.1
            opts.fontStyle = .serif
        }),
        ("Compact", "rectangle.compress.vertical", { opts in
            opts.layoutTemplate = .compact
            opts.cardStyle = .sharp
            opts.showHeader = false
            opts.textScale = 0.9
            opts.fontStyle = .system
        }),
        ("Poster", "star.fill", { opts in
            opts.layoutTemplate = .bold
            opts.cardStyle = .rounded
            opts.showHeader = true
            opts.headerStyle = .centered
            opts.textScale = 1.3
            opts.scrimIntensity = 0.6
            opts.fontStyle = .rounded
        }),
        ("Stacked", "line.3.horizontal", { opts in
            opts.layoutTemplate = .stacked
            opts.cardStyle = .minimal
            opts.showHeader = true
            opts.headerStyle = .centered
            opts.textScale = 1.0
            opts.scrimIntensity = 0.5
            opts.fontStyle = .system
            opts.listScale = 1.0
            opts.listOffsetX = 0
            opts.listOffsetY = 0
        }),
    ]

    // MARK: - State

    @State private var options = ExportOptions()
    @State private var cachedImage = UIImage()
    @State private var renderTask: Task<Void, Never>?
    @State private var isRendering = false
    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var selectedTab: EditorTab = .presets
    @State private var showRemoveWatermarkSheet = false
    @State private var showExportOptions = false
    @State private var isScreenCaptured = UIScreen.main.isCaptured
    @State private var showScreenshotMessage = false
    @AppStorage("shareImageEditor.lastOptions") private var savedOptionsData = Data()

    // Background
    @State private var bgKind: CustomBackground.Kind = .gradient
    @State private var solidColor: Color = Color(hex: "#1A0A00") ?? .black
    @State private var gradFrom: Color = Color(hex: "#1A0A00") ?? .black
    @State private var gradTo: Color = Color(hex: "#3D1C00") ?? .brown
    @State private var bgPhotoItem: PhotosPickerItem?
    @State private var bgVideoItem: PhotosPickerItem?
    @State private var bgPhotoData: Data?
    @State private var bgVideoFrameData: Data?
    @State private var bgVideoURL: URL?
    @State private var bgPhotoThumb: UIImage?
    @State private var bgVideoThumb: UIImage?

    // Overlays
    @State private var overlays: [TextOverlay] = []
    @State private var selectedOverlayID: UUID?
    @State private var showAddTextSheet = false
    @State private var newOverlayText = ""
    @State private var showOverlayEditor = false
    @State private var editingOverlayIndex: Int?

    // Show list drag/scale on canvas
    @State private var listGestureActive = false

    // Colors
    @State private var accentColor: Color = Color("AccentColor")

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geo in
                    VStack(spacing: 0) {
                        // ── PINNED PREVIEW ──
                        canvasPreview(availableHeight: geo.size.height)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        // ── QUICK ACTION BAR ──
                        quickActionBar
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                        // ── TAB BAR ──
                        tabBar

                        // ── TAB CONTENT ──
                        tabContent
                            .frame(maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("Edit Flyer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showAddTextSheet) { addTextSheet }
        .sheet(isPresented: $showOverlayEditor, onDismiss: { editingOverlayIndex = nil }) {
            if let idx = editingOverlayIndex, overlays.indices.contains(idx) {
                OverlayEditorSheet(
                    overlay: $overlays[idx],
                    presetColors: Self.presetColors,
                    fontWeights: Self.fontWeights,
                    fontFamilies: Self.fontFamilies,
                    onUpdate: regeneratePreview,
                    onDelete: {
                        overlays.remove(at: idx)
                        selectedOverlayID = nil
                        showOverlayEditor = false
                        regeneratePreview()
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            restoreSavedOptions()
            if cachedImage.size == .zero { regeneratePreview() }
        }
        .onDisappear {
            // Remove the copied source video from temp when the editor closes.
            if let bgVideoURL {
                try? FileManager.default.removeItem(at: bgVideoURL)
            }
        }
        .task {
            await purchaseManager.loadProducts()
            regeneratePreview()
        }
        .sheet(isPresented: $showRemoveWatermarkSheet) {
            RemoveWatermarkSheet(purchaseManager: purchaseManager)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Export", isPresented: $showExportOptions, titleVisibility: .visible) {
            Button("Export with blur + watermark") {
                shareImage(mode: .blurAndWatermark)
            }
            Button(purchaseManager.hasRemovedWatermark ? "Export as is" : "Export as is with clear HD") {
                if purchaseManager.hasRemovedWatermark {
                    shareImage(mode: .asIs)
                } else {
                    showRemoveWatermarkSheet = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: purchaseManager.hasRemovedWatermark) {
            regeneratePreview()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            isScreenCaptured = UIScreen.main.isCaptured
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            guard !purchaseManager.hasRemovedWatermark else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                showScreenshotMessage = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showScreenshotMessage = false
                }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Canvas Preview
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func canvasPreview(availableHeight: CGFloat) -> some View {
        let aspect = options.sizePreset.size.width / options.sizePreset.size.height
        let previewH = max(260, availableHeight * 0.6)

        return GeometryReader { geo in
            let availW = max(geo.size.width, 1)
            let availH = max(geo.size.height, 1)
            let fitW = max(min(availW, availH * aspect), 1)
            let fitH = max(fitW / aspect, 1)

            ZStack {
                Image(uiImage: cachedImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .blur(radius: purchaseManager.hasRemovedWatermark ? 0 : 0.25)
                    .shadow(color: .black.opacity(0.6), radius: 24, y: 12)
                    .opacity(isRendering ? 0.6 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isRendering)

                if isRendering {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.3)
                }

                // ── Draggable / Scalable Show List Region ──
                DraggableListOverlay(
                    offsetX: $options.listOffsetX,
                    offsetY: $options.listOffsetY,
                    scale: $options.listScale,
                    canvasSize: CGSize(width: fitW, height: fitH),
                    isActive: $listGestureActive,
                    onChanged: { regeneratePreviewDebounced() },
                    onEnded: { regeneratePreview() }
                )

                ForEach(Array(overlays.enumerated()), id: \.element.id) { idx, overlay in
                    DraggableTextLabel(
                        overlay: $overlays[idx],
                        canvasSize: CGSize(width: fitW, height: fitH),
                        isSelected: selectedOverlayID == overlay.id,
                        onTap: {
                            selectedOverlayID = overlay.id
                            editingOverlayIndex = idx
                            showOverlayEditor = true
                        },
                        onDragEnd: { regeneratePreviewDebounced() },
                        onDelete: {
                            overlays.remove(at: idx)
                            selectedOverlayID = nil
                            regeneratePreview()
                        }
                    )
                }

                if isScreenCaptured && !purchaseManager.hasRemovedWatermark {
                    ScreenCaptureProtectionOverlay()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if showScreenshotMessage {
                    screenshotMessage
                        .padding(.bottom, 12)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(width: fitW, height: fitH)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: previewH)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Quick Action Bar
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var quickActionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                formatMenu
                if !purchaseManager.hasRemovedWatermark {
                    removeWatermarkButton
                }
                Spacer()
                addTextButton
                exportButton
            }

            VStack(alignment: .leading, spacing: 8) {
                if !purchaseManager.hasRemovedWatermark {
                    removeWatermarkButton
                }
                HStack(spacing: 12) {
                    formatMenu
                    Spacer()
                    addTextButton
                    exportButton
                }
            }
        }
    }

    private var formatMenu: some View {
        Menu {
            ForEach(SocialSizePreset.allCases) { preset in
                Button {
                    options.sizePreset = preset
                    regeneratePreview()
                } label: {
                    Label(preset.displayLabel, systemImage: preset.icon)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: options.sizePreset.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(options.sizePreset.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .minimumScaleFactor(0.82)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.12), in: Capsule())
        }
    }

    private var removeWatermarkButton: some View {
        Button {
            showRemoveWatermarkSheet = true
        } label: {
            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.top, 1)
                Text("Remove watermark\nClear HD export")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white.opacity(0.62))
            .padding(.horizontal, 4)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var addTextButton: some View {
        Button {
            showAddTextSheet = true
        } label: {
            Image(systemName: "plus.square.on.square")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var exportButton: some View {
        Button {
            showExportOptions = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .bold))
                Text("Export")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.accentColor, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private enum ExportMode {
        case asIs
        case blurAndWatermark
    }

    private var selectedBackgroundThumbnail: UIImage? {
        bgKind == .video ? bgVideoThumb : bgPhotoThumb
    }

    private var screenshotMessage: some View {
        Text("Remove the watermark for clean exports.")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.64), in: Capsule())
            .allowsHitTesting(false)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Tab Bar
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(EditorTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                            .symbolRenderingMode(.hierarchical)
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : .white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.06))
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Tab Content
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @ViewBuilder
    private var tabContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                switch selectedTab {
                case .presets:  presetsPanel
                case .layout:   layoutPanel
                case .text:     textPanel
                case .colors:   colorsPanel
                case .elements: elementsPanel
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Presets Panel
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var presetsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("ONE-TAP STYLES")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(Self.flyerPresets, id: \.name) { preset in
                    Button {
                        withAnimation(.spring(response: 0.35)) {
                            preset.apply(&options)
                            regeneratePreview()
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                Image(systemName: preset.icon)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .frame(height: 56)

                            Text(preset.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            sectionLabel("BACKGROUND")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Self.gradientPresets, id: \.label) { preset in
                        Button {
                            gradFrom = Color(hex: preset.from) ?? .black
                            gradTo = Color(hex: preset.to) ?? .gray
                            options.backgroundStyle = .custom
                            bgKind = .gradient
                            regeneratePreview()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: preset.from) ?? .black, Color(hex: preset.to) ?? .gray],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(.white.opacity(0.15), lineWidth: 1)
                                    )
                                Text(preset.label)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }

            HStack(spacing: 12) {
                PhotosPicker(selection: $bgPhotoItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 14))
                        Text(bgPhotoData != nil ? "Change Image" : "Use Photo Background")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1), in: Capsule())
                }

                PhotosPicker(selection: $bgVideoItem, matching: .videos) {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 14))
                        Text(bgVideoFrameData != nil ? "Change Video" : "Use Video Background")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1), in: Capsule())
                }

                if let mediaThumb = selectedBackgroundThumbnail {
                    ZStack(alignment: .bottomTrailing) {
                        Image(uiImage: mediaThumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        if bgKind == .video {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(.black.opacity(0.6), in: Circle())
                                .padding(3)
                        }
                    }

                    Button {
                        clearMediaBackground()
                        regeneratePreview()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .onChange(of: bgPhotoItem) { _, newItem in
                Task { await loadBGPhoto(from: newItem) }
            }
            .onChange(of: bgVideoItem) { _, newItem in
                Task { await loadBGVideo(from: newItem) }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Layout Panel
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var layoutPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionLabel("TEMPLATE")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(LayoutTemplate.allCases) { template in
                        let isSelected = options.layoutTemplate == template
                        Button {
                            options.layoutTemplate = template
                            regeneratePreview()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: template.icon)
                                    .font(.system(size: 20, weight: .medium))
                                    .frame(width: 52, height: 52)
                                    .background(isSelected ? Color.accentColor : Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                Text(template.rawValue)
                                    .font(.system(size: 11, weight: .semibold))

                                Text(template.description)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(width: 80)
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }

            sectionLabel("CARD STYLE")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CardStyle.allCases) { style in
                        let isSelected = options.cardStyle == style
                        Button {
                            options.cardStyle = style
                            regeneratePreview()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: style.icon)
                                    .font(.system(size: 13))
                                Text(style.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(isSelected ? Color.accentColor : Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            sectionLabel("LIST POSITION & SIZE")

            HStack(spacing: 10) {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text("Drag the show list on the preview to reposition it")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            sliderRow(title: "List Size", value: $options.listScale, range: 0.3...2.0, step: 0.05,
                       format: { String(format: "%.0f%%", $0 * 100) })
            { regeneratePreview() }

            if options.listOffsetX != 0 || options.listOffsetY != 0 || options.listScale != 1.0 {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        options.listOffsetX = 0
                        options.listOffsetY = 0
                        options.listScale = 1.0
                        regeneratePreview()
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Reset Position & Size")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }

            sectionLabel("FINE-TUNE")

            sliderRow(title: "Columns", value: Binding(
                get: { Double(options.columns) },
                set: { options.columns = Int($0); regeneratePreview() }
            ), range: 0...4, step: 1, format: { "\(Int($0))" }, hint: "0 = auto")

            sliderRow(title: "Grid Gap", value: $options.gridGap, range: 0.5...2.0, step: 0.05,
                       format: { String(format: "%.0f%%", $0 * 100) })
            { regeneratePreview() }

            sliderRow(title: "Card Padding", value: $options.showPadding, range: 0.5...2.0, step: 0.05,
                       format: { String(format: "%.0f%%", $0 * 100) })
            { regeneratePreview() }

            sliderRow(title: "Background Dim", value: $options.scrimIntensity, range: 0.0...1.0, step: 0.05,
                       format: { String(format: "%.0f%%", $0 * 100) })
            { regeneratePreview() }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Text Panel
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var textPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionLabel("FONT FAMILY")

            Picker("Font", selection: Binding(
                get: { options.fontStyle },
                set: { options.fontStyle = $0; regeneratePreview() }
            )) {
                ForEach(FontStyle.allCases) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)

            sectionLabel("TEXT SIZE")

            sliderRow(title: "Scale", value: $options.textScale, range: 0.6...1.6, step: 0.05,
                       format: { String(format: "%.0f%%", $0 * 100) })
            { regeneratePreview() }

            sectionLabel("HEADER")

            Toggle(isOn: Binding(
                get: { options.showHeader },
                set: { options.showHeader = $0; regeneratePreview() }
            )) {
                Label("Show Header", systemImage: "text.alignleft")
                    .font(.system(size: 14, weight: .medium))
            }
            .tint(Color.accentColor)

            if options.showHeader {
                Picker("Alignment", selection: Binding(
                    get: { options.headerStyle },
                    set: { options.headerStyle = $0; regeneratePreview() }
                )) {
                    ForEach(HeaderStyle.allCases) { style in
                        Label(style.rawValue, systemImage: style.icon).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }

            sectionLabel("SHOW / HIDE")

            VStack(spacing: 2) {
                visibilityToggle("Venue", icon: "mappin.circle", isOn: Binding(
                    get: { options.showVenue },
                    set: { options.showVenue = $0; regeneratePreview() }
                ))
                visibilityToggle("Date", icon: "calendar", isOn: Binding(
                    get: { options.showDate },
                    set: { options.showDate = $0; regeneratePreview() }
                ))
                visibilityToggle("Time", icon: "clock", isOn: Binding(
                    get: { options.showTime },
                    set: { options.showTime = $0; regeneratePreview() }
                ))
            }
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            sectionLabel("CUSTOM TEXT OVERLAYS")

            if overlays.isEmpty {
                HStack {
                    Image(systemName: "text.badge.plus")
                        .foregroundStyle(.secondary)
                    Text("No custom text yet. Tap + above the preview to add.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(overlays.enumerated()), id: \.element.id) { idx, overlay in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: overlay.colorHex) ?? .white)
                                .frame(width: 12, height: 12)

                            Text(overlay.text)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                                .foregroundStyle(.white)

                            Spacer()

                            Button {
                                selectedOverlayID = overlay.id
                                editingOverlayIndex = idx
                                showOverlayEditor = true
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.accentColor)
                            }

                            Button {
                                overlays.remove(at: idx)
                                if selectedOverlayID == overlay.id { selectedOverlayID = nil }
                                regeneratePreview()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            selectedOverlayID == overlay.id ?
                            Color.accentColor.opacity(0.15) : Color.white.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    }
                }
            }

            Button {
                showAddTextSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Custom Text")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Colors Panel
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var colorsPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionLabel("ACCENT COLOR")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                ForEach(Self.presetColors, id: \.self) { hex in
                    let isSel = colorHex(accentColor) == hex
                    Button {
                        accentColor = Color(hex: hex) ?? .white
                        options.accentHex = hex
                        regeneratePreview()
                    } label: {
                        Circle()
                            .fill(Color(hex: hex) ?? .gray)
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                            .overlay(
                                isSel ? Circle().stroke(Color.white, lineWidth: 3).padding(-2) : nil
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                ColorPicker("", selection: Binding(
                    get: { accentColor },
                    set: { color in
                        accentColor = color
                        options.accentHex = colorHex(color)
                        regeneratePreview()
                    }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 36, height: 36)
            }

            sectionLabel("TEXT COLOR")

            HStack(spacing: 16) {
                Button {
                    options.textColorHex = nil
                    regeneratePreview()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 12))
                        Text("Auto")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(options.textColorHex == nil ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        options.textColorHex == nil ? Color.accentColor : Color.white.opacity(0.08),
                        in: Capsule()
                    )
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    options.textColorHex = "#FFFFFF"
                    regeneratePreview()
                } label: {
                    colorChip("#FFFFFF", label: "White", selected: options.textColorHex == "#FFFFFF")
                }
                .buttonStyle(.plain)

                Button {
                    options.textColorHex = "#000000"
                    regeneratePreview()
                } label: {
                    colorChip("#000000", label: "Black", selected: options.textColorHex == "#000000")
                }
                .buttonStyle(.plain)

                ColorPicker("", selection: Binding(
                    get: { Color(hex: options.textColorHex ?? "#FFFFFF") ?? .white },
                    set: { color in
                        options.textColorHex = colorHex(color)
                        regeneratePreview()
                    }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 30, height: 30)
            }

            sectionLabel("BACKGROUND MODE")

            Picker("Background", selection: Binding(
                get: { options.backgroundStyle },
                set: { newVal in
                    options.backgroundStyle = newVal
                    if newVal != .custom { bgKind = .gradient }
                    regeneratePreview()
                }
            )) {
                ForEach(BackgroundStyle.allCases) { style in
                    Label(style.rawValue, systemImage: style.icon).tag(style)
                }
            }
            .pickerStyle(.segmented)

            if options.backgroundStyle == .gradient || options.backgroundStyle == .custom {
                sectionLabel("GRADIENT")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Self.gradientPresets, id: \.label) { preset in
                            Button {
                                gradFrom = Color(hex: preset.from) ?? .black
                                gradTo = Color(hex: preset.to) ?? .gray
                                regeneratePreview()
                            } label: {
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: preset.from) ?? .black, Color(hex: preset.to) ?? .gray],
                                                startPoint: .top, endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(.white.opacity(0.15), lineWidth: 1)
                                        )
                                    Text(preset.label)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }

                HStack(spacing: 16) {
                    HStack(spacing: 8) {
                        Text("From")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        ColorPicker("", selection: Binding(
                            get: { gradFrom },
                            set: { gradFrom = $0; regeneratePreview() }
                        ), supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 30, height: 30)
                    }

                    HStack(spacing: 8) {
                        Text("To")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        ColorPicker("", selection: Binding(
                            get: { gradTo },
                            set: { gradTo = $0; regeneratePreview() }
                        ), supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 30, height: 30)
                    }
                }
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Elements Panel
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var elementsPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionLabel("BACKGROUND MEDIA")

            HStack(spacing: 12) {
                PhotosPicker(selection: $bgPhotoItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 15))
                        Text(bgPhotoData != nil ? "Change Image" : "Choose Image")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                PhotosPicker(selection: $bgVideoItem, matching: .videos) {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 15))
                        Text(bgVideoFrameData != nil ? "Change Video" : "Choose Video")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let mediaThumb = selectedBackgroundThumbnail {
                    ZStack(alignment: .bottomTrailing) {
                        Image(uiImage: mediaThumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        if bgKind == .video {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(.black.opacity(0.6), in: Circle())
                                .padding(3)
                        }
                    }

                    Button {
                        clearMediaBackground()
                        regeneratePreview()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()
            }
            .onChange(of: bgPhotoItem) { _, newItem in
                Task { await loadBGPhoto(from: newItem) }
            }
            .onChange(of: bgVideoItem) { _, newItem in
                Task { await loadBGVideo(from: newItem) }
            }

            sectionLabel("TEXT OVERLAYS (\(overlays.count))")

            if overlays.isEmpty {
                placeholderArea(icon: "text.badge.plus", text: "No custom text. Tap + to add text overlays.")
            } else {
                ForEach(Array(overlays.enumerated()), id: \.element.id) { idx, overlay in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(hex: overlay.colorHex) ?? .white)
                            .frame(width: 4, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(overlay.text)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                            Text("\(overlay.fontName) · \(overlay.fontWeight) · \(Int(overlay.fontSize * 100))%")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            selectedOverlayID = overlay.id
                            editingOverlayIndex = idx
                            showOverlayEditor = true
                        } label: {
                            Text("Edit")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            Button {
                showAddTextSheet = true
            } label: {
                Label("Add Text Overlay", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Reusable Pieces
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white.opacity(0.35))
            .tracking(1.2)
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>,
                           step: Double, format: @escaping (Double) -> String,
                           hint: String? = nil, onChange: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                if let h = hint {
                    Text(h)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(format(value.wrappedValue))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
                .tint(Color.accentColor)
                .onChange(of: value.wrappedValue) { _, _ in onChange?() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func visibilityToggle(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(isOn.wrappedValue ? Color.accentColor : .secondary)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 14, weight: .medium))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.accentColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func colorChip(_ hex: String, label: String, selected: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(hex: hex) ?? .gray)
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(selected ? .white : .white.opacity(0.5))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(selected ? Color.accentColor : Color.white.opacity(0.06), in: Capsule())
    }

    private func placeholderArea(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Add Text Sheet
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var addTextSheet: some View {
        AddTextSheet(text: $newOverlayText) { text in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            overlays.append(TextOverlay(text: trimmed))
            selectedOverlayID = overlays.last?.id
            newOverlayText = ""
            regeneratePreview()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Helpers
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func colorHex(_ color: Color) -> String {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func buildCustomBG() -> CustomBackground {
        var bg = CustomBackground()
        bg.kind = bgKind
        bg.solidHex = colorHex(solidColor)
        bg.gradientFromHex = colorHex(gradFrom)
        bg.gradientToHex = colorHex(gradTo)
        bg.photoData = bgPhotoData
        bg.videoFrameData = bgVideoFrameData
        return bg
    }

    private func regeneratePreviewDebounced() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            regeneratePreview()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }

    private func regeneratePreview() {
        renderTask?.cancel()
        isRendering = true
        persistCurrentOptions()

        var opts = options
        opts.backgroundStyle = .custom
        opts.customBackground = buildCustomBG()
        opts.textOverlays = overlays
        opts.accentHex = colorHex(accentColor)

        let now = Date()
        let upcomingShows = shows.filter { ($0.date ?? now) >= now }
        let snapshots = upcomingShows.map { ShowSnapshot(from: $0) }
        let name = normalizedPerformerName(performerName)
        let showsWatermark = !purchaseManager.hasRemovedWatermark

        renderTask = Task { @MainActor in
            let img = await Task.detached(priority: .userInitiated) {
                ShareImageGenerator.generatePreview(snapshots: snapshots, performerName: name, options: opts,
                                                    showsWatermark: showsWatermark,
                                                    watermarkStyle: .subtlePreview)
            }.value

            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                cachedImage = img
                isRendering = false
            }
        }
    }

    private func normalizedPerformerName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "My" || trimmed == "My Shows" {
            return "Shows"
        }
        return trimmed
    }

    private func shareImage(mode: ExportMode) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        persistCurrentOptions()

        if mode == .asIs, !purchaseManager.hasRemovedWatermark {
            showRemoveWatermarkSheet = true
            return
        }

        var opts = options
        opts.backgroundStyle = .custom
        opts.customBackground = buildCustomBG()
        opts.textOverlays = overlays
        opts.accentHex = colorHex(accentColor)

        let now = Date()
        let upcomingShows = shows.filter { ($0.date ?? now) >= now }
        let snapshots = upcomingShows.map { ShowSnapshot(from: $0) }
        let name = normalizedPerformerName(performerName)
        let showsWatermark = mode == .blurAndWatermark

        Task { @MainActor in
            isRendering = true
            let activityItem: Any
            if bgKind == .video, let bgVideoURL {
                do {
                    let videoURL = try await Task.detached(priority: .userInitiated) {
                        try await Self.exportVideoBackground(
                            sourceURL: bgVideoURL,
                            snapshots: snapshots,
                            performerName: name,
                            options: opts,
                            showsWatermark: showsWatermark
                        )
                    }.value
                    activityItem = videoURL
                } catch {
                    let rendered = await Task.detached(priority: .userInitiated) {
                        let rendered = ShareImageGenerator.generate(snapshots: snapshots, performerName: name, options: opts,
                                                                    showsWatermark: showsWatermark)
                        return mode == .blurAndWatermark ? Self.blurredExportImage(rendered) : rendered
                    }.value
                    activityItem = rendered
                }
            } else {
                let image = await Task.detached(priority: .userInitiated) {
                    let rendered = ShareImageGenerator.generate(snapshots: snapshots, performerName: name, options: opts,
                                                                showsWatermark: showsWatermark)
                    return mode == .blurAndWatermark ? Self.blurredExportImage(rendered) : rendered
                }.value
                activityItem = image
            }
            isRendering = false

            let vc = UIActivityViewController(activityItems: [activityItem], applicationActivities: nil)
            // The exported video is written to a temp file; remove it once the
            // share sheet is finished with it so exports don't accumulate.
            if let exportedVideoURL = activityItem as? URL {
                vc.completionWithItemsHandler = { _, _, _, _ in
                    try? FileManager.default.removeItem(at: exportedVideoURL)
                }
            }
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first?.rootViewController else {
                // The share sheet never gets presented, so its completion handler
                // won't run — clean up the exported temp video here instead.
                if let exportedVideoURL = activityItem as? URL {
                    try? FileManager.default.removeItem(at: exportedVideoURL)
                }
                return
            }
            var top = root
            while let p = top.presentedViewController { top = p }
            if let pop = vc.popoverPresentationController {
                pop.sourceView = top.view
                pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
                pop.permittedArrowDirections = []
            }
            top.present(vc, animated: true)
        }
    }

    nonisolated private static func blurredExportImage(_ image: UIImage) -> UIImage {
        guard let inputImage = CIImage(image: image) else { return image }
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(2.0, forKey: kCIInputRadiusKey)

        guard let outputImage = filter?.outputImage?.cropped(to: inputImage.extent),
              let cgImage = CIContext().createCGImage(outputImage, from: inputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    nonisolated private static func exportVideoBackground(
        sourceURL: URL,
        snapshots: [ShowSnapshot],
        performerName: String,
        options: ExportOptions,
        showsWatermark: Bool
    ) async throws -> URL {
        // Free exports get the same degradation as the still-image path: blur the
        // underlying video before compositing the watermark overlay. If the blur
        // pass fails, the caller falls back to a blurred still image.
        let workingSourceURL = showsWatermark ? try await blurredSourceVideo(sourceURL: sourceURL) : sourceURL
        defer {
            if workingSourceURL != sourceURL {
                try? FileManager.default.removeItem(at: workingSourceURL)
            }
        }

        let asset = AVAsset(url: workingSourceURL)
        let composition = AVMutableComposition()

        guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video,
                                                                      preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw VideoBackgroundExportError.missingVideoTrack
        }

        let duration = try await asset.load(.duration)
        let fullRange = CMTimeRange(start: .zero, duration: duration)
        try compositionVideoTrack.insertTimeRange(fullRange, of: sourceVideoTrack, at: .zero)

        for sourceAudioTrack in try await asset.loadTracks(withMediaType: .audio) {
            guard let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio,
                                                                         preferredTrackID: kCMPersistentTrackID_Invalid) else {
                continue
            }
            try? compositionAudioTrack.insertTimeRange(fullRange, of: sourceAudioTrack, at: .zero)
        }

        let renderSize = options.sizePreset.size
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = fullRange

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        layerInstruction.setTransform(try await videoFillTransform(for: sourceVideoTrack, renderSize: renderSize), at: .zero)
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]

        let parentLayer = CALayer()
        let videoLayer = CALayer()
        let overlayLayer = CALayer()
        let frame = CGRect(origin: .zero, size: renderSize)

        parentLayer.frame = frame
        videoLayer.frame = frame
        overlayLayer.frame = frame
        overlayLayer.contentsGravity = .resizeAspectFill
        overlayLayer.contentsScale = 1

        var overlayOptions = options
        overlayOptions.backgroundStyle = .custom
        overlayOptions.customBackground.kind = .gradient
        overlayOptions.customBackground.photoData = nil
        overlayOptions.customBackground.videoFrameData = nil

        let overlayImage = ShareImageGenerator.generateOverlay(
            snapshots: snapshots,
            performerName: performerName,
            options: overlayOptions,
            showsWatermark: showsWatermark
        )
        overlayLayer.contents = overlayImage.cgImage

        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SEE-ME-LIVE-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoBackgroundExportError.exportSessionUnavailable
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true

        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }

        if exportSession.status == .completed {
            return outputURL
        }

        throw exportSession.error ?? VideoBackgroundExportError.exportFailed
    }

    /// Renders a gaussian-blurred copy of the source video to a temp file.
    /// Used to degrade free exports the same way still images are blurred.
    nonisolated private static func blurredSourceVideo(sourceURL: URL) async throws -> URL {
        let asset = AVAsset(url: sourceURL)

        let videoComposition = try await AVMutableVideoComposition.videoComposition(with: asset) { request in
            let blurred = request.sourceImage
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 6])
                .cropped(to: request.sourceImage.extent)
            request.finish(with: blurred, context: nil)
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SEE-ME-LIVE-blur-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoBackgroundExportError.exportSessionUnavailable
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition

        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }

        if exportSession.status == .completed {
            return outputURL
        }

        throw exportSession.error ?? VideoBackgroundExportError.exportFailed
    }

    nonisolated private static func videoFillTransform(for track: AVAssetTrack, renderSize: CGSize) async throws -> CGAffineTransform {
        let preferredTransform = try await track.load(.preferredTransform)
        let naturalTrackSize = try await track.load(.naturalSize)
        let transformedRect = CGRect(origin: .zero, size: naturalTrackSize).applying(preferredTransform)
        let naturalSize = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))
        let scale = max(renderSize.width / max(naturalSize.width, 1), renderSize.height / max(naturalSize.height, 1))
        let scaledSize = CGSize(width: naturalSize.width * scale, height: naturalSize.height * scale)
        let tx = (renderSize.width - scaledSize.width) * 0.5 - transformedRect.minX * scale
        let ty = (renderSize.height - scaledSize.height) * 0.5 - transformedRect.minY * scale

        return preferredTransform
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: tx, y: ty))
    }

    private func loadBGPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            let processed = await Task.detached(priority: .userInitiated) {
                downscaledBackgroundData(data)
            }.value
            let thumb = await Task.detached(priority: .userInitiated) {
                UIImage(data: processed)?.preparingThumbnail(of: CGSize(width: 300, height: 300))
            }.value
            await MainActor.run {
                bgPhotoData = processed
                bgPhotoThumb = thumb
                bgVideoFrameData = nil
                bgVideoThumb = nil
                bgVideoItem = nil
                bgKind = .photo
                regeneratePreview()
            }
        }
    }

    private func loadBGVideo(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let pickedVideo = try? await item.loadTransferable(type: PickedBackgroundVideo.self) else { return }

        let processed = await Task.detached(priority: .userInitiated) {
            videoBackgroundFrameData(from: pickedVideo.url)
        }.value

        guard let processed else { return }

        let thumb = await Task.detached(priority: .userInitiated) {
            UIImage(data: processed)?.preparingThumbnail(of: CGSize(width: 300, height: 300))
        }.value

        await MainActor.run {
            bgVideoFrameData = processed
            bgVideoThumb = thumb
            if let oldURL = bgVideoURL, oldURL != pickedVideo.url {
                try? FileManager.default.removeItem(at: oldURL)
            }
            bgVideoURL = pickedVideo.url
            bgPhotoData = nil
            bgPhotoThumb = nil
            bgPhotoItem = nil
            bgKind = .video
            regeneratePreview()
        }
    }

    private func clearMediaBackground() {
        bgPhotoData = nil
        bgPhotoThumb = nil
        bgPhotoItem = nil
        bgVideoFrameData = nil
        bgVideoThumb = nil
        if let bgVideoURL {
            try? FileManager.default.removeItem(at: bgVideoURL)
        }
        bgVideoURL = nil
        bgVideoItem = nil
        bgKind = .gradient
    }

    private func restoreSavedOptions() {
        if let saved = try? JSONDecoder().decode(ExportOptions.self, from: savedOptionsData) {
            options = saved
            bgKind = saved.customBackground.kind
            solidColor = Color(hex: saved.customBackground.solidHex) ?? solidColor
            gradFrom = Color(hex: saved.customBackground.gradientFromHex) ?? gradFrom
            gradTo = Color(hex: saved.customBackground.gradientToHex) ?? gradTo
            accentColor = Color(hex: saved.accentHex) ?? accentColor
            overlays = saved.textOverlays
            bgPhotoData = saved.customBackground.photoData
            bgVideoFrameData = saved.customBackground.videoFrameData
            if let data = bgPhotoData {
                bgPhotoThumb = UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 300, height: 300))
            }
            if let data = bgVideoFrameData {
                bgVideoThumb = UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 300, height: 300))
            }
            return
        }

        if let amber = Self.gradientPresets.first(where: { $0.label == "Amber" }) {
            gradFrom = Color(hex: amber.from) ?? gradFrom
            gradTo = Color(hex: amber.to) ?? gradTo
            bgKind = .gradient
            options.backgroundStyle = .custom
        }
    }

    private func persistCurrentOptions() {
        var saved = options
        saved.backgroundStyle = .custom
        saved.customBackground = buildCustomBG()
        saved.customBackground.photoData = nil
        saved.customBackground.videoFrameData = nil
        if saved.customBackground.kind == .photo || saved.customBackground.kind == .video {
            saved.customBackground.kind = .gradient
        }
        saved.textOverlays = overlays
        saved.accentHex = colorHex(accentColor)

        if let encoded = try? JSONEncoder().encode(saved) {
            savedOptionsData = encoded
        }
    }
}

private func downscaledBackgroundData(_ data: Data, maxDimension: CGFloat = 2400) -> Data {
    guard let image = UIImage(data: data) else { return data }
    let maxSide = max(image.size.width, image.size.height)
    guard maxSide > maxDimension else { return data }

    let scale = maxDimension / maxSide
    let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.preferredRange = .standard

    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
    let resized = autoreleasepool {
        renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    return resized.jpegData(compressionQuality: 0.82) ?? data
}

private func videoBackgroundFrameData(from url: URL, maxDimension: CGFloat = 2400) -> Data? {
    let asset = AVAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)

    let time = CMTime(seconds: 0.1, preferredTimescale: 600)
    guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
        return nil
    }

    let image = UIImage(cgImage: cgImage)
    guard let data = image.jpegData(compressionQuality: 0.82) else {
        return nil
    }
    return downscaledBackgroundData(data, maxDimension: maxDimension)
}

private struct PickedBackgroundVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let sourceURL = received.file
            let fileExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)

            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return PickedBackgroundVideo(url: destinationURL)
        }
    }
}

private enum VideoBackgroundExportError: Error {
    case missingVideoTrack
    case exportSessionUnavailable
    case exportFailed
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Draggable List Overlay
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Transparent, draggable/pinchable region that represents the show list on the canvas.
/// Lets users reposition and resize the list with gestures.
private struct DraggableListOverlay: View {
    @Binding var offsetX: Double
    @Binding var offsetY: Double
    @Binding var scale: Double
    let canvasSize: CGSize
    @Binding var isActive: Bool
    let onChanged: () -> Void
    let onEnded: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var pinchScale: CGFloat = 1.0
    @GestureState private var isPinching = false

    var body: some View {
        let cx = canvasSize.width * 0.5 + CGFloat(offsetX) * canvasSize.width + dragOffset.width
        let cy = canvasSize.height * 0.5 + CGFloat(offsetY) * canvasSize.height + dragOffset.height

        // Visual region indicator
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(
                (isActive || isPinching)
                    ? Color.accentColor.opacity(0.8)
                    : Color.white.opacity(0.0),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        (isActive || isPinching)
                            ? Color.accentColor.opacity(0.05)
                            : Color.clear
                    )
            )
            .frame(
                width: max(1, canvasSize.width * 0.9 * CGFloat(scale) * pinchScale),
                height: max(1, canvasSize.height * 0.75 * CGFloat(scale) * pinchScale)
            )
            .position(x: cx, y: cy)
            .gesture(dragGesture)
            .gesture(magnifyGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
                isActive = true
                onChanged()
            }
            .onEnded { value in
                let newX = offsetX + Double(value.translation.width / canvasSize.width)
                let newY = offsetY + Double(value.translation.height / canvasSize.height)
                offsetX = max(-0.45, min(0.45, newX))
                offsetY = max(-0.45, min(0.45, newY))
                dragOffset = .zero
                isActive = false
                onEnded()
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($isPinching) { _, state, _ in state = true }
            .onChanged { value in
                pinchScale = value.magnification
            }
            .onEnded { value in
                let newScale = scale * Double(value.magnification)
                scale = max(0.3, min(2.0, newScale))
                pinchScale = 1.0
                onEnded()
            }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Draggable Text Label
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct DraggableTextLabel: View {
    @Binding var overlay: TextOverlay
    let canvasSize: CGSize
    let isSelected: Bool
    let onTap: () -> Void
    let onDragEnd: () -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        let cx = overlay.positionX * canvasSize.width
        let cy = overlay.positionY * canvasSize.height

        ZStack(alignment: .topTrailing) {
            Text(overlay.text)
                .font(resolvedFont)
                .foregroundStyle(Color(hex: overlay.colorHex) ?? .white)
                .shadow(color: .black.opacity(overlay.shadowEnabled ? overlay.shadowOpacity : 0.35), radius: 4, y: 2)
                .rotationEffect(.degrees(overlay.rotation))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(isSelected ? 0.4 : 0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            isSelected ? Color.accentColor : Color.white.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

            if isSelected {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, .red)
                }
                .offset(x: 8, y: -8)
            }
        }
        .position(x: cx + dragOffset.width, y: cy + dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in dragOffset = value.translation }
                .onEnded { value in
                    guard canvasSize.width > 0, canvasSize.height > 0 else {
                        dragOffset = .zero
                        return
                    }
                    let newX = (cx + value.translation.width) / canvasSize.width
                    let newY = (cy + value.translation.height) / canvasSize.height
                    overlay.positionX = max(0.05, min(0.95, newX))
                    overlay.positionY = max(0.05, min(0.95, newY))
                    dragOffset = .zero
                    onDragEnd()
                }
        )
        .onTapGesture { onTap() }
    }

    private var resolvedFont: Font {
        let size = max(1, overlay.fontSize * canvasSize.width * 0.4)
        let weight: Font.Weight = {
            switch overlay.fontWeight.lowercased() {
            case "ultralight": return .ultraLight
            case "thin": return .thin
            case "light": return .light
            case "regular": return .regular
            case "medium": return .medium
            case "semibold": return .semibold
            case "bold": return .bold
            case "heavy": return .heavy
            case "black": return .black
            default: return .bold
            }
        }()
        if overlay.fontName == "System" {
            return .system(size: size, weight: weight)
        } else {
            return .custom(overlay.fontName, size: size)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Add Text Sheet
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct AddTextSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let onAdd: (String) -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What should it say?")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("Your name, tagline, URL…", text: $text)
                        .font(.system(size: 20, weight: .medium))
                        .padding(16)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .focused($isFocused)
                }

                Button {
                    onAdd(text)
                    dismiss()
                } label: {
                    Text("Add to Flyer")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            text.trimmingCharacters(in: .whitespaces).isEmpty ? Color(.systemGray4) : Color.accentColor,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .foregroundStyle(.white)
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Add Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { isFocused = true }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Overlay Editor Sheet (Full Text Customization)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct OverlayEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var overlay: TextOverlay
    let presetColors: [String]
    let fontWeights: [(weight: String, label: String)]
    let fontFamilies: [(name: String, label: String, preview: String)]
    let onUpdate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    livePreview
                    editableText
                    fontPicker
                    weightPicker
                    sizeSlider
                    colorPicker
                    effectsControls
                    positionControls
                    deleteButton
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var livePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.85), Color.gray.opacity(0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            Text(overlay.text.isEmpty ? "Preview" : overlay.text)
                .font(previewFont)
                .foregroundStyle(Color(hex: overlay.colorHex) ?? .white)
                .shadow(color: overlay.shadowEnabled ? .black.opacity(overlay.shadowOpacity) : .clear, radius: 4, y: 2)
                .rotationEffect(.degrees(overlay.rotation))
                .padding()
        }
        .frame(height: 110)
    }

    private var previewFont: Font {
        let weight = resolveWeight(overlay.fontWeight)
        if overlay.fontName == "System" {
            return .system(size: 30, weight: weight)
        } else {
            return .custom(overlay.fontName, size: 30)
        }
    }

    private var editableText: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("TEXT")
            TextField("Your text", text: $overlay.text)
                .font(.system(size: 17))
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onChange(of: overlay.text) { onUpdate() }
        }
    }

    private var fontPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("FONT")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(fontFamilies, id: \.name) { font in
                        let isSel = overlay.fontName == font.name
                        Button {
                            overlay.fontName = font.name
                            onUpdate()
                        } label: {
                            VStack(spacing: 4) {
                                Text(font.preview)
                                    .font(font.name == "System" ? .system(size: 18, weight: .bold) : .custom(font.name, size: 18))
                                    .frame(width: 44, height: 36)
                                Text(font.label)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(isSel ? .white : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                isSel ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var weightPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("WEIGHT")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(fontWeights, id: \.weight) { w in
                        let isSel = overlay.fontWeight == w.weight
                        Button {
                            overlay.fontWeight = w.weight
                            onUpdate()
                        } label: {
                            Text(w.label)
                                .font(.system(size: 12, weight: isSel ? .bold : .medium))
                                .foregroundStyle(isSel ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    isSel ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var sizeSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("SIZE")
                Spacer()
                Text("\(Int(overlay.fontSize * 100))%")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Image(systemName: "textformat.size.smaller")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Slider(value: $overlay.fontSize, in: 0.03...0.25, step: 0.005)
                    .tint(Color.accentColor)
                    .onChange(of: overlay.fontSize) { onUpdate() }
                Image(systemName: "textformat.size.larger")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("COLOR")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                ForEach(presetColors, id: \.self) { hex in
                    let isSel = overlay.colorHex == hex
                    Button {
                        overlay.colorHex = hex
                        onUpdate()
                    } label: {
                        Circle()
                            .fill(Color(hex: hex) ?? .gray)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                            .overlay(isSel ? Circle().stroke(Color.accentColor, lineWidth: 3).padding(-3) : nil)
                    }
                    .buttonStyle(.plain)
                }

                ColorPicker("", selection: Binding(
                    get: { Color(hex: overlay.colorHex) ?? .white },
                    set: { color in
                        let uiColor = UIColor(color)
                        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
                        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
                        overlay.colorHex = String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
                        onUpdate()
                    }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 34, height: 34)
            }
        }
    }

    private var effectsControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("EFFECTS")

            HStack {
                Image(systemName: "shadow")
                    .font(.system(size: 15))
                    .foregroundStyle(overlay.shadowEnabled ? Color.accentColor : .secondary)
                    .frame(width: 24)
                Text("Drop Shadow")
                    .font(.system(size: 14))
                Spacer()
                Toggle("", isOn: $overlay.shadowEnabled)
                    .labelsHidden()
                    .tint(Color.accentColor)
                    .onChange(of: overlay.shadowEnabled) { onUpdate() }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            if overlay.shadowEnabled {
                HStack {
                    Text("Intensity")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Slider(value: $overlay.shadowOpacity, in: 0.1...1.0)
                        .tint(Color.accentColor)
                        .onChange(of: overlay.shadowOpacity) { onUpdate() }
                    Text("\(Int(overlay.shadowOpacity * 100))%")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
                .padding(.horizontal, 4)
            }

            HStack {
                Image(systemName: "rotate.right")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("Rotation")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Slider(value: $overlay.rotation, in: -45...45, step: 1)
                    .tint(Color.accentColor)
                    .onChange(of: overlay.rotation) { onUpdate() }
                Text("\(Int(overlay.rotation))°")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }

    private var positionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("POSITION")
            Text("Drag the text on the preview, or use quick placement:")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                positionButton("Top Left", x: 0.2, y: 0.08)
                positionButton("Top Center", x: 0.5, y: 0.08)
                positionButton("Top Right", x: 0.8, y: 0.08)
            }
            HStack(spacing: 8) {
                positionButton("Mid Left", x: 0.2, y: 0.5)
                positionButton("Center", x: 0.5, y: 0.5)
                positionButton("Mid Right", x: 0.8, y: 0.5)
            }
            HStack(spacing: 8) {
                positionButton("Bot Left", x: 0.2, y: 0.92)
                positionButton("Bottom", x: 0.5, y: 0.92)
                positionButton("Bot Right", x: 0.8, y: 0.92)
            }
        }
    }

    private func positionButton(_ label: String, x: Double, y: Double) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                overlay.positionX = x
                overlay.positionY = y
                onUpdate()
            }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onDelete()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                Text("Remove Text")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.secondary)
            .tracking(1)
    }

    private func resolveWeight(_ w: String) -> Font.Weight {
        switch w.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .bold
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Remove Watermark
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct RemoveWatermarkSheet: View {
    @ObservedObject var purchaseManager: PurchaseManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: purchaseManager.hasRemovedWatermark ? "checkmark.seal.fill" : "drop.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(purchaseManager.hasRemovedWatermark ? Color.green : Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(purchaseManager.hasRemovedWatermark ? "HD Exports Unlocked" : "Export in HD")
                        .font(.system(size: 20, weight: .bold))
                    Text("Remove the watermark and preview blur with a one-time purchase.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }

            if let message = purchaseManager.statusMessage {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button {
                Task {
                    if purchaseManager.canRetryProductLoad {
                        await purchaseManager.loadProducts()
                    } else {
                        await purchaseManager.purchaseRemoveWatermark()
                    }
                }
            } label: {
                HStack {
                    if purchaseManager.isPurchasing || purchaseManager.isLoadingProducts {
                        ProgressView()
                    }

                    Text(primaryButtonTitle)
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(primaryButtonEnabled ? Color.accentColor : Color.gray, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!primaryButtonEnabled)

            Button {
                Task { await purchaseManager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .disabled(purchaseManager.isPurchasing)
        }
        .padding(22)
        .task {
            if purchaseManager.removeWatermarkProduct == nil {
                await purchaseManager.loadProducts()
            } else {
                await purchaseManager.checkCurrentEntitlements()
            }
        }
    }

    private var primaryButtonTitle: String {
        if purchaseManager.hasRemovedWatermark {
            return "Purchased"
        }

        if purchaseManager.isPurchasePending {
            return "Pending Approval"
        }

        if purchaseManager.isLoadingProducts {
            return "Loading..."
        }

        if purchaseManager.removeWatermarkProduct == nil {
            return "Try Again"
        }

        if let price = purchaseManager.removeWatermarkPriceText {
            return "Remove Watermark \(price)"
        }

        return "Remove Watermark"
    }

    private var primaryButtonEnabled: Bool {
        !purchaseManager.hasRemovedWatermark &&
        !purchaseManager.isPurchasePending &&
        !purchaseManager.isLoadingProducts &&
        !purchaseManager.isPurchasing &&
        (purchaseManager.removeWatermarkProduct != nil || purchaseManager.canRetryProductLoad)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Screen Capture Protection
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct ScreenCaptureProtectionOverlay: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.24)

                VStack(spacing: 6) {
                    Text("Preview protected")
                        .font(.system(size: max(16, geo.size.width * 0.04), weight: .bold))
                    Text("Remove watermark for clean exports")
                        .font(.system(size: max(12, geo.size.width * 0.028), weight: .semibold))
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .allowsHitTesting(false)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Button Style
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    ShareImageEditorView(
        shows: [],
        performerName: "Taylor Drew"
    )
}
