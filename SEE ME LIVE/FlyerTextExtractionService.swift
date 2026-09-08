//
//  FlyerTextExtractionService.swift
//  SEE ME LIVE
//
//  Created by Taylor Drew on 9/8/26.
//

import Foundation
import UIKit
import Vision

struct FlyerShowDetails: Equatable {
    var title: String?
    var venue: String?
    var date: Date?

    var hasValues: Bool {
        title != nil || venue != nil || date != nil
    }
}

enum FlyerTextExtractionError: LocalizedError {
    case invalidImage
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The selected flyer could not be read as an image."
        case .recognitionFailed:
            return "Text could not be extracted from this flyer."
        }
    }
}

struct FlyerTextExtractionService {
    static func extractShowDetails(from imageData: Data) async throws -> FlyerShowDetails {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            throw FlyerTextExtractionError.invalidImage
        }

        let lines = try await recognizedLines(from: cgImage)
        return parseShowDetails(from: lines)
    }

    static func parseShowDetails(from lines: [String], now: Date = Date()) -> FlyerShowDetails {
        let cleanedLines = lines
            .map { cleanLine($0) }
            .filter { !$0.isEmpty }

        guard !cleanedLines.isEmpty else {
            return FlyerShowDetails()
        }

        let date = detectDate(in: cleanedLines.joined(separator: "\n"), now: now)
        let title = detectTitle(in: cleanedLines)
        let venue = detectVenue(in: cleanedLines, excluding: [title])

        return FlyerShowDetails(title: title, venue: venue, date: date)
    }

    private static func recognizedLines(from cgImage: CGImage) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            var recognitionResult: Result<[String], Error>?

            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    recognitionResult = .failure(error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    recognitionResult = .failure(FlyerTextExtractionError.recognitionFailed)
                    return
                }

                let lines = observations
                    .compactMap { observation -> (text: String, box: CGRect)? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return (candidate.string, observation.boundingBox)
                    }
                    .sorted { lhs, rhs in
                        let yDelta = abs(lhs.box.midY - rhs.box.midY)
                        if yDelta > 0.025 {
                            return lhs.box.midY > rhs.box.midY
                        }
                        return lhs.box.minX < rhs.box.minX
                    }
                    .map(\.text)

                recognitionResult = .success(lines)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try handler.perform([request])

            switch recognitionResult {
            case .success(let lines):
                return lines
            case .failure(let error):
                throw error
            case .none:
                throw FlyerTextExtractionError.recognitionFailed
            }
        }.value
    }

    private static func detectTitle(in lines: [String]) -> String? {
        lines.first { line in
            !isLikelyDateOrTime(line) &&
            !isLikelyVenueCue(line) &&
            !isLikelyTicketOrPromoLine(line) &&
            line.count >= 3
        }
    }

    private static func detectVenue(in lines: [String], excluding excludedValues: [String?]) -> String? {
        let excluded = Set(excludedValues.compactMap { $0?.lowercased() })

        for line in lines {
            let lowercased = line.lowercased()
            if lowercased.hasPrefix("at ") || lowercased.hasPrefix("@ ") {
                let venue = line.dropFirst(lowercased.hasPrefix("@ ") ? 2 : 3)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !venue.isEmpty {
                    return venue
                }
            }

            if lowercased.hasPrefix("venue:") {
                let venue = line.dropFirst("venue:".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !venue.isEmpty {
                    return venue
                }
            }
        }

        return lines.first { line in
            let lowercased = line.lowercased()
            return !excluded.contains(lowercased) &&
            !isLikelyDateOrTime(line) &&
            !isLikelyTicketOrPromoLine(line) &&
            (
                lowercased.contains("club") ||
                lowercased.contains("theater") ||
                lowercased.contains("theatre") ||
                lowercased.contains("room") ||
                lowercased.contains("bar") ||
                lowercased.contains("hall") ||
                lowercased.contains("lounge") ||
                lowercased.contains("arena") ||
                lowercased.contains("center")
            )
        }
    }

    private static func detectDate(in text: String, now: Date) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        return matches.first(where: { $0.date != nil })?.date.map { normalizeDetectedDate($0, now: now) }
    }

    private static func normalizeDetectedDate(_ detectedDate: Date, now: Date) -> Date {
        let calendar = Calendar.current
        let detectedComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: detectedDate)
        let currentYear = calendar.component(.year, from: now)

        guard detectedComponents.year == 2000,
              detectedComponents.month != nil,
              detectedComponents.day != nil else {
            return detectedDate
        }

        var components = detectedComponents
        components.year = currentYear

        if let thisYearDate = calendar.date(from: components),
           thisYearDate >= calendar.startOfDay(for: now) {
            return thisYearDate
        }

        components.year = currentYear + 1
        return calendar.date(from: components) ?? detectedDate
    }

    private static func isLikelyVenueCue(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return lowercased.hasPrefix("at ") ||
        lowercased.hasPrefix("@ ") ||
        lowercased.hasPrefix("venue:")
    }

    private static func isLikelyDateOrTime(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        let dateTokens = [
            "jan", "feb", "mar", "apr", "may", "jun",
            "jul", "aug", "sep", "sept", "oct", "nov", "dec",
            "mon", "tue", "wed", "thu", "fri", "sat", "sun",
            "pm", "am", "/"
        ]

        return dateTokens.contains { lowercased.contains($0) } ||
        lowercased.range(of: #"\b\d{1,2}:\d{2}\b"#, options: .regularExpression) != nil
    }

    private static func isLikelyTicketOrPromoLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return lowercased.contains("ticket") ||
        lowercased.contains("rsvp") ||
        lowercased.contains("doors") ||
        lowercased.contains("follow") ||
        lowercased.contains("instagram") ||
        lowercased.contains("facebook") ||
        lowercased.contains("www.") ||
        lowercased.contains("http")
    }

    private static func cleanLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
