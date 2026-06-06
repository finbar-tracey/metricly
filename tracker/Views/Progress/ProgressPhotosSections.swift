import SwiftUI

enum ProgressPhotosSections {

    static let categories = ["Front", "Back", "Side", "Legs", "Other"]

    static var filterCategories: [String] { ["All"] + categories }

    static func heroCard(photos: [ProgressPhoto]) -> some View {
        HeroCard(palette: [
            Color(red: 0.55, green: 0.30, blue: 0.95),
            Color(red: 0.40, green: 0.30, blue: 0.85),
            Color(red: 0.30, green: 0.40, blue: 0.85)
        ]) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Progress Photos")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            AnimatedInt(
                                value: photos.count,
                                font: .system(size: 42, weight: .black, design: .rounded),
                                color: .white
                            )
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                            Text("photos")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                    Spacer()
                    if !photos.isEmpty, let latest = photos.first {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("LATEST")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                                .tracking(0.5)
                            Text(latest.date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption.bold()).foregroundStyle(.white)
                        }
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.7), in: RoundedRectangle(cornerRadius: AppTheme.chipRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.chipRadius, style: .continuous)
                                .stroke(.white.opacity(0.25), lineWidth: 0.5)
                        )
                    }
                }

                HStack(spacing: 0) {
                    ForEach(categories, id: \.self) { cat in
                        let count = photos.filter { $0.category == cat }.count
                        HeroStatCol(value: "\(count)", label: cat)
                        if cat != categories.last {
                            Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                        }
                    }
                }
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
    }

    static func categoryPickerCard(
        photos: [ProgressPhoto],
        filterCategory: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Filter", icon: "line.3.horizontal.decrease.circle.fill", color: .purple)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filterCategories, id: \.self) { cat in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { filterCategory.wrappedValue = cat }
                        } label: {
                            let count = cat == "All" ? photos.count : photos.filter { $0.category == cat }.count
                            HStack(spacing: 5) {
                                Text(cat).font(.caption.bold())
                                Text("\(count)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(filterCategory.wrappedValue == cat ? .white.opacity(0.25) : Color(.tertiarySystemFill),
                                                in: Capsule())
                                    .foregroundStyle(filterCategory.wrappedValue == cat ? .white : .secondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(filterCategory.wrappedValue == cat ? Color.purple : Color(.secondarySystemFill),
                                        in: Capsule())
                            .foregroundStyle(filterCategory.wrappedValue == cat ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appCard()
    }

    static func photoCategoryCard(
        category: String,
        items: [ProgressPhoto],
        onSelect: @escaping (ProgressPhoto) -> Void,
        onDelete: @escaping (ProgressPhoto) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: category, icon: "photo.stack", color: .purple)

            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { photo in
                    photoThumbnail(photo, onSelect: onSelect, onDelete: onDelete)
                }
            }
        }
        .appCard()
    }

    static func addPhotoButton(onPickCategory: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(categories, id: \.self) { category in
                Button(category) { onPickCategory(category) }
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    static func emptyStateCard(onPickCategory: @escaping (String) -> Void) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.purple.opacity(0.12)).frame(width: 70, height: 70)
                Image(systemName: "camera.fill")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(.purple)
            }
            VStack(spacing: 6) {
                Text("No Photos Yet").font(.headline)
                Text("Take progress photos to track your physical transformation over time.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Menu {
                ForEach(categories, id: \.self) { category in
                    Button(category) { onPickCategory(category) }
                }
            } label: {
                Text("Add First Photo")
                    .font(.subheadline.bold()).padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.purple.gradient).foregroundStyle(.white).clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }

    // MARK: - Private

    private static func photoThumbnail(
        _ photo: ProgressPhoto,
        onSelect: @escaping (ProgressPhoto) -> Void,
        onDelete: @escaping (ProgressPhoto) -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect(photo)
        } label: {
            VStack(spacing: 6) {
                Group {
                    if let uiImage = UIImage(data: photo.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color(.tertiarySystemGroupedBackground)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)

                Text(photo.date, format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.pressableCard)
        .contextMenu {
            Button(role: .destructive) {
                onDelete(photo)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
