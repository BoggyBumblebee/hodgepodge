import Foundation

protocol BrewfileDocumentLoading {
    func loadDocument(at fileURL: URL) throws -> BrewfileDocument
}

struct BrewfileDocumentLoader: BrewfileDocumentLoading {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func loadDocument(at fileURL: URL) throws -> BrewfileDocument {
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = contents.components(separatedBy: .newlines)
        let parsedLines = lines.enumerated().compactMap { index, line in
            parseLine(line, lineNumber: index + 1)
        }

        let modifiedAt = try? fileManager.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date

        return BrewfileDocument(
            fileURL: fileURL,
            lines: parsedLines,
            loadedAt: Date(),
            modifiedAt: modifiedAt ?? nil
        )
    }

    private func parseLine(_ rawLine: String, lineNumber: Int) -> BrewfileLine? {
        let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else {
            return nil
        }

        if let comment = parseComment(trimmedLine) {
            return makeLine(
                lineNumber: lineNumber,
                category: .comment,
                rawLine: rawLine,
                commentText: comment
            )
        }

        if let entry = parseEntry(from: rawLine, lineNumber: lineNumber) {
            return makeLine(
                lineNumber: lineNumber,
                category: .entry,
                entry: entry,
                rawLine: rawLine
            )
        }

        return makeLine(
            lineNumber: lineNumber,
            category: .unknown,
            rawLine: rawLine
        )
    }

    private func makeLine(
        lineNumber: Int,
        category: BrewfileLineCategory,
        entry: BrewfileEntry? = nil,
        rawLine: String,
        commentText: String? = nil
    ) -> BrewfileLine {
        BrewfileLine(
            lineNumber: lineNumber,
            category: category,
            entry: entry,
            rawLine: rawLine,
            commentText: commentText
        )
    }

