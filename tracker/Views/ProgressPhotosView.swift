import SwiftUI
import SwiftData
import PhotosUI

struct ProgressPhotosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedCategory = "Front"
    @State private var showingPicker = false
    @State private var selectedPhoto: ProgressPhoto?
    @State private var photoToDelete: ProgressPhoto?
    @State private var filterCategory = "All"

    private let categories = ["Front", "Back", "Side", "Legs", "Other"]
    private var filterCategories: [String] { ["All"] + categories }

    private var filteredPhotos: [ProgressPhoto] {
        filterCategory == "All" ? photos : photos.filter { $0.category == filterCategory }
    }

    private var groupedPhotos: [(String, [ProgressPhoto])] {
        let grouped = Dictionary(grouping: filteredPhotos, by: { $0.category })
        return categories.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                heroCard
                categoryPickerCard

                if filteredPhotos.isEmpty {
                    emptyStateCard
                } else {
                    ForEach(groupedPhotos, id: \.0) { category, items in
                        photoCategoryCard(category: category, items: items)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Progress Photos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                addPhotoButton
            }
        }
        .photosPicker(isPresented: $showingPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            if let newItem { loadPhoto(from: newItem) }
        }
        .sheet(item: $selectedPhoto) { photo in
            NavigationStack {
                PhotoDetailView(photo: photo)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { selectedPhoto = nil }
                        }
                    }
            }
        }
        .alert("Delete Photo?", isPresented: Binding(
            get: { photoToDelete != nil },
            set: { if !$0 { photoToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let photo = photoToDelete {
                    modelContext.delete(photo)
                    photoToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { photoToDelete = nil }
        } message: {
            Text("This photo will be permanently deleted.")
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
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
                        .background(.ultraThinMaterial.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
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


    // MARK: - Category Picker Card

    private var categoryPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Filter", icon: "line.3.horizontal.decrease.circle.fill", color: .purple)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filterCategories, id: \.self) { cat in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { filterCategory = cat }
                        } label: {
                            let count = cat == "All" ? photos.count : photos.filter { $0.category == cat }.count
                            HStack(spacing: 5) {
                                Text(cat).font(.caption.bold())
                                Text("\(count)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(filterCategory == cat ? .white.opacity(0.25) : Color(.tertiarySystemFill),
                                                in: Capsule())
                                    .foregroundStyle(filterCategory == cat ? .white : .secondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(filterCategory == cat ? Color.purple : Color(.secondarySystemFill),
                                        in: Capsule())
                            .foregroundStyle(filterCategory == cat ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Photo Category Card

    private func photoCategoryCard(category: String, items: [ProgressPhoto]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: category, icon: "photo.stack", color: .purple)

            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { photo in
                    photoThumbnail(photo)
                }
            }
        }
        .appCard()
    }

    // MARK: - Photo Thumbnail

    private func photoThumbnail(_ photo: ProgressPhoto) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedPhoto = photo
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
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                photoToDelete = photo
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Add Photo Button

    private var addPhotoButton: some View {
        Menu {
            ForEach(categories, id: \.self) { category in
                Button(category) {
                    selectedCategory = category
                    showingPicker = true
                }
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
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
                    Button(category) {
                        selectedCategory = category
                        showingPicker = true
                    }
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

    // MARK: - Load Photo

    private func loadPhoto(from item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            guard let uiImage = UIImage(data: data),
                  let compressed = uiImage.jpegData(compressionQuality: 0.7) else { return }
            let photo = ProgressPhoto(date: .now, imageData: compressed, category: selectedCategory)
            modelContext.insert(photo)
            selectedItem = nil
        }
    }
}

// MARK: - Photo Detail View

struct PhotoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let photo: ProgressPhoto
    @State private var notes: String = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                // Photo
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
                }

                // Meta card
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Details", icon: "info.circle.fill", color: .purple)
                    VStack(spacing: 0) {
                        HStack {
                            Text("Category").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text(photo.category)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.purple.opacity(0.12), in: Capsule())
                                .foregroundStyle(.purple)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        Divider().padding(.leading, 16)
                        HStack {
                            Text("Date").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text(photo.date, format: .dateTime.month().day().year())
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .appCard()

                // Notes card
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Notes", icon: "note.text", color: .purple)
                    TextField("Add notes about this photo…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.body)
                        .padding(14)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .appCard()

                // Delete button
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Photo", systemImage: "trash")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Color.red.opacity(0.10))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Photo Detail")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { notes = photo.notes }
        .onDisappear { photo.notes = notes }
        .alert("Delete Photo?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(photo)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This photo will be permanently deleted.")
        }
    }
}

#Preview {
    NavigationStack { ProgressPhotosView() }
        .modelContainer(for: ProgressPhoto.self, inMemory: true)
}
