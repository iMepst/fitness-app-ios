import SwiftUI
import PhotosUI

/// "Logo" section of the studio editor: load from the website, pick a photo,
/// or set a short monogram with a colour. Without any of these the pin is shown.
struct GymLogoSection: View {
    @Bindable var gym: Gym

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        Section {
            HStack(spacing: 14) {
                GymBadge(gym: gym, size: 52)
                    .animation(.snappy, value: gym.logo)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary)
                        .font(.subheadline.weight(.semibold))
                    Text("Erscheint oben links im Studio-Menü.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)

            if let website = gym.logoWebsite {
                Button {
                    Task { await loadFromWebsite(website) }
                } label: {
                    HStack {
                        Label("Logo von Website laden", systemImage: "globe")
                        Spacer()
                        if isLoading { ProgressView() }
                    }
                }
                .disabled(isLoading)
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Bild auswählen", systemImage: "photo")
            }

            if gym.logoData != nil {
                Button("Bild entfernen", systemImage: "trash", role: .destructive) {
                    withAnimation { gym.logoData = nil }
                }
                .tint(.red)
            } else {
                TextField("Kürzel, z. B. JR", text: monogramBinding)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                ColorPicker("Farbe", selection: colorBinding, supportsOpacity: false)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Logo")
        } footer: {
            Text("Ohne Bild und Kürzel zeigt die App eine Standortnadel. Bekannte Ketten wie John Reed haben ein vorgegebenes Kürzel.")
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await usePhoto(item) }
        }
    }

    private var summary: String {
        switch gym.logo {
        case .image: "Logo-Bild"
        case .monogram(let text, _): "Kürzel „\(text)“"
        case .pin: "Kein Logo"
        }
    }

    private var monogramBinding: Binding<String> {
        Binding {
            gym.monogram
        } set: {
            gym.monogram = Gym.cleanMonogram($0)
        }
    }

    private var colorBinding: Binding<Color> {
        Binding {
            if let color = Color(hex: gym.monogramColorHex) { return color }
            if let brand = GymBrand.preset(for: gym.name), let color = Color(hex: brand.backgroundHex) { return color }
            return .accentColor
        } set: {
            gym.monogramColorHex = $0.hexString
        }
    }

    private func loadFromWebsite(_ website: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let data = try await GymLogoLoader.load(from: website)
            withAnimation { gym.logoData = data }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Logo konnte nicht geladen werden. Bist du online?"
        }
    }

    private func usePhoto(_ item: PhotosPickerItem) async {
        errorMessage = nil
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let png = GymLogoLoader.normalized(image)
        else {
            errorMessage = "Das Bild konnte nicht geladen werden."
            return
        }
        withAnimation { gym.logoData = png }
    }
}