    private func parseComment(_ trimmedLine: String) -> String? {
        guard trimmedLine.hasPrefix("#") else {
            return nil
        }

        return trimmedLine
            .dropFirst()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseEntry(from rawLine: String, lineNumber: Int) -> BrewfileEntry? {
        let lineWithoutInlineComment: String
        let inlineComment: String?
        (lineWithoutInlineComment, inlineComment) = splitInlineComment(in: rawLine)

        let trimmedLine = lineWithoutInlineComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else {
            return nil
        }

        let keyword = trimmedLine.prefix { $0.isLetter || $0 == "_" }
        guard !keyword.isEmpty else {
            return nil
        }

        let kind = BrewfileEntryKind(rawValue: String(keyword)) ?? .unknown
        guard kind != .unknown else {
            return nil
        }

        guard let nameRange = firstQuotedStringRange(in: trimmedLine) else {
            return nil
        }

        let name = String(trimmedLine[nameRange])
        let suffixStartIndex = nameRange.upperBound < trimmedLine.endIndex
            ? trimmedLine.index(after: nameRange.upperBound)
            : trimmedLine.endIndex
        let suffix = trimmedLine[suffixStartIndex...]
        let options = parseOptions(from: String(suffix))

        return BrewfileEntry(
            lineNumber: lineNumber,
            kind: kind,
            name: name,
            rawLine: rawLine,
            options: options,
            inlineComment: inlineComment
        )
    }

    private func splitInlineComment(in rawLine: String) -> (String, String?) {
        var inSingleQuotes = false
        var inDoubleQuotes = false
        var previousCharacter: Character?

        for (index, character) in rawLine.enumerated() {
            switch character {
            case "'" where !inDoubleQuotes && previousCharacter != "\\":
                inSingleQuotes.toggle()
            case "\"" where !inSingleQuotes && previousCharacter != "\\":
                inDoubleQuotes.toggle()
            case "#" where !inSingleQuotes && !inDoubleQuotes:
                let splitIndex = rawLine.index(rawLine.startIndex, offsetBy: index)
                let line = String(rawLine[..<splitIndex])
                let comment = String(rawLine[rawLine.index(after: splitIndex)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (line, comment.isEmpty ? nil : comment)
            default:
                break
            }

            previousCharacter = character
        }

        return (rawLine, nil)
    }

    private func firstQuotedStringRange(in line: String) -> Range<String.Index>? {
        var quoteCharacter: Character?
        var startIndex: String.Index?
        var previousCharacter: Character?
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]

            if quoteCharacter == nil {
                if (character == "\"" || character == "'"), previousCharacter != "\\" {
                    quoteCharacter = character
                    startIndex = line.index(after: index)
                }
            } else if character == quoteCharacter,
                      previousCharacter != "\\",
                      let startIndex {
                return startIndex..<index
            }

            previousCharacter = character
            index = line.index(after: index)
        }

        return nil
    }

    private func parseOptions(from suffix: String) -> [String: String] {
        let trimmed = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return [:]
        }

        let optionText = trimmed.hasPrefix(",")
            ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            : trimmed

        guard !optionText.isEmpty else {
            return [:]
        }

        return splitTopLevelCSV(optionText).reduce(into: [:]) { partialResult, component in
            let trimmedComponent = component.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedComponent.isEmpty else {
                return
            }

            if let separatorIndex = firstTopLevelColon(in: trimmedComponent) {
                let key = trimmedComponent[..<separatorIndex]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let value = trimmedComponent[trimmedComponent.index(after: separatorIndex)...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                partialResult[key] = value
            } else {
                partialResult["value_\(partialResult.count + 1)"] = trimmedComponent
            }
        }
    }

    private func splitTopLevelCSV(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""

        scanTopLevel(in: text) { _, character, state in
            if character == ",", state.isAtTopLevel {
                parts.append(current)
                current.removeAll(keepingCapacity: true)
                return false
            }

            current.append(character)
            return false
        }

        if !current.isEmpty {
            parts.append(current)
        }

        return parts
    }

    private func firstTopLevelColon(in text: String) -> String.Index? {
        var separatorIndex: String.Index?

        scanTopLevel(in: text) { index, character, state in
            if character == ":", state.isAtTopLevel {
                separatorIndex = index
                return true
            }

            return false
        }

        return separatorIndex
    }

    private func scanTopLevel(
        in text: String,
        _ visitor: (String.Index, Character, TopLevelParserState) -> Bool
    ) {
        var state = TopLevelParserState()

        for index in text.indices {
            let character = text[index]
            state.consume(character)

            if visitor(index, character, state) {
                return
            }
        }
    }
}

private struct TopLevelParserState {
    private(set) var inSingleQuotes = false
    private(set) var inDoubleQuotes = false
    private(set) var bracketDepth = 0
    private(set) var braceDepth = 0
    private(set) var parenthesisDepth = 0
    private var previousCharacter: Character?

    var isAtTopLevel: Bool {
        !inSingleQuotes &&
        !inDoubleQuotes &&
        bracketDepth == 0 &&
        braceDepth == 0 &&
        parenthesisDepth == 0
    }

    mutating func consume(_ character: Character) {
        switch character {
        case "'" where !inDoubleQuotes && previousCharacter != "\\":
            inSingleQuotes.toggle()
        case "\"" where !inSingleQuotes && previousCharacter != "\\":
            inDoubleQuotes.toggle()
        case "[" where !inSingleQuotes && !inDoubleQuotes:
            bracketDepth += 1
        case "]" where !inSingleQuotes && !inDoubleQuotes:
            bracketDepth = max(0, bracketDepth - 1)
        case "{" where !inSingleQuotes && !inDoubleQuotes:
            braceDepth += 1
        case "}" where !inSingleQuotes && !inDoubleQuotes:
            braceDepth = max(0, braceDepth - 1)
        case "(" where !inSingleQuotes && !inDoubleQuotes:
            parenthesisDepth += 1
        case ")" where !inSingleQuotes && !inDoubleQuotes:
            parenthesisDepth = max(0, parenthesisDepth - 1)
        default:
            break
        }

        previousCharacter = character
    }
}
