import Foundation
import UIKit

struct ExportHelper {

    // MARK: - Workout CSV

    static func generateCSV(workouts: [Workout]) -> String {
        var csv = "Date,Workout,Rating,Duration (min),Exercise,Muscle Group,Superset Group,Set,Reps,Weight (kg),RPE,Distance (km),Duration (s)\n"
        for workout in workouts.sorted(by: { $0.date > $1.date }) {
            let dateStr = formatDate(workout.date)
            let durationMin = workout.duration.map { String(Int($0 / 60)) } ?? ""
            let ratingStr = workout.rating.map(String.init) ?? ""
            for exercise in workout.exercises.sorted(by: { $0.order < $1.order }) {
                let ssGroup = exercise.supersetGroup.map(String.init) ?? ""
                let categoryStr = exercise.category?.rawValue ?? ""
                for (index, set) in exercise.sets.enumerated() {
                    let rpeStr = set.rpe.map(String.init) ?? ""
                    let distStr = set.distance.map { String(format: "%.2f", $0) } ?? ""
                    let durStr = set.durationSeconds.map(String.init) ?? ""
                    let line = "\(dateStr),\(escape(workout.name)),\(ratingStr),\(durationMin),\(escape(exercise.name)),\(categoryStr),\(ssGroup),\(index + 1),\(set.reps),\(String(format: "%.1f", set.weight)),\(rpeStr),\(distStr),\(durStr)\n"
                    csv += line
                }
            }
        }
        return csv
    }

    // MARK: - Cardio CSV

    static func generateCardioCSV(sessions: [CardioSession]) -> String {
        var csv = "Date,Title,Type,Duration (min),Distance (km),Avg Pace (min/km),Elevation Gain (m),Calories,Notes\n"
        for session in sessions.sorted(by: { $0.date > $1.date }) {
            let dateStr = formatDate(session.date)
            let durationMin = String(format: "%.1f", session.durationSeconds / 60)
            let distKm = String(format: "%.3f", session.distanceMeters / 1000)
            let pace: String
            if session.distanceMeters > 0 && session.durationSeconds > 0 {
                let secPerKm = session.durationSeconds / (session.distanceMeters / 1000)
                pace = String(format: "%d:%02d", Int(secPerKm) / 60, Int(secPerKm) % 60)
            } else {
                pace = ""
            }
            let elevation = String(format: "%.0f", session.elevationGainMeters)
            let calories = session.caloriesBurned.map { String(format: "%.0f", $0) } ?? ""
            let line = "\(dateStr),\(escape(session.title)),\(escape(session.cardioType)),\(durationMin),\(distKm),\(pace),\(elevation),\(calories),\(escape(session.notes))\n"
            csv += line
        }
        return csv
    }

    // MARK: - PDF Report

