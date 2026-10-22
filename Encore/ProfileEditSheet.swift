import SwiftUI
import PhotosUI
import OSLog

// MARK: - Edit profile
/// Photo, name and club. Name and club are saved on this phone and on the server.
struct ProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileStore = UserProfileStore.shared
    @ObservedObject private var authManager = AuthManager.shared

    @State private var name = ""
    @State private var club = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isSavingPhoto = false
    @State private var imageToCrop: UIImage?
    @State private var savedCount = 0
    @FocusState private var focusedField: Field?

    private enum Field { case name, club }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        photoSection

                        VStack(alignment: .leading, spacing: 10) {
                            HomeSectionHeader(title: "MENO")
                            TextField("", text: $name, prompt: Text("Tvoje meno").foregroundColor(Color.textPlaceholder))
                                .textContentType(.name)
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .club }
                                .onChange(of: name) { _, value in
                                    if value.count > NameRules.maxLength { name = String(value.prefix(NameRules.maxLength)) }
                                }
                                .authFieldChrome()
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HomeSectionHeader(title: "TANEČNÝ KLUB")
                            TextField("", text: $club, prompt: Text("Názov klubu").foregroundColor(Color.textPlaceholder))
                                .textContentType(.organizationName)
                                .focused($focusedField, equals: .club)
                                .submitLabel(.done)
                                .onSubmit(save)
                                .onChange(of: club) { _, value in
                                    if value.count > UserProfileStore.clubMaxLength { club = String(value.prefix(UserProfileStore.clubMaxLength)) }
                                }
                                .authFieldChrome()
                            Text(AppFeatures.coachTools
                                 ? "Meno a klub uvidia tvoji partneri a tréneri a podľa mena ťa nájdu."
                                 : "Meno a klub uvidia tvoji partneri a podľa mena ťa nájdu.")
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Upraviť profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uložiť", action: save)
                        .fontWeight(.bold)
                }
            }
            .onAppear {
                name = profileStore.currentName
                club = profileStore.currentClub
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                loadPhoto(item)
            }
            .sheet(item: Binding(get: { imageToCrop.map(CropTarget.init) }, set: { if $0 == nil { imageToCrop = nil } })) { target in
                AvatarCropperSheet(
                    originalImage: target.image,
                    onSave: { cropped in
                        imageToCrop = nil
                        saveCroppedAvatar(cropped)
                    },
                    onCancel: { imageToCrop = nil }
                )
            }
            .sensoryFeedback(.success, trigger: savedCount)
        }
        .preferredColorScheme(.dark)
    }

    private struct CropTarget: Identifiable {
        let image: UIImage
        var id: ObjectIdentifier { ObjectIdentifier(image) }
    }

    // MARK: Photo
    private var photoSection: some View {
        VStack(spacing: 14) {
            ProfileAvatarView(
                name: name.isEmpty ? profileStore.currentName : name,
                imagePath: profileStore.currentAvatarPath,
                avatarURL: authManager.userAvatarURL,
                size: 104
            )
            .overlay {
                if isSavingPhoto {
                    ProgressView().tint(Color.gold400)
                }
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(isSavingPhoto ? "Ukladám…" : "Zmeniť fotku", systemImage: "photo.on.rectangle")
                        .font(.footnote.weight(.bold))
                        .foregroundColor(Color.gold400)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 40)
                        .background(Color.gold500.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.pressable)
                .disabled(isSavingPhoto)

                if let path = profileStore.currentAvatarPath,
                   let current = MediaResolver.resolveImage(path: path) {
                    Button { imageToCrop = current } label: {
                        Label("Upraviť výrez", systemImage: "crop")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(Color.gold400)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 40)
                            .background(Color.gold500.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.pressable)
                }
            }

            if profileStore.currentAvatarPath != nil {
                Button(role: .destructive, action: removePhoto) {
                    Label("Odstrániť fotku", systemImage: "trash")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Color.latinRed)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.pressable)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: Actions
    private func save() {
        profileStore.saveProfile(name: name, club: club)
        savedCount += 1
        dismiss()
    }

    private func loadPhoto(_ item: PhotosPickerItem) {
        isSavingPhoto = true
        Task {
            defer {
                selectedPhotoItem = nil
                isSavingPhoto = false
            }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            imageToCrop = image
        }
    }

    private func saveCroppedAvatar(_ image: UIImage) {
        isSavingPhoto = true
        let oldPath = profileStore.currentAvatarPath
        let uid = profileStore.activeUserId
        Task {
            defer { isSavingPhoto = false }
            do {
                // Compressing a full photo takes a moment: off the main thread, with the write.
                let filename = try await Task.detached(priority: .userInitiated) { () throws -> String? in
                    guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
                    return try MediaStorageManager.store(data: data, prefix: "profile_\(uid)", fileExtension: "jpg")
                }.value
                guard let filename else { return }
                profileStore.setAvatarPath(filename)
                MediaStorageManager.removeFile(named: oldPath)
                savedCount += 1
            } catch {
                Logger.general.error("Saving profile photo failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func removePhoto() {
        MediaStorageManager.removeFile(named: profileStore.currentAvatarPath)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            profileStore.setAvatarPath(nil)
        }
    }
}

// MARK: - Profile Avatar View (Initial-based Monogram or Photo)

struct ProfileAvatarView: View {
    let name: String
    let imagePath: String?
    var avatarURL: String? = nil
    let size: CGFloat
    
    private var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(separator: " ").prefix(2).compactMap(\.first)
        if !words.isEmpty {
            return String(words).uppercased()
        }
        return trimmed.prefix(1).uppercased().isEmpty ? "T" : String(trimmed.prefix(1)).uppercased()
    }
    
    var body: some View {
        ZStack {
            // Inner base circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.obsidian800, Color.obsidian700],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Photo or Initials Monogram
            if let imagePath, !imagePath.isEmpty, let uiImage = MediaResolver.resolveImage(path: imagePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    default:
                        Text(initials)
                            .font(.system(size: size * 0.38, weight: .black, design: .rounded))
                            .foregroundColor(.gold400)
                            .shadow(color: Color.gold500.opacity(0.4), radius: 6)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                // Luxury Initials Monogram
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .black, design: .rounded))
                    .foregroundColor(.gold400)
                    .shadow(color: Color.gold500.opacity(0.45), radius: 8)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .background(
            // Ambient outer bloom behind the frame
            Circle()
                .fill(Color.gold500.opacity(0.28))
                .frame(width: size + 14, height: size + 14)
                .blur(radius: 10)
        )
        .overlay(
            // Crisp Golden Luxury Rim Frame on top of the photo
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.gold300, Color.gold500, Color.gold400, Color.gold300],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
        )
        .overlay(
            // Inner specular rim for high-end jewelry-grade depth
            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                .padding(1.2)
        )
        .shadow(color: Color.gold500.opacity(0.25), radius: 10, x: 0, y: 3)
    }
}

