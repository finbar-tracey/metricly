import SwiftUI
import SwiftData

extension CardioActiveView {

    // MARK: - Stats panel

    var statsPanel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                statCell(
                    value: tracker.formattedElapsed,
                    label: "Time",
                    font: .system(size: 38, weight: .black, design: .rounded)
                )
                Divider().frame(height: 50)
                statCell(
                    value: tracker.formattedDistance(useKm: useKm),
                    label: useKm ? "km" : "mi",
                    font: .system(size: 38, weight: .black, design: .rounded)
                )
                Divider().frame(height: 50)
                statCell(
                    value: tracker.formattedCurrentPace(useKm: useKm),
                    label: "Pace " + tracker.paceUnit,
                    font: .system(size: 30, weight: .black, design: .rounded),
                    color: tracker.currentPaceSecPerKm > 0
                        ? PaceZone.zone(for: tracker.currentPaceSecPerKm).color
                        : nil
                )
            }
            .padding(.vertical, 4)

            if let hr = displayHeartRate {
                heartRateZoneModule(hr: hr)
            }

            HStack(spacing: 20) {
                secondaryStat(
                    icon: "flame.fill",
                    value: String(format: "%.0f", tracker.estimatedCalories()),
                    label: "cal",
                    color: .orange
                )
                secondaryStat(
                    icon: "arrow.up.right",
                    value: String(format: "%.0f m", tracker.elevationGainMeters),
                    label: "Elevation"
                )
                secondaryStat(
                    icon: "flag.checkered",
                    value: "\(tracker.splits.count)",
                    label: useKm ? "km splits" : "mi splits"
                )
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                        showSplits.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: showSplits ? "chevron.down" : "chevron.up")
                            .font(.caption.bold())
                        Text("Splits")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(cardioType.color)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [cardioType.color.opacity(0.18), cardioType.color.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .overlay(Capsule().stroke(cardioType.color.opacity(0.22), lineWidth: 0.5))
                }
                .buttonStyle(.pressableCard)
            }
            .padding(.horizontal, 20)

            if showSplits && !tracker.splits.isEmpty {
                splitsTable
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.bottom, 8)
    }

    func statCell(value: String, label: String, font: Font, color: Color? = nil) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(font)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(color.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary))
                .contentTransition(.numericText())
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity)
    }

    func secondaryStat(icon: String, value: String, label: String, color: Color = .secondary) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    func heartRateZoneModule(hr: Double) -> some View {
        let zone = HRZone.zone(for: hr, maxHR: settingsArray.first?.resolvedMaxHR)
        let fill = max(0.0, min(1.0, (hr - 90) / 95.0))
        let order: [HRZone] = [.easy, .aerobic, .tempo, .threshold, .max]
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 8)
                    .frame(width: 76, height: 76)
                Circle()
                    .trim(from: 0, to: fill)
                    .stroke(zone.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 76, height: 76)
                    .shadow(color: zone.color.opacity(0.5), radius: 5, y: 1)
                    .animation(.easeOut(duration: 0.5), value: hr)
                VStack(spacing: -1) {
                    Text("\(Int(hr))")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("BPM")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(zone.color)
                        .symbolEffect(.pulse, options: .repeating)
                    Text("Zone \(zone.number) · \(zone.rawValue)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(zone.color)
                        .contentTransition(.opacity)
                }
                HStack(spacing: 4) {
                    ForEach(order, id: \.self) { z in
                        Capsule()
                            .fill(z.number <= zone.number ? z.color : Color.primary.opacity(0.10))
                            .frame(height: 6)
                            .animation(.easeOut(duration: 0.3), value: zone)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    #if DEBUG
    func startHRSimulation() {
        guard tracker.currentHeartRate == nil else { return }
        hrSimTimer?.invalidate()
        let t = Timer(timeInterval: 2.0, repeats: true) { _ in
            simulatedHR = Double.random(in: 108...178)
        }
        RunLoop.main.add(t, forMode: .common)
        hrSimTimer = t
    }
    #endif

    var splitsTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SPLIT").frame(width: 40, alignment: .leading)
                Spacer()
                Text("TIME").frame(width: 56, alignment: .trailing)
                Text("PACE").frame(width: 68, alignment: .trailing)
                if tracker.currentHeartRate != nil {
                    Text("HR").frame(width: 42, alignment: .trailing)
                }
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(tracker.splits.reversed()) { split in
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(cardioType.color.opacity(0.16))
                                    .frame(width: 28, height: 28)
                                Text("\(split.id)")
                                    .font(.system(size: 12, weight: .black, design: .rounded).monospacedDigit())
                                    .foregroundStyle(cardioType.color)
                            }
                            .frame(width: 40, alignment: .leading)
                            Spacer()
                            Text(split.formattedDuration())
                                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                                .frame(width: 56, alignment: .trailing)
                            Text(split.formattedPace(useKm: useKm))
                                .font(.system(size: 13, weight: .black, design: .rounded).monospacedDigit())
                                .foregroundStyle(cardioType.color)
                                .frame(width: 68, alignment: .trailing)
                            if tracker.currentHeartRate != nil {
                                Text(split.avgHeartRate.map { "\(Int($0))" } ?? "--")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(.red)
                                    .frame(width: 42, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        Divider().padding(.horizontal, 20)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous)
                .stroke(AppTheme.cardHairline, lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
    }
}
