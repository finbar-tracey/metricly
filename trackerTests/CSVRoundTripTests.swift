import XCTest
@testable import tracker

final class CSVRoundTripTests: XCTestCase {

    // MARK: - escape()

    func testPlainFieldUnchanged() {
        XCTAssertEqual(ExportHelper.escape("Push Day"), "Push Day")
    }

    func testFieldWithCommaIsQuoted() {
        XCTAssertEqual(ExportHelper.escape("Push, Day"), "\"Push, Day\"")
    }

    func testFieldWithQuoteIsDoubled() {
        XCTAssertEqual(
            ExportHelper.escape("He said \"hello\""),
            "\"He said \"\"hello\"\"\""
        )
    }

    func testFieldWithNewlineIsQuoted() {
        XCTAssertEqual(
            ExportHelper.escape("Line one\nLine two"),
            "\"Line one\nLine two\""
        )
    }

    func testFieldWithCommaAndQuote() {
        XCTAssertEqual(
            ExportHelper.escape("She said \"go\", and went."),
            "\"She said \"\"go\"\", and went.\""
        )
    }

    // MARK: - parseCSVRows()

    func testParsesPlainCSV() {
        let csv = "a,b,c\n1,2,3\n"
        let rows = ImportHelper.parseCSVRows(csv)
        XCTAssertEqual(rows, [["a","b","c"], ["1","2","3"]])
    }

    func testParsesQuotedFieldWithComma() {
        let csv = "name,score\n\"Push, Day\",10\n"
        let rows = ImportHelper.parseCSVRows(csv)
        XCTAssertEqual(rows, [["name","score"], ["Push, Day","10"]])
    }

    func testParsesDoubledQuoteEscape() {
        // The actual round-trip case that motivated this fix
        let csv = "name\n\"He said \"\"hello\"\"\"\n"
        let rows = ImportHelper.parseCSVRows(csv)
        XCTAssertEqual(rows, [["name"], ["He said \"hello\""]])
    }

    func testParsesQuotedFieldWithNewline() {
        let csv = "notes\n\"Line one\nLine two\"\n"
        let rows = ImportHelper.parseCSVRows(csv)
        XCTAssertEqual(rows, [["notes"], ["Line one\nLine two"]])
    }

    func testParsesEmptyFields() {
        let csv = "a,b,c\n,2,\n"
        let rows = ImportHelper.parseCSVRows(csv)
        XCTAssertEqual(rows, [["a","b","c"], ["","2",""]])
    }

    func testHandlesCRLFLineEndings() {
        let csv = "a,b\r\n1,2\r\n"
        let rows = ImportHelper.parseCSVRows(csv)
        XCTAssertEqual(rows, [["a","b"], ["1","2"]])
    }

    func testHandlesNoTrailingNewline() {
        let csv = "a,b\n1,2"
        let rows = ImportHelper.parseCSVRows(csv)
        XCTAssertEqual(rows, [["a","b"], ["1","2"]])
    }

    func testSkipsBlankLines() {
        let csv = "a,b\n\n1,2\n\n"
        let rows = ImportHelper.parseCSVRows(csv)
        XCTAssertEqual(rows, [["a","b"], ["1","2"]])
    }

    // MARK: - Round-trip

    func testRoundTripPreservesQuotesInWorkoutName() {
        let original = "He said \"go heavy\""
        let escaped = ExportHelper.escape(original)
        // Wrap in a one-row CSV and re-parse
        let csv = "name\n\(escaped)\n"
        let rows = ImportHelper.parseCSVRows(csv)
        XCTAssertEqual(rows.last?.first, original)
    }

    func testRoundTripPreservesCommasInExerciseName() {
        let original = "Bench Press, paused"
        let csv = "name\n\(ExportHelper.escape(original))\n"
        let rows = ImportHelper.parseCSVRows(csv)
        XCTAssertEqual(rows.last?.first, original)
    }

    func testRoundTripPreservesNewlinesInNotes() {
        let original = "First note line\nSecond note line"
        let csv = "notes\n\(ExportHelper.escape(original))\n"
        let rows = ImportHelper.parseCSVRows(csv)
        XCTAssertEqual(rows.last?.first, original)
    }

    func testRoundTripWithAllSpecialCharsInOneField() {
        let original = "Mixed: comma, quote \", and\nnewline."
        let csv = "field\n\(ExportHelper.escape(original))\n"
        let rows = ImportHelper.parseCSVRows(csv)
        XCTAssertEqual(rows.last?.first, original)
    }

    func testRoundTripMultipleRowsAndFields() {
        // Full multi-row, multi-field round trip mixing escaped and plain values
        let values: [[String]] = [
            ["Date", "Workout", "Note"],
            ["2026-05-01", "Push, Day", "He said \"easy\""],
            ["2026-05-02", "Pull", "Multi\nline\nnote"],
            ["2026-05-03", "Legs", "Plain text"],
        ]
        let csv = values.map { row in
            row.map(ExportHelper.escape).joined(separator: ",")
        }.joined(separator: "\n") + "\n"

        let parsed = ImportHelper.parseCSVRows(csv)
        XCTAssertEqual(parsed, values)
    }
}
