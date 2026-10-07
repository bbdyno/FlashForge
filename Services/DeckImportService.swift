//
//  DeckImportService.swift
//  FlashForge
//

import Compression
import Foundation
import SQLite3

struct ImportedDeck: Equatable, Sendable {
    struct Card: Equatable, Sendable {
        let front: String
        let back: String
        let note: String
    }

    let title: String
    var cards: [Card]
}

enum DeckImportError: LocalizedError, Equatable {
    case unreadable
    case empty
    case unsupportedAnkiFormat

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return FlashForgeStrings.Import.Error.unreadable
        case .empty:
            return FlashForgeStrings.Import.Error.empty
        case .unsupportedAnkiFormat:
            return FlashForgeStrings.Import.Error.ankiFormat
        }
    }
}

// Reads other apps' decks as text-only cards. Scheduling and media are not
// carried over: every imported card starts as new.
enum DeckImportService {
    static func importFile(at url: URL) throws -> [ImportedDeck] {
        guard let data = try? Data(contentsOf: url) else {
            throw DeckImportError.unreadable
        }
        let name = url.deletingPathExtension().lastPathComponent
        switch url.pathExtension.lowercased() {
        case "apkg", "colpkg":
            return try AnkiPackageReader.decks(from: data, fallbackTitle: name)
        default:
            return [try DelimitedTextReader.deck(from: data, title: name)]
        }
    }
}

// MARK: - CSV / TSV

