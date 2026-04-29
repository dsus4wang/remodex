// FILE: TurnMarkdownModels.swift
// Purpose: Markdown render profile and assistant text formatting helpers.
// Layer: Model
// Exports: MarkdownRenderProfile, SkillReferenceReplacementStyle
// Depends on: Foundation

import Foundation

enum MarkdownRenderProfile {
    case assistantProse
    case fileChangeSystem
}

extension MarkdownRenderProfile {
    var cacheKey: String {
        switch self {
        case .assistantProse:
            return "assistantProse"
        case .fileChangeSystem:
            return "fileChangeSystem"
        }
    }
}

enum SkillReferenceReplacementStyle {
    case mentionToken
    case displayName
}

enum TimelineTextSelectionPolicy {
    static let allowsInlineMessageSelection = true
    static let allowsScrollContainerSelection = false
}

struct TimelineMarkdownSegment: Identifiable, Equatable {
    enum Kind: Equatable {
        case markdown
        case codeBlock
    }

    let id: String
    let kind: Kind
    let text: String
    let codeLanguage: String?
}

enum TimelineMarkdownSegmenter {
    private static let cache = BoundedCache<String, [TimelineMarkdownSegment]>(maxEntries: 256)

    static func segments(in source: String) -> [TimelineMarkdownSegment] {
        let cacheKey = TurnTextCacheKey.stableKey(namespace: "timeline-markdown-segments", text: source)
        return cache.getOrSet(cacheKey) {
            parseSegments(in: source)
        }
    }

    static func reset() {
        cache.removeAll()
    }

    private static func parseSegments(in source: String) -> [TimelineMarkdownSegment] {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var segments: [TimelineMarkdownSegment] = []
        var markdownLines: [String] = []
        var codeLines: [String] = []
        var codeLanguage: String?
        var isInsideCodeBlock = false
        var segmentStartLine = 0

        func appendSegment(kind: TimelineMarkdownSegment.Kind, text: String, language: String?, startLine: Int) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            segments.append(
                TimelineMarkdownSegment(
                    id: "\(kind)-\(startLine)-\(segments.count)-\(trimmed.utf8.count)",
                    kind: kind,
                    text: trimmed,
                    codeLanguage: language
                )
            )
        }

        func flushMarkdown(at lineIndex: Int) {
            appendSegment(
                kind: .markdown,
                text: markdownLines.joined(separator: "\n"),
                language: nil,
                startLine: segmentStartLine
            )
            markdownLines.removeAll(keepingCapacity: true)
            segmentStartLine = lineIndex
        }

        func flushCode(at lineIndex: Int) {
            appendSegment(
                kind: .codeBlock,
                text: codeLines.joined(separator: "\n"),
                language: codeLanguage,
                startLine: segmentStartLine
            )
            codeLines.removeAll(keepingCapacity: true)
            codeLanguage = nil
            segmentStartLine = lineIndex
        }

        for (lineIndex, line) in lines.enumerated() {
            if line.hasPrefix("```") {
                if isInsideCodeBlock {
                    flushCode(at: lineIndex + 1)
                    isInsideCodeBlock = false
                } else {
                    flushMarkdown(at: lineIndex)
                    let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                    codeLanguage = language.isEmpty ? nil : language
                    isInsideCodeBlock = true
                    segmentStartLine = lineIndex
                }
                continue
            }

            if isInsideCodeBlock {
                codeLines.append(line)
            } else {
                markdownLines.append(line)
            }
        }

        if isInsideCodeBlock {
            flushCode(at: lines.count)
        } else {
            flushMarkdown(at: lines.count)
        }

        return segments
    }
}
