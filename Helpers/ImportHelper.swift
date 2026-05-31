import Foundation
import SwiftData
import UniformTypeIdentifiers

struct ImportHelper {
    enum ImportError: LocalizedError {
        case invalidFormat
        case noData
        case parseError(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "The CSV file format is not recognized."
            case .noData: return "The CSV file contains no workout data."
            case .parseError(let detail): return "Parse error: \(detail)"
            }
        }
    }

    struct ImportPreview: Identifiable {
        let id = UUID()
        let format: ImportFormat
        let workouts: [ParsedWorkout]

        var workoutCount: Int { workouts.count }
        var exerciseCount: Int {
            Set(workouts.flatMap { $0.exercises.map { $0.name.lowercased() } }).count
        }
        var totalSetCount: Int {
            workouts.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + $1.sets.count } }
        }
        var earliestDate: Date? {
            workouts.map(\.startDate).min()
        }
        var sampleWorkout: ParsedWorkout? { workouts.first }
    }

    enum ImportPlan {
        case preview(ImportPreview)
        case metriclyDirect
    }

    static func plan(from url: URL) throws -> ImportPlan {
        let content = try readContents(of: url)
        let rows = parseCSVRows(content)
        guard rows.count > 1 else { throw ImportError.noData }
        let header = rows[0]
        let dataRows = Array(rows.dropFirst())

        switch ImportFormat.detect(header: header) {
        case .strong:
            let workouts = StrongParser.parseRows(dataRows)
            guard !workouts.isEmpty else { throw ImportError.noData }
            return .preview(ImportPreview(format: .strong, workouts: workouts))

        case .hevy:
            let workouts = HevyParser.parseRows(header: header, rows: dataRows)
            guard !workouts.isEmpty else { throw ImportError.noData }
            return .preview(ImportPreview(format: .hevy, workouts: workouts))

        case .metricly:
            return .metriclyDirect

        case .none:
            throw ImportError.invalidFormat
        }
    }

    private static func readContents(of url: URL) throws -> String {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            return try String(contentsOf: url, encoding: .utf8)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func importCSV(from url: URL, into context: ModelContext) throws -> Int {
        let content = try readContents(of: url)
        let rows = parseCSVRows(content)
        guard rows.count > 1 else { throw ImportError.noData }
        let headerRow = rows[0]
        let dataRows = Array(rows.dropFirst())

        switch ImportFormat.detect(header: headerRow) {
        case .strong:
            let parsed = StrongParser.parseRows(dataRows)
            guard !parsed.isEmpty else { throw ImportError.noData }
            return insertParsedWorkouts(parsed, into: context)

        case .hevy:
            let parsed = HevyParser.parseRows(header: headerRow, rows: dataRows)
            guard !parsed.isEmpty else { throw ImportError.noData }
            return insertParsedWorkouts(parsed, into: context)

        case .metricly:
            return try importMetriclyRows(rows, into: context)

        case .none:
            throw ImportError.invalidFormat
        }
    }

    // MARK: - CSV Parsing

    static func parseCSVRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let chars = Array(normalized)
        var i = 0
        while i < chars.count {
            let char = chars[i]

            if inQuotes {
                if char == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    }
                    inQuotes = false
                } else {
                    currentField.append(char)
                }
            } else {
                switch char {
                case "\"":
                    inQuotes = true
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                case "\n":
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.allSatisfy({ $0.isEmpty }) {
                        rows.append(currentRow)
                    }
                    currentRow = []
                default:
                    currentField.append(char)
                }
            }
            i += 1
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            if !currentRow.allSatisfy({ $0.isEmpty }) {
                rows.append(currentRow)
            }
        }

        return rows
    }

    // MARK: - Locale-tolerant decimal parsing

    static func parseDecimal(_ s: String?) -> Double? {
        guard let s = s?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if let v = Double(s) { return v }
        let commaCount = s.filter { $0 == "," }.count
        let hasPeriod  = s.contains(".")
        if commaCount == 1 && !hasPeriod {
            return Double(s.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }
}
