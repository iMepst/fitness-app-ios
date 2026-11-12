import SwiftUI

/// A studio's logo: its image, its monogram (e.g. a white "JR" on black),
/// or the location pin when neither is set.
struct GymBadge: View {
    let gym: Gym?
    var size: CGFloat = 28

    var body: some View {
        Group {
            switch gym?.logo ?? .pin {
            case .image(let data):
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(.rect(cornerRadius: size * 0.26))
                } else {
                    pin
                }
            case .monogram(let text, let hex):
                let background = Color(hex: hex) ?? .accentColor
                Text(text)
                    .font(.system(size: size * (text.count > 2 ? 0.4 : 0.52), weight: .black))
                    .fontWidth(.compressed)
                    .tracking(-0.3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(background.contrastingText)
                    .frame(width: size, height: size)
                    .background(background, in: .rect(cornerRadius: size * 0.26))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.26)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    }
            case .pin:
                pin
            }
        }
        .accessibilityHidden(true)
    }

    private var pin: some View {
        Image(systemName: "mappin.and.ellipse")
            .font(.system(size: size * 0.6))
            .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 16) {
        GymBadge(gym: Gym(name: "John Reed Wandsbek"), size: 44)
        GymBadge(gym: Gym(name: "Studio X"), size: 44)
        GymBadge(gym: nil, size: 44)
    }
    .padding()
}
