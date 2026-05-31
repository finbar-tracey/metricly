import SwiftUI
import Charts

enum CaffeineLogCardSection {

    static func quickLogCard(
        frequentSources: [CaffeineEngine.FrequentSource],
        onQuickLog: @escaping (String, Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Log", icon: "bolt.heart.fill", color: .brown)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(frequentSources) { fav in
                        Button { onQuickLog(fav.name, fav.mg) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: fav.icon).font(.caption)
                                Text(fav.name).font(.caption.bold())
                                Text("\(Int(fav.mg))mg").font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color.brown.opacity(0.20), Color.brown.opacity(0.10)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                in: Capsule()
                            )
                            .overlay(Capsule().stroke(Color.brown.opacity(0.25), lineWidth: 0.5))
                            .foregroundStyle(Color.brown)
                        }
                        .buttonStyle(.pressableCard)
                    }
                }
            }
        }
        .appCard()
    }

    static func dailyBudgetCard(todayTotalMg: Double, dailyLimit: Double) -> some View {
        let progress = min(1.0, todayTotalMg / dailyLimit)
        let overLimit = todayTotalMg > dailyLimit
        let color: Color = overLimit ? .red : (progress > 0.75 ? .orange : .brown)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Daily Budget", icon: "chart.bar.fill", color: color)
                Spacer()
                Text("\(Int(todayTotalMg)) / \(Int(dailyLimit)) mg")
                    .font(.caption.bold().monospacedDigit()).foregroundStyle(color)
            }
            GradientProgressBar(value: progress, color: color, height: 8)
            if overLimit {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.caption)
                    Text("Over daily limit by \(Int(todayTotalMg - dailyLimit)) mg")
                        .font(.caption).foregroundStyle(.red)
                }
            }
        }
        .appCard()
    }

    static func decayCard(
        from now: Date,
        entries: [CaffeineEntry],
        halfLife: Double,
        decayTint: Color
    ) -> some View {
        let data = CaffeineEngine.decayCurveData(entries: entries, halfLifeHours: halfLife, now: now)
        let clearTime = CaffeineEngine.clearTime(from: now, entries: entries, halfLifeHours: halfLife)

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Caffeine Decay", icon: "waveform.path.ecg", color: .brown)
            Chart {
                ForEach(data) { point in
                    AreaMark(x: .value("Time", point.date), y: .value("Caffeine", point.mg))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [decayTint.opacity(0.30), decayTint.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    LineMark(x: .value("Time", point.date), y: .value("Caffeine", point.mg))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.82, green: 0.48, blue: 0.20), decayTint],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                }
                if let nowPoint = data.first {
                    PointMark(x: .value("Time", nowPoint.date), y: .value("Caffeine", nowPoint.mg))
                        .symbolSize(130)
                        .foregroundStyle(decayTint)
                        .annotation(position: .top, alignment: .center) {
                            Text("\(Int(nowPoint.mg))mg")
                                .font(.caption2.bold())
                                .foregroundStyle(.brown)
                        }
                }
                RuleMark(y: .value("Sleep Ready", 25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(.green.opacity(0.6))
                    .annotation(position: .leading, alignment: .leading) {
                        Text("Sleep").font(.caption2).foregroundStyle(.green)
                    }
                if let clearTime {
                    RuleMark(x: .value("Clear", clearTime))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.green.opacity(0.5))
                        .annotation(position: .top, alignment: .center) {
                            Text(clearTime, format: .dateTime.hour().minute())
                                .font(.caption2.bold()).foregroundStyle(.green)
                        }
                }
            }
            .chartYAxisLabel("mg")
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .frame(height: 200).padding(.vertical, 4)
        }
        .appCard()
    }

    struct LogCaffeineCard: View {
        @Binding var selectedSource: String
        @Binding var customMg: String
        @Binding var showTimePicker: Bool
        @Binding var customDate: Date
        var isMgFocused: FocusState<Bool>.Binding
        let defaultMgForSource: Double
        let effectiveMg: Double
        let onLog: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Log Caffeine", icon: "plus.circle.fill", color: .brown)
                sourcePickerView.padding(.bottom, 4)
                VStack(spacing: 0) {
                    HStack {
                        Text("Amount").foregroundStyle(.secondary).font(.subheadline)
                        Spacer()
                        TextField(
                            selectedSource == "Other" ? "mg" : "\(Int(defaultMgForSource)) mg",
                            text: $customMg
                        )
                        .keyboardType(.decimalPad).focused(isMgFocused)
                        .multilineTextAlignment(.trailing).frame(width: 80).font(.subheadline)
                        Text("mg").foregroundStyle(.secondary).font(.subheadline)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("Time").foregroundStyle(.secondary).font(.subheadline)
                        Spacer()
                        if showTimePicker {
                            DatePicker("", selection: $customDate, in: ...Date.now,
                                       displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden().fixedSize()
                            Button("Now") { customDate = .now; showTimePicker = false }
                                .font(.caption.bold()).foregroundStyle(.brown)
                        } else {
                            Button {
                                customDate = .now; showTimePicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Now").font(.subheadline)
                                    Image(systemName: "clock").font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    Divider().padding(.leading, 16)
                    Button(action: onLog) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Log \(Int(effectiveMg)) mg \(selectedSource)").font(.subheadline.bold())
                        }
                        .accessibilityIdentifier("caffeineLogButton")
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(
                            Group {
                                if effectiveMg <= 0 {
                                    Color(.systemFill)
                                } else {
                                    LinearGradient(
                                        colors: [Color(red: 0.82, green: 0.48, blue: 0.20), Color.brown],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                }
                            }
                        )
                        .foregroundStyle(effectiveMg <= 0 ? Color.secondary : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                        .shadow(color: effectiveMg <= 0 ? .clear : Color.brown.opacity(0.40), radius: 8, y: 4)
                    }
                    .disabled(effectiveMg <= 0)
                    .buttonStyle(.pressableCard)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .appCard()
        }

        private var sourcePickerView: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CaffeineEntry.presets, id: \.name) { preset in
                        Button {
                            selectedSource = preset.name
                            if preset.name != "Other" { customMg = "" }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: preset.icon).font(.system(size: 18))
                                Text(preset.name).font(.caption2).lineLimit(1)
                                if preset.mg > 0 {
                                    Text("\(Int(preset.mg))mg").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 70, height: 65)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedSource == preset.name ? Color.brown.opacity(0.15) : Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedSource == preset.name ? Color.brown : .clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.pressableCard)
                    }
                }
            }
        }
    }
}
