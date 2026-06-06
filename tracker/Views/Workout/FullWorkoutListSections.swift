import SwiftUI

enum FullWorkoutListSections {

    enum DateRange: String, CaseIterable {
        case all = "All Time"
        case week = "This Week"
        case month = "This Month"
        case threeMonths = "3 Months"
        case year = "This Year"
    }

    static func cutoffDate(for range: DateRange) -> Date {
        let calendar = Calendar.current
        switch range {
        case .all: return .distantPast
        case .week: return calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        case .month: return calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: .now) ?? .now
        case .year: return calendar.date(byAdding: .year, value: -1, to: .now) ?? .now
        }
    }

    @ViewBuilder
    static func heroSection(total: Int, thisWeek: Int, thisMonth: Int) -> some View {
        Section {
            workoutHeroCard(total: total, thisWeek: thisWeek, thisMonth: thisMonth)
                .listRowBackground(Color.clear)
                .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    @ViewBuilder
    static func filterChipsSection(
        filterDateRange: Binding<DateRange>,
        filterMuscleGroup: Binding<MuscleGroup?>,
        filterRating: Binding<Int?>,
        hasActiveFilters: Bool,
        onClearFilters: @escaping () -> Void
    ) -> some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    dateFilterMenu(selection: filterDateRange)
                    muscleFilterMenu(selection: filterMuscleGroup)
                    ratingFilterMenu(selection: filterRating)
                    if hasActiveFilters {
                        Button(action: onClearFilters) {
                            Text("Clear")
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.red.opacity(0.1), in: Capsule())
                        }
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }

    @ViewBuilder
    static func workoutListSection(
        workouts: [Workout],
        hasActiveFilters: Bool,
        onDelete: @escaping (IndexSet) -> Void
    ) -> some View {
        Section {
            ForEach(workouts) { workout in
                NavigationLink(value: workout) {
                    WorkoutCardView(workout: workout)
                }
            }
            .onDelete(perform: onDelete)
        } header: {
            HStack {
                SectionHeader(
                    title: hasActiveFilters ? "Filtered Workouts" : "All Workouts",
                    icon: "dumbbell.fill",
                    color: .accentColor
                )
                if hasActiveFilters {
                    Spacer()
                    Text("\(workouts.count)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    static func noFilterMatchesRow(onClearFilters: @escaping () -> Void) -> some View {
        ContentUnavailableView {
            Label("No Matches", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text("No workouts match your current filters.")
        } actions: {
            Button("Clear Filters", action: onClearFilters)
        }
        .listRowBackground(Color.clear)
    }

    static func emptyLibraryOverlay(onStartWorkout: @escaping () -> Void) -> some View {
        EmptyStateView(
            icon: "dumbbell.fill",
            title: "No Workouts Yet",
            subtitle: "Log your first workout to start tracking your progress.",
            action: .init(label: "Start Workout", perform: onStartWorkout)
        )
    }

    // MARK: - Hero

    private static func workoutHeroCard(total: Int, thisWeek: Int, thisMonth: Int) -> some View {
        HeroCard(palette: AppTheme.Gradients.calm) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("All Workouts")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(0.5)
                        .textCase(.uppercase)
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: "\(total)", label: "Total", icon: "dumbbell.fill")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
                    HeroStatCol(value: "\(thisWeek)", label: "This Week", icon: "calendar")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 40)
                    HeroStatCol(value: "\(thisMonth)", label: "This Month", icon: "calendar.badge.clock")
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
        .frame(minHeight: 145)
    }

    // MARK: - Filters

    private static func dateFilterMenu(selection: Binding<DateRange>) -> some View {
        Menu {
            ForEach(DateRange.allCases, id: \.self) { range in
                Button {
                    selection.wrappedValue = range
                } label: {
                    if selection.wrappedValue == range {
                        Label(range.rawValue, systemImage: "checkmark")
                    } else {
                        Text(range.rawValue)
                    }
                }
            }
        } label: {
            filterChipLabel(
                label: selection.wrappedValue == .all ? "Date" : selection.wrappedValue.rawValue,
                isActive: selection.wrappedValue != .all,
                icon: "calendar"
            )
        }
    }

    private static func muscleFilterMenu(selection: Binding<MuscleGroup?>) -> some View {
        Menu {
            Button {
                selection.wrappedValue = nil
            } label: {
                if selection.wrappedValue == nil {
                    Label("All", systemImage: "checkmark")
                } else {
                    Text("All")
                }
            }
            ForEach(MuscleGroup.allCases) { group in
                Button {
                    selection.wrappedValue = group
                } label: {
                    if selection.wrappedValue == group {
                        Label(group.rawValue, systemImage: "checkmark")
                    } else {
                        Text(group.rawValue)
                    }
                }
            }
        } label: {
            filterChipLabel(
                label: selection.wrappedValue?.rawValue ?? "Muscle",
                isActive: selection.wrappedValue != nil,
                icon: "figure.strengthtraining.traditional"
            )
        }
    }

    private static func ratingFilterMenu(selection: Binding<Int?>) -> some View {
        Menu {
            Button {
                selection.wrappedValue = nil
            } label: {
                if selection.wrappedValue == nil {
                    Label("Any", systemImage: "checkmark")
                } else {
                    Text("Any")
                }
            }
            ForEach(1...5, id: \.self) { stars in
                Button {
                    selection.wrappedValue = stars
                } label: {
                    if selection.wrappedValue == stars {
                        Label(String(repeating: "★", count: stars), systemImage: "checkmark")
                    } else {
                        Text(String(repeating: "★", count: stars))
                    }
                }
            }
        } label: {
            filterChipLabel(
                label: selection.wrappedValue.map { "\($0)★" } ?? "Rating",
                isActive: selection.wrappedValue != nil,
                icon: "star"
            )
        }
    }

    private static func filterChipLabel(label: String, isActive: Bool, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor : Color(.tertiarySystemFill), in: Capsule())
        .foregroundStyle(isActive ? .white : .primary)
    }
}