enum DelimitedTextReader {
    static func deck(from data: Data, title: String) throws -> ImportedDeck {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            throw DeckImportError.unreadable
        }
        let cards = cards(from: text)
        guard !cards.isEmpty else {
            throw DeckImportError.empty
        }
        return ImportedDeck(title: title, cards: cards)
    }

    static func cards(from text: String) -> [ImportedDeck.Card] {
        // Anki's text export starts with "#key:value" lines.
        let body = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}"))
        let content = body.split(separator: "\n", omittingEmptySubsequences: false)
            .drop { $0.hasPrefix("#") }
            .joined(separator: "\n")

        var rows = parse(content, delimiter: delimiter(for: content))
            .map { $0.map { MarkupStripper.plainText($0) } }
            .filter { $0.contains { !$0.isEmpty } }
        if let first = rows.first, isHeader(first) {
            rows.removeFirst()
        }

        return rows.compactMap { row in
            guard row.count >= 2, !row[0].isEmpty, !row[1].isEmpty else {
                return nil
            }
            let note = row.dropFirst(2).filter { !$0.isEmpty }.joined(separator: "\n")
            return ImportedDeck.Card(front: row[0], back: row[1], note: note)
        }
    }

    private static func delimiter(for text: String) -> Character {
        let sample = text.prefix(4000)
        let candidates: [Character] = ["\t", ",", ";"]
        return candidates.max { lhs, rhs in
            sample.filter { $0 == lhs }.count < sample.filter { $0 == rhs }.count
        } ?? ","
    }

    private static func isHeader(_ row: [String]) -> Bool {
        let names: Set<String> = ["front", "back", "question", "answer", "term", "definition", "앞면", "뒷면", "질문", "답"]
        return row.prefix(2).allSatisfy { names.contains($0.lowercased()) }
    }

    // RFC 4180 quoting: fields may be wrapped in quotes, contain the delimiter
    // or newlines, and escape a quote by doubling it.
    static func parse(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var iterator = text.makeIterator()
        var pending = iterator.next()

        while let character = pending {
            pending = iterator.next()
            if isQuoted {
                if character == "\"" {
                    if pending == "\"" {
                        field.append("\"")
                        pending = iterator.next()
                    } else {
                        isQuoted = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"", field.isEmpty {
                isQuoted = true
            } else if character == delimiter {
                row.append(field)
                field = ""
            } else if character == "\n" {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(character)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}

enum MarkupStripper {
    static func plainText(_ value: String) -> String {
        var text = value
        guard text.contains("<") || text.contains("&") || text.contains("[sound:") else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        text = text.replacingOccurrences(of: "<br\\s*/?>|</div>|</p>|</li>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\[sound:[^\\]]*\\]", with: "", options: .regularExpression)
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'"]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Anki packages

enum AnkiPackageReader {
    static func decks(from data: Data, fallbackTitle: String) throws -> [ImportedDeck] {
        let archive = try ZipArchiveReader(data: data)
        // Anki 2.1.50+ writes a zstd-compressed "collection.anki21b" unless the
        // export is made compatible with older versions.
        guard let name = ["collection.anki21", "collection.anki2"].first(where: archive.contains) else {
            throw archive.contains("collection.anki21b") ? DeckImportError.unsupportedAnkiFormat : DeckImportError.unreadable
        }
        let database = try archive.data(named: name)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("anki-\(UUID().uuidString).sqlite")
        try database.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var handle: OpaquePointer?
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let handle else {
            throw DeckImportError.unreadable
        }
        defer { sqlite3_close(handle) }

        let deckNames = deckNames(in: handle)
        var decksByID: [Int64: ImportedDeck] = [:]
        var order: [Int64] = []
        var seenNotes = Set<Int64>()

        let query = "SELECT n.id, c.did, n.flds FROM cards c JOIN notes n ON n.id = c.nid ORDER BY c.did, c.due, n.id"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, query, -1, &statement, nil) == SQLITE_OK else {
            throw DeckImportError.unreadable
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            let noteID = sqlite3_column_int64(statement, 0)
            let deckID = sqlite3_column_int64(statement, 1)
            // A note can produce several cards (e.g. reversed); it is imported once.
            guard seenNotes.insert(noteID).inserted, let raw = sqlite3_column_text(statement, 2) else {
                continue
            }
            let fields = String(cString: raw).components(separatedBy: "\u{1F}").map(MarkupStripper.plainText)
            guard fields.count >= 2, !fields[0].isEmpty, !fields[1].isEmpty else {
                continue
            }
            let note = fields.dropFirst(2).filter { !$0.isEmpty }.joined(separator: "\n")
            if decksByID[deckID] == nil {
                order.append(deckID)
                decksByID[deckID] = ImportedDeck(title: deckNames[deckID] ?? fallbackTitle, cards: [])
            }
            decksByID[deckID]?.cards.append(ImportedDeck.Card(front: fields[0], back: fields[1], note: note))
        }

        let decks = order.compactMap { decksByID[$0] }
        guard !decks.isEmpty else {
            throw DeckImportError.empty
        }
        return decks
    }

    // Deck names live in a JSON blob in `col.decks` (older schema) or in a
    // `decks` table (newer schema).
    private static func deckNames(in handle: OpaquePointer) -> [Int64: String] {
        var names: [Int64: String] = [:]
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(handle, "SELECT decks FROM col", -1, &statement, nil) == SQLITE_OK,
           sqlite3_step(statement) == SQLITE_ROW,
           let raw = sqlite3_column_text(statement, 0),
           let json = try? JSONSerialization.jsonObject(with: Data(String(cString: raw).utf8)) as? [String: Any] {
            for (key, value) in json {
                if let id = Int64(key), let name = (value as? [String: Any])?["name"] as? String {
                    names[id] = displayName(name)
                }
            }
        }
        sqlite3_finalize(statement)

        statement = nil
        if names.isEmpty, sqlite3_prepare_v2(handle, "SELECT id, name FROM decks", -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let raw = sqlite3_column_text(statement, 1) {
                    names[sqlite3_column_int64(statement, 0)] = displayName(String(cString: raw))
                }
            }
        }
        sqlite3_finalize(statement)
        return names
    }

    // "Parent::Child" (or the newer \u{1F} separator) becomes "Parent / Child".
    private static func displayName(_ name: String) -> String {
        name.replacingOccurrences(of: "\u{1F}", with: "::")
            .components(separatedBy: "::")
            .joined(separator: " / ")
    }
}

// The small part of ZIP that .apkg files use: stored or deflated entries
// located through the central directory.
struct ZipArchiveReader {
    private struct Entry {
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    private let data: Data
    private var entries: [String: Entry] = [:]

    init(data: Data) throws {
        self.data = data
        let bytes = [UInt8](data)
        guard bytes.count >= 22 else {
            throw DeckImportError.unreadable
        }

        var end = bytes.count - 22
        while end >= 0, !(bytes[end] == 0x50 && bytes[end + 1] == 0x4B && bytes[end + 2] == 0x05 && bytes[end + 3] == 0x06) {
            end -= 1
        }
        guard end >= 0 else {
            throw DeckImportError.unreadable
        }

        let count = Int(Self.uint16(bytes, end + 10))
        var offset = Int(Self.uint32(bytes, end + 16))
        for _ in 0 ..< count {
            guard offset + 46 <= bytes.count, Self.uint32(bytes, offset) == 0x0201_4B50 else {
                throw DeckImportError.unreadable
            }
            let nameLength = Int(Self.uint16(bytes, offset + 28))
            let extraLength = Int(Self.uint16(bytes, offset + 30))
            let commentLength = Int(Self.uint16(bytes, offset + 32))
            guard offset + 46 + nameLength <= bytes.count else {
                throw DeckImportError.unreadable
            }
            let name = String(decoding: bytes[(offset + 46) ..< (offset + 46 + nameLength)], as: UTF8.self)
            entries[name] = Entry(
                method: Self.uint16(bytes, offset + 10),
                compressedSize: Int(Self.uint32(bytes, offset + 20)),
                uncompressedSize: Int(Self.uint32(bytes, offset + 24)),
                localHeaderOffset: Int(Self.uint32(bytes, offset + 42))
            )
            offset += 46 + nameLength + extraLength + commentLength
        }
    }

    func contains(_ name: String) -> Bool {
        entries[name] != nil
    }

    func data(named name: String) throws -> Data {
        guard let entry = entries[name] else {
            throw DeckImportError.unreadable
        }
        let bytes = [UInt8](data)
        let header = entry.localHeaderOffset
        guard header + 30 <= bytes.count, Self.uint32(bytes, header) == 0x0403_4B50 else {
            throw DeckImportError.unreadable
        }
        let start = header + 30 + Int(Self.uint16(bytes, header + 26)) + Int(Self.uint16(bytes, header + 28))
        guard start + entry.compressedSize <= bytes.count else {
            throw DeckImportError.unreadable
        }
        let payload = Array(bytes[start ..< (start + entry.compressedSize)])

        switch entry.method {
        case 0:
            return Data(payload)
        case 8:
            guard entry.uncompressedSize > 0 else {
                return Data()
            }
            var output = [UInt8](repeating: 0, count: entry.uncompressedSize)
            let written = compression_decode_buffer(&output, output.count, payload, payload.count, nil, COMPRESSION_ZLIB)
            guard written == entry.uncompressedSize else {
                throw DeckImportError.unreadable
            }
            return Data(output)
        default:
            throw DeckImportError.unreadable
        }
    }

    private static func uint16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func uint32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }
}
