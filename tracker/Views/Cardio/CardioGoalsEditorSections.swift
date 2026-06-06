import SwiftUI

enum CardioGoalsEditorSections {

    static func setGoalsCard(
        distanceGoalKm: Double,
        sessionGoal: Int,
        distanceUnit: DistanceUnit,
        onEditDistance: @escaping () -> Void,
        onEditSessions: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Set Goals", icon: "target", color: .purple)

            VStack(spacing: 0) {
                Button(action: onEditDistance) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.chipRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, AppTheme.Signal.actionOrange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                                .shadow(color: .orange.opacity(0.40), radius: 5, y: 2)
                            Image(systemName: "ruler")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weekly Distance")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text("Set a distance target for each week")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(distanceGoalKm > 0
                             ? String(format: "%.0f %@", distanceUnit.display(distanceGoalKm), distanceUnit.label)
                             : "Not set")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(distanceGoalKm > 0 ? .orange : .secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .buttonStyle(.pressableCard)

                Divider().padding(.horizontal, 16)

                Button(action: onEditSessions) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.chipRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, AppTheme.Signal.calm],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                                .shadow(color: .blue.opacity(0.40), radius: 5, y: 2)
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weekly Sessions")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text("How many cardio sessions per week")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(sessionGoal > 0
                             ? "\(sessionGoal) session\(sessionGoal == 1 ? "" : "s")"
                             : "Not set")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(sessionGoal > 0 ? .blue : .secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .buttonStyle(.pressableCard)
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                    .stroke(AppTheme.cardHairline, lineWidth: 0.5)
            )
        }
        .appCard()
    }

    static func distanceGoalSheet(
        draftDistanceKm: Binding<Double>,
        distanceUnit: DistanceUnit,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        value: draftDistanceKm,
                        in: 0...500,
                        step: distanceUnit.stepSize
                    ) {
                        HStack {
                            Text("Distance")
                            Spacer()
                            Text(draftDistanceKm.wrappedValue > 0
                                 ? String(format: "%.0f %@", distanceUnit.display(draftDistanceKm.wrappedValue), distanceUnit.label)
                                 : "Off")
                                .foregroundStyle(draftDistanceKm.wrappedValue > 0 ? .primary : .secondary)
                        }
                    }
                } footer: {
                    Text("Set to 0 to disable this goal.")
                }
            }
            .navigationTitle("Weekly Distance Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }
            }
        }
        .presentationDetents([.medium])
    }

    static func sessionGoalSheet(
        draftSessionCount: Binding<Int>,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: draftSessionCount, in: 0...14) {
                        HStack {
                            Text("Sessions per week")
                            Spacer()
                            Text(draftSessionCount.wrappedValue > 0 ? "\(draftSessionCount.wrappedValue)" : "Off")
                                .foregroundStyle(draftSessionCount.wrappedValue > 0 ? .primary : .secondary)
                        }
                    }
                } footer: {
                    Text("Set to 0 to disable this goal.")
                }
            }
            .navigationTitle("Weekly Session Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }
            }
        }
        .presentationDetents([.medium])
    }

    static func streakCard(streak: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Activity Streak", icon: "flame.fill", color: .red)

            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.18), Color.red.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 78, height: 78)
                        .overlay(Circle().stroke(Color.red.opacity(0.20), lineWidth: 1))
                    VStack(spacing: 2) {
                        AnimatedInt(
                            value: streak,
                            font: .system(size: 30, weight: .black, design: .rounded),
                            color: .red
                        )
                        Text("WEEKS")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(streak == 0 ? "No streak yet" : "\(streak) week\(streak == 1 ? "" : "s") in a row")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(streak == 0
                         ? "Complete a cardio session this week to start your streak."
                         : "Keep going — don't break the chain!")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.red.opacity(0.08), Color(.tertiarySystemGroupedBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                    .stroke(Color.red.opacity(0.12), lineWidth: 0.5)
            )
        }
        .appCard()
    }
}
