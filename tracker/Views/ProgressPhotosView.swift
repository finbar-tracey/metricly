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

    private var filteredPhotos: [ProgressPhoto] {
        filterCategory == "All" ? photos : photos.filter { $0.category == filterCategory }
    }

    private var groupedPhotos: [(String, [ProgressPhoto])] {
        let grouped = Dictionary(grouping: filteredPhotos, by: { $0.category })
        return ProgressPhotosSections.categories.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                ProgressPhotosSections.heroCard(photos: photos)
                ProgressPhotosSections.categoryPickerCard(photos: photos, filterCategory: $filterCategory)

                if filteredPhotos.isEmpty {
                    ProgressPhotosSections.emptyStateCard(onPickCategory: pickCategory)
                } else {
                    ForEach(groupedPhotos, id: \.0) { category, items in
                        ProgressPhotosSections.photoCategoryCard(
                            category: category,
                            items: items,
                            onSelect: { selectedPhoto = $0 },
                            onDelete: { photoToDelete = $0 }
                        )
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
                ProgressPhotosSections.addPhotoButton(onPickCategory: pickCategory)
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

    private func pickCategory(_ category: String) {
        selectedCategory = category
        showingPicker = true
    }

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
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
                }

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
