import SwiftUI

enum HeartRateDetailHeroSections {
    struct HRZone: Identifiable {
        let name: String
        let range: String
        let color: Color
        let isActive: Bool
        var id: String { name }
    }

    static func heroCard(
        todayResting: Double?,
        todayStats: (min: Double, max: Double, avg: Double)?,
        todayHRV: Double?
    ) -> some View {
        HeroCard(palette: AppTheme.Gradients.strain) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 60, height: 60)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "heart.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        if let resting = todayResting {
                            Text("Resting Heart Rate")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.82))
                                .tracking(0.5)
                                .textCase(.uppercase)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                AnimatedInt(value: Int(resting), font: .system(size: 54, weight: .black, design: .rounded), color: .white)
                                    .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                                Text("bpm")
                                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                        } else if let stats = todayStats {
                            Text("Average Today")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.82))
                                .tracking(0.5)
                                .textCase(.uppercase)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                AnimatedInt(value: Int(stats.avg), font: .system(size: 54, weight: .black, design: .rounded), color: .white)
                                    .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                                Text("bpm")
                                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                        } else {
                            Text("No Data")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
                HStack(spacing: 0) {
                    if let stats = todayStats {
                        HeroStatCol(value: "\(Int(stats.min)) bpm", label: "Min", icon: "arrow.down.heart.fill")
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                        HeroStatCol(value: "\(Int(stats.max)) bpm", label: "Max", icon: "arrow.up.heart.fill")
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    }
                    if let hrv = todayHRV {
                        HeroStatCol(value: "\(Int(hrv)) ms", label: "HRV", icon: "waveform.path.ecg")
                    } else {
                        HeroStatCol(value: "—", label: "HRV", icon: "waveform.path.ecg")
                    }
                    if let stats = todayStats {
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                        HeroStatCol(value: "\(Int(stats.max - stats.min))", label: "Range", icon: "arrow.up.arrow.down")
                    }
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
    }

    static func zonesCard(stats: (min: Double, max: Double, avg: Double)) -> some View {
        let zones = heartRateZones(min: stats.min, max: stats.max)
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Heart Rate Zones", icon: "heart.circle.fill", color: .red)
            VStack(spacing: 0) {
                ForEach(Array(zones.enumerated()), id: \.element.id) { idx, zone in
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(LinearGradient(colors: [zone.color, zone.color.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 5, height: 42)
                            .shadow(color: zone.color.opacity(0.40), radius: 4)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(zone.name).font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text(zone.range).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if zone.isActive {
                            Text("ACTIVE")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(0.5)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(
                                    LinearGradient(colors: [zone.color, zone.color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: Capsule()
                                )
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    if idx < zones.count - 1 { Divider().padding(.leading, 35) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.cardHairline, lineWidth: 0.5))
        }
        .appCard()
    }

    private static func heartRateZones(min: Double, max: Double) -> [HRZone] {
        let estimatedMax = 190.0
        let restZone = estimatedMax * 0.5
        let fatBurnLow = estimatedMax * 0.5
        let fatBurnHigh = estimatedMax * 0.7
        let cardioLow = estimatedMax * 0.7
        let cardioHigh = estimatedMax * 0.85
        let peakLow = estimatedMax * 0.85
        return [
            HRZone(name: "Rest", range: "< \(Int(restZone)) bpm", color: .blue, isActive: min < restZone),
            HRZone(name: "Fat Burn", range: "\(Int(fatBurnLow))–\(Int(fatBurnHigh)) bpm", color: .green, isActive: max >= fatBurnLow && min <= fatBurnHigh),
            HRZone(name: "Cardio", range: "\(Int(cardioLow))–\(Int(cardioHigh)) bpm", color: .yellow, isActive: max >= cardioLow && min <= cardioHigh),
            HRZone(name: "Peak", range: "> \(Int(peakLow)) bpm", color: .red, isActive: max >= peakLow),
        ]
    }
}
