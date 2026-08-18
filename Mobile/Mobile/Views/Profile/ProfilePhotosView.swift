import PhotosUI
import SwiftUI

struct ProfilePhotoItem: Identifiable {
    let id: UUID = UUID()
    var remoteURL: URL?
    var systemFallback: String = "photo"
}

struct ProfilePhotosView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    
    @State private var remotePhotoURLs: [URL] = []
    @State private var showAddPhotosSheet = false
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var showSuccessToast = false
    @State private var selectedPhoto: FacilityPhoto? = nil
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    private var facilityPhotos: [FacilityPhoto] {
        remotePhotoURLs.map { FacilityPhoto(source: .remote($0)) }
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header row: All Photos count & ADD PHOTOS button
                        HStack {
                            Text("\("All Photos".localized) (\(remotePhotoURLs.count))")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Button {
                                showAddPhotosSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("ADD PHOTOS".localized)
                                        .font(.caption.weight(.bold))
                                }
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.1))
                                )
                            }
                        }
                        .padding(.horizontal, PhotoMetrics.gutter)
                        .padding(.top, 12)
                        
                        if remotePhotoURLs.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 40, weight: .light))
                                    .foregroundStyle(.secondary)
                                Text("No Photos Yet")
                                    .font(.headline)
                                Text("Tap ADD PHOTOS to upload images to the community repository.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            PhotoMosaicGrid(
                                photos: facilityPhotos,
                                width: max(proxy.size.width - PhotoMetrics.gutter * 2, 0),
                                onSelect: { selectedPhoto = $0 }
                            )
                            .padding(.horizontal, PhotoMetrics.gutter)
                        }
                    }
                    .padding(.bottom, 40)
                }
                
                // Success Toast Banner
                if showSuccessToast {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.green)
                        
                        Text("Your photos successfully added!".localized)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.primary)
                        
                        Spacer()
                        
                        Button {
                            withAnimation {
                                showSuccessToast = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.green.opacity(0.12))
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .task {
            await loadPhotosFromSupabase()
        }
        .sheet(isPresented: $showAddPhotosSheet) {
            addPhotosSheet
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            FacilityPhotoDetailView(photo: photo)
        }
    }

    @State private var pickedImageData: [Data] = []

    private func loadPhotosFromSupabase() async {
        do {
            let reviews = try await ReviewService.shared.fetchAllReviews()
            var urls: [URL] = []
            for r in reviews {
                if let elevator = r.elevatorPhotoUrls {
                    urls.append(contentsOf: elevator.compactMap { URL(string: $0) })
                }
                if let toilet = r.toiletPhotoUrls {
                    urls.append(contentsOf: toilet.compactMap { URL(string: $0) })
                }
            }
            await MainActor.run {
                self.remotePhotoURLs = urls
            }
        } catch {
            print("ProfilePhotosView: Failed to load photos from Supabase: \(error)")
        }
    }
    
    private var addPhotosSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            // Browse Tile via PhotosPicker
                            PhotosPicker(selection: $selectedPhotosPickerItems, matching: .images) {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.blue.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.blue.opacity(0.04))
                                    )
                                    .frame(height: 160)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.system(size: 28))
                                                .foregroundStyle(Color.blue)
                                            Text("Browse".localized)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.blue)
                                        }
                                    )
                            }
                            .onChange(of: selectedPhotosPickerItems) { oldValue, newItems in
                                Task {
                                    var dataList: [Data] = []
                                    for item in newItems {
                                        if let data = try? await item.loadTransferable(type: Data.self) {
                                            dataList.append(data)
                                        }
                                    }
                                    await MainActor.run { self.pickedImageData = dataList }
                                }
                            }
                            
                            // Selected Draft Photos Grid
                            ForEach(pickedImageData.indices, id: \.self) { idx in
                                ZStack(alignment: .topTrailing) {
                                    if let uiImage = UIImage(data: pickedImageData[idx]) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 160)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                    
                                    Button {
                                        withAnimation {
                                            pickedImageData.remove(at: idx)
                                            if idx < selectedPhotosPickerItems.count {
                                                selectedPhotosPickerItems.remove(at: idx)
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.black)
                                            .padding(6)
                                            .background(Circle().fill(.white))
                                            .shadow(radius: 2)
                                    }
                                    .padding(8)
                                }
                            }
                        }
                        .padding(20)
                    }
                }
                
                // Submit Button
                VStack {
                    Button {
                        Task {
                            isUploading = true
                            for data in pickedImageData {
                                if let urlString = try? await ReviewService.shared.uploadPhoto(jpegData: data),
                                   let url = URL(string: urlString) {
                                    await MainActor.run {
                                        self.remotePhotoURLs.append(url)
                                    }
                                }
                            }
                            await MainActor.run {
                                self.isUploading = false
                                self.pickedImageData.removeAll()
                                self.selectedPhotosPickerItems.removeAll()
                                self.showAddPhotosSheet = false
                                self.showSuccessToast = true
                            }
                        }
                    } label: {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 6)
                            }
                            Text(isUploading ? "Uploading...".localized : "Submit".localized)
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                        )
                    }
                    .disabled(pickedImageData.isEmpty || isUploading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Add Photos".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAddPhotosSheet = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }
}

#Preview {
    ProfilePhotosView()
        .environmentObject(LanguageManager.shared)
}
