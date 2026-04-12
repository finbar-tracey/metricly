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

    private let categories = ["Front", "Back", "Side", "Legs", "Other"]

    private var groupedPhotos: [(String, [ProgressPhoto])] {
        let grouped = Dictionary(grouping: photos, by: { $0.category })
        return categories.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    var body: some View {
        Group {
            if photos.isEmpty {
                ContentUnavailableView {
                    Label("No Progress Photos", systemImage: "camera")
                } description: {
                    Text("Take progress photos to track your physical transformation over time.")
                } actions: {
                    addPhotoButton
                }
            } else {
                List {
                    ForEach(groupedPhotos, id: \.0) { category, items in
                        Section(category) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(items) { photo in
                                        photoThumbnail(photo)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        addPhotoButton
                    }
                }
            }
        }
        .navigationTitle("Progress Photos")
        .photosPicker(isPresented: $showingPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            if let newItem {
                loadPhoto(from: newItem)
            }
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
        .confirmationDialog("Photo Category", isPresented: .constant(false)) {
            // Placeholder for category selection
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

    private var addPhotoButton: some View {
        Menu {
            ForEach(categories, id: \.self) { category in
                Button(category) {
                    selectedCategory = category
                    showingPicker = true
                }
            }
        } label: {
            Label("Add Photo", systemImage: "plus")
        }
    }

    private func photoThumbnail(_ photo: ProgressPhoto) -> some View {
        Button {
            selectedPhoto = photo
        } label: {
            VStack(spacing: 4) {
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.quaternary)
                        .frame(width: 100, height: 130)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
                Text(photo.date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                photoToDelete = photo
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            // Compress image
            guard let uiImage = UIImage(data: data),
                  let compressed = uiImage.jpegData(compressionQuality: 0.7) else { return }

            let photo = ProgressPhoto(
                date: .now,
                imageData: compressed,
                category: selectedCategory
            )
            modelContext.insert(photo)
            selectedItem = nil
        }
    }
}

struct PhotoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let photo: ProgressPhoto
    @State private var notes: String = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                HStack {
                    Label(photo.category, systemImage: "tag")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                    Spacer()
                    Text(photo.date, format: .dateTime.month().day().year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                    TextField("Add notes about this photo...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()
        }
        .navigationTitle("Photo Detail")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            notes = photo.notes
        }
        .onDisappear {
            photo.notes = notes
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Photo", systemImage: "trash")
                }
            }
        }
        .alert("Delete Photo?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(photo)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This photo will be permanently deleted.")
        }
    }
}

#Preview {
    NavigationStack {
        ProgressPhotosView()
    }
    .modelContainer(for: ProgressPhoto.self, inMemory: true)
}