    static func generateWorkoutPDF(workouts: [Workout]) -> Data {
        let pageWidth: CGFloat = 612   // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return pdfRenderer.pdfData { context in
            let sorted = workouts.sorted(by: { $0.date > $1.date })

            // ── Title page ──
            context.beginPage()
            var y: CGFloat = margin

            // App name
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .black),
                .foregroundColor: UIColor.label
            ]
            let titleStr = NSAttributedString(string: "Metricly Workout Report", attributes: titleAttrs)
            titleStr.draw(at: CGPoint(x: margin, y: y))
            y += 40

            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let generatedStr = NSAttributedString(
                string: "Generated \(Date.now.formatted(date: .long, time: .shortened))  •  \(sorted.count) workout\(sorted.count == 1 ? "" : "s")",
                attributes: dateAttrs
            )
            generatedStr.draw(at: CGPoint(x: margin, y: y))
            y += 30

            // Divider
            UIColor.separator.setStroke()
            let divPath = UIBezierPath()
            divPath.move(to: CGPoint(x: margin, y: y))
            divPath.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            divPath.lineWidth = 0.5
            divPath.stroke()
            y += 20

            // Summary stats
            let totalSets = sorted.flatMap { $0.exercises.flatMap(\.sets) }.filter { !$0.isWarmUp }.count
            let totalVolumeKg = sorted.reduce(0.0) { total, w in
                total + w.exercises.reduce(0.0) { $0 + $1.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight } }
            }
            let summaryItems: [(String, String)] = [
                ("Total Workouts", "\(sorted.count)"),
                ("Total Sets", "\(totalSets)"),
                ("Total Volume", String(format: "%.0f kg", totalVolumeKg)),
            ]
            let statW = (pageWidth - margin * 2) / CGFloat(summaryItems.count)
            for (i, (label, value)) in summaryItems.enumerated() {
                let x = margin + CGFloat(i) * statW
                let valAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                    .foregroundColor: UIColor.label
                ]
                let labAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                NSAttributedString(string: value, attributes: valAttrs).draw(at: CGPoint(x: x, y: y))
                NSAttributedString(string: label, attributes: labAttrs).draw(at: CGPoint(x: x, y: y + 26))
            }
            y += 56

            // Divider
            UIColor.separator.setStroke()
            let div2 = UIBezierPath()
            div2.move(to: CGPoint(x: margin, y: y))
            div2.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            div2.lineWidth = 0.5
            div2.stroke()
            y += 20

            // ── Workout entries ──
            let contentW = pageWidth - margin * 2

            let workoutHeaderAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let exerciseAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.label
            ]
            let setAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.secondaryLabel
            ]

            for workout in sorted {
                // Check if we need a new page (need at least ~60pt)
                if y > pageHeight - margin - 60 {
                    context.beginPage()
                    y = margin
                }

                // Workout header
                let wDate = formatDate(workout.date)
                let wDur = workout.formattedDuration ?? ""
                let wName = NSAttributedString(string: workout.name, attributes: workoutHeaderAttrs)
                wName.draw(at: CGPoint(x: margin, y: y))
                y += 18
                let wMeta = NSAttributedString(
                    string: "\(wDate)\(wDur.isEmpty ? "" : "  •  \(wDur)")  •  \(workout.exercises.count) exercise\(workout.exercises.count == 1 ? "" : "s")",
                    attributes: metaAttrs
                )
                wMeta.draw(at: CGPoint(x: margin, y: y))
                y += 16

                // Exercises
                for exercise in workout.exercises.sorted(by: { $0.order < $1.order }) {
                    if y > pageHeight - margin - 40 {
                        context.beginPage()
                        y = margin
                    }
                    let workingSets = exercise.sets.filter { !$0.isWarmUp }
                    let exStr = NSAttributedString(string: "  \(exercise.name)", attributes: exerciseAttrs)
                    exStr.draw(at: CGPoint(x: margin, y: y))
                    y += 15

                    // Summarise sets as grouped lines (e.g. "3 × 10 @ 80 kg")
                    let setSummary = summariseSets(workingSets)
                    let setStr = NSAttributedString(string: "    \(setSummary)", attributes: setAttrs)
                    let setRect = CGRect(x: margin, y: y, width: contentW - 10, height: 200)
                    setStr.draw(in: setRect)
                    y += 14
                }
                y += 12

                // Thin rule between workouts
                UIColor.separator.withAlphaComponent(0.4).setStroke()
                let rule = UIBezierPath()
                rule.move(to: CGPoint(x: margin, y: y))
                rule.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                rule.lineWidth = 0.3
                rule.stroke()
                y += 10
            }

            // Footer on last page
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            NSAttributedString(string: "Metricly — your fitness companion", attributes: footerAttrs)
                .draw(at: CGPoint(x: margin, y: pageHeight - margin))
        }
    }

    // MARK: - Helpers

    private static func summariseSets(_ sets: [ExerciseSet]) -> String {
        guard !sets.isEmpty else { return "No working sets" }
        // Group consecutive sets with same reps+weight
        var groups: [(reps: Int, weight: Double, count: Int)] = []
        for s in sets {
            if let last = groups.last, last.reps == s.reps, abs(last.weight - s.weight) < 0.01 {
                groups[groups.count - 1].count += 1
            } else {
                groups.append((s.reps, s.weight, 1))
            }
        }
        return groups.map { g in
            let countStr = g.count > 1 ? "\(g.count) × " : ""
            let weightStr = g.weight > 0 ? " @ \(String(format: g.weight.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", g.weight)) kg" : ""
            return "\(countStr)\(g.reps) reps\(weightStr)"
        }.joined(separator: "  |  ")
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