// MARK: - Avatar Cropper & Positioning Sheet (Interactive Zoom & Pan)

struct AvatarCropperSheet: View {
    let originalImage: UIImage
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let cropSize: CGFloat = 260
    
    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                
                VStack(spacing: 20) {
                    Text("Pohybom a priblížením prispôsob fotku do rámu")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.gold300.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                    
                    Spacer()
                    
                    // Viewport Container
                    ZStack {
                        // Background base
                        Circle()
                            .fill(Color.obsidian800)
                            .frame(width: cropSize, height: cropSize)
                        
                        // User photo with pan and pinch zoom
                        Image(uiImage: originalImage)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(scale)
                            .offset(offset)
                            .frame(width: cropSize, height: cropSize)
                            .clipShape(Circle())
                        
                        // Luxury Outer Frame Rim
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.gold300, Color.gold500, Color.gold400, Color.gold300],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3.5
                            )
                            .frame(width: cropSize, height: cropSize)
                        
                        // Inner specular accent
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                            .frame(width: cropSize - 4, height: cropSize - 4)
                    }
                    .frame(width: cropSize, height: cropSize)
                    .contentShape(Rectangle())
                    .gesture(
                        SimultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                },
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = max(0.5, min(scale * delta, 5.0))
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                    )
                    .shadow(color: Color.gold500.opacity(0.35), radius: 18)
                    
                    Spacer()
                    
                    // Controls: Zoom Slider & Reset button
                    VStack(spacing: 14) {
                        HStack(spacing: 14) {
                            Image(systemName: "minus.magnifyingglass")
                                .foregroundColor(Color.gold400.opacity(0.7))
                                .font(.system(size: 15))
                            
                            Slider(value: $scale, in: 0.6...4.0)
                                .tint(Color.gold400)
                            
                            Image(systemName: "plus.magnifyingglass")
                                .foregroundColor(Color.gold400)
                                .font(.system(size: 15))
                        }
                        .padding(.horizontal, 36)
                        
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                                lastScale = 1.0
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Vycentrovať")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(Color.gold400)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.gold500.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.pressable)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Upraviť fotku")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") { onCancel() }
                        .foregroundColor(Color.white.opacity(0.7))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Použiť") {
                        let cropped = renderCroppedImage()
                        onSave(cropped)
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.gold400)
                }
            }
        }
    }
    
    private func renderCroppedImage() -> UIImage {
        let targetSize: CGFloat = 512
        let ratio = targetSize / cropSize
        
        let imgW = originalImage.size.width
        let imgH = originalImage.size.height
        guard imgW > 0, imgH > 0 else { return originalImage }
        
        let aspect = imgW / imgH
        let baseW: CGFloat
        let baseH: CGFloat
        if aspect > 1.0 {
            baseH = cropSize
            baseW = cropSize * aspect
        } else {
            baseW = cropSize
            baseH = cropSize / aspect
        }
        
        let displayedW = baseW * scale
        let displayedH = baseH * scale
        let imgX = (cropSize - displayedW) / 2.0 + offset.width
        let imgY = (cropSize - displayedH) / 2.0 + offset.height
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetSize, height: targetSize), format: format)
        return renderer.image { _ in
            let circle = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: targetSize, height: targetSize))
            circle.addClip()
            
            originalImage.draw(in: CGRect(
                x: imgX * ratio,
                y: imgY * ratio,
                width: displayedW * ratio,
                height: displayedH * ratio
            ))
        }
    }
}
