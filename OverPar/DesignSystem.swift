import SwiftUI
import UIKit

struct CourseCoverImage: View {
    @EnvironmentObject private var store: AppStore
    let course: GolfCourse?

    var body: some View {
        CourseCoverArtwork(image: resolvedImage)
            .accessibilityHidden(true)
    }

    private var resolvedImage: UIImage {
        if let course,
           let data = store.courseCoverData(for: course),
           let image = UIImage(data: data) {
            return image
        }
        return UIImage(named: CourseCoverProcessor.defaultAssetName) ?? UIImage()
    }
}

struct CourseCoverArtwork: View {
    let image: UIImage

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }
}

enum CourseCoverProcessor {
    static let defaultAssetName = "CourseMorning"

    static var outputPixelSize: CGSize {
        guard let cgImage = UIImage(named: defaultAssetName)?.cgImage else {
            return CGSize(width: 1122, height: 1402)
        }
        return CGSize(width: cgImage.width, height: cgImage.height)
    }

    static func prepare(_ data: Data) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            return nil
        }

        let outputSize = outputPixelSize
        let scale = max(
            outputSize.width / image.size.width,
            outputSize.height / image.size.height
        )
        let drawnSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let origin = CGPoint(
            x: (outputSize.width - drawnSize.width) / 2,
            y: (outputSize.height - drawnSize.height) / 2
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.jpegData(withCompressionQuality: 0.84) { _ in
            image.draw(in: CGRect(origin: origin, size: drawnSize))
        }
    }

    static func hasExpectedPixelSize(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        return CGSize(width: cgImage.width, height: cgImage.height) == outputPixelSize
    }
}

enum OverParTheme {
    // MARK: Semantic colour
    static let forest = Color(light: 0x0B4A36, dark: 0x71D5A8)
    static let forestDark = Color(light: 0x063426, dark: 0xD8F7E8)
    static let secondaryGreen = Color(light: 0x557B4B, dark: 0x9BC58F)
    static let accent = Color(light: 0xD6A742, dark: 0xF1C96D)
    static let canvas = Color(light: 0xF3F5F0, dark: 0x09110E)
    static let surface = Color(light: 0xFFFEFA, dark: 0x121C18)
    static let secondarySurface = Color(light: 0xE8EEE6, dark: 0x1A2721)
    static let mint = Color(light: 0xDDEDE2, dark: 0x19372A)
    static let ink = Color(light: 0x102019, dark: 0xF1F6F2)
    static let secondary = Color(light: 0x5E6D65, dark: 0xA7B5AD)
    static let tertiary = Color(light: 0x829087, dark: 0x7D8F85)
    static let line = Color(light: 0xD8E0DA, dark: 0x2A3932)
    static let success = Color(light: 0x148357, dark: 0x52D39A)
    static let warning = Color(light: 0xA96912, dark: 0xF1B653)
    static let danger = Color(light: 0xB43B3B, dark: 0xFF7772)
    static let info = Color(light: 0x286DA3, dark: 0x6ABAF1)

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let page: CGFloat = 20
    }

    enum Radius {
        static let control: CGFloat = 14
        static let card: CGFloat = 20
        static let feature: CGFloat = 28
    }

    enum Shadow {
        static let small = (color: Color.black.opacity(0.06), radius: CGFloat(8), y: CGFloat(3))
        static let medium = (color: Color.black.opacity(0.09), radius: CGFloat(18), y: CGFloat(8))
        static let large = (color: Color.black.opacity(0.14), radius: CGFloat(30), y: CGFloat(14))
    }

    enum Motion {
        static let press = Animation.easeOut(duration: 0.11)
        static let selection = Animation.spring(response: 0.28, dampingFraction: 0.84)
        static let reveal = Animation.spring(response: 0.48, dampingFraction: 0.88)
    }
}

private extension Color {
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1
        )
    }
}

enum OverParCardStyle {
    case standard, secondary, elevated, hero
}

struct OverParCard<Content: View>: View {
    var style: OverParCardStyle = .standard
    @ViewBuilder var content: Content

    private var fill: Color {
        style == .secondary ? OverParTheme.secondarySurface : OverParTheme.surface
    }

    private var radius: CGFloat {
        style == .hero ? OverParTheme.Radius.feature : OverParTheme.Radius.card
    }

    var body: some View {
        content
            .padding(style == .hero ? OverParTheme.Space.lg : OverParTheme.Space.md)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(OverParTheme.line.opacity(style == .elevated ? 0.45 : 0.8), lineWidth: 0.75)
            }
            .shadow(
                color: style == .elevated || style == .hero ? OverParTheme.Shadow.medium.color : .clear,
                radius: OverParTheme.Shadow.medium.radius,
                y: OverParTheme.Shadow.medium.y
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(.white)
            .background(OverParTheme.forest, in: RoundedRectangle(cornerRadius: OverParTheme.Radius.control, style: .continuous))
            .shadow(color: OverParTheme.forest.opacity(configuration.isPressed ? 0.08 : 0.18), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(OverParTheme.Motion.press, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(OverParTheme.forest)
            .background(OverParTheme.mint, in: RoundedRectangle(cornerRadius: OverParTheme.Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: OverParTheme.Radius.control).stroke(OverParTheme.forest.opacity(0.12)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(OverParTheme.Motion.press, value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 46, height: 46)
            .foregroundStyle(OverParTheme.ink)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.42), lineWidth: 0.75))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(OverParTheme.Motion.press, value: configuration.isPressed)
    }
}

struct SectionHeading: View {
    var eyebrow: String
    var title: String
    var action: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: OverParTheme.Space.md) {
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.35)
                    .foregroundStyle(OverParTheme.secondaryGreen)
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .tracking(-0.35)
                    .foregroundStyle(OverParTheme.ink)
            }
            Spacer()
            if let action, let onAction {
                Button(action, action: onAction)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(OverParTheme.forest)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusPill: View {
    var text: String
    var symbol: String = "checkmark.seal.fill"
    var tone: Color = OverParTheme.forest

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(tone)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tone.opacity(0.11), in: Capsule())
    }
}

struct OverParMetric: View {
    let value: String
    let label: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(OverParTheme.secondary)
            if let detail {
                Text(detail)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(OverParTheme.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OverParEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: OverParTheme.Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(OverParTheme.forest)
                .frame(width: 76, height: 76)
                .background(OverParTheme.mint, in: Circle())
            VStack(spacing: 6) {
                Text(title).font(.system(.title3, design: .rounded, weight: .bold))
                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(OverParTheme.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OverParTheme.Space.xxl)
        .padding(.horizontal, OverParTheme.Space.lg)
    }
}

struct CourseArtwork: View {
    var compact = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.25, blue: 0.17), Color(red: 0.20, green: 0.43, blue: 0.24)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Ellipse()
                    .fill(Color(red: 0.36, green: 0.61, blue: 0.30))
                    .frame(width: proxy.size.width * 0.86, height: proxy.size.height * 0.47)
                    .rotationEffect(.degrees(-13))
                    .offset(x: proxy.size.width * 0.10, y: proxy.size.height * 0.19)
                Ellipse()
                    .fill(Color(red: 0.55, green: 0.73, blue: 0.39))
                    .frame(width: proxy.size.width * 0.33, height: proxy.size.height * 0.24)
                    .offset(x: proxy.size.width * 0.23, y: -proxy.size.height * 0.16)
                Circle()
                    .fill(Color(red: 0.80, green: 0.69, blue: 0.42))
                    .frame(width: compact ? 22 : 34)
                    .offset(x: -proxy.size.width * 0.25, y: proxy.size.height * 0.18)
                Image(systemName: "flag.fill")
                    .font(.system(size: compact ? 17 : 24, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: proxy.size.width * 0.25, y: -proxy.size.height * 0.16)
            }
        }
        .accessibilityHidden(true)
    }
}

// Original vector club marks avoid mixing unrelated symbols into the bag.
struct GolfClubIcon: View {
    let club: GolfClub
    var size: CGFloat = 54
    var selected = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(selected ? Color.white.opacity(0.15) : OverParTheme.mint)
            ClubSilhouette(category: club.category)
                .stroke(selected ? Color.white : OverParTheme.forest, style: StrokeStyle(lineWidth: max(2, size * 0.045), lineCap: .round, lineJoin: .round))
                .padding(size * 0.17)
            Text(club.iconLabel)
                .font(.system(size: size * 0.18, weight: .heavy, design: .monospaced))
                .foregroundStyle(selected ? OverParTheme.forest : .white)
                .padding(.horizontal, size * 0.09)
                .padding(.vertical, size * 0.035)
                .background(selected ? Color.white : OverParTheme.forest, in: Capsule())
                .offset(x: size * 0.26, y: size * 0.27)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct ClubSilhouette: Shape {
    let category: ClubCategory
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = CGPoint(x: rect.maxX * 0.69, y: rect.minY)
        let neck = CGPoint(x: rect.maxX * 0.48, y: rect.maxY * 0.68)
        path.move(to: top); path.addLine(to: neck)
        switch category {
        case .driver, .miniDriver, .fairwayWood:
            path.addCurve(to: CGPoint(x: rect.maxX * 0.12, y: rect.maxY * 0.82), control1: CGPoint(x: rect.maxX * 0.38, y: rect.maxY * 0.62), control2: CGPoint(x: rect.maxX * 0.18, y: rect.maxY * 0.66))
            path.addCurve(to: neck, control1: CGPoint(x: rect.maxX * 0.04, y: rect.maxY), control2: CGPoint(x: rect.maxX * 0.38, y: rect.maxY))
        case .putter:
            path.addLine(to: CGPoint(x: rect.maxX * 0.42, y: rect.maxY * 0.86)); path.addLine(to: CGPoint(x: rect.maxX * 0.12, y: rect.maxY * 0.86)); path.addLine(to: CGPoint(x: rect.maxX * 0.12, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.maxX * 0.58, y: rect.maxY))
        default:
            path.addLine(to: CGPoint(x: rect.maxX * 0.14, y: rect.maxY * 0.76)); path.addLine(to: CGPoint(x: rect.maxX * 0.22, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.maxX * 0.58, y: rect.maxY * 0.88)); path.closeSubpath()
        }
        return path
    }
}

extension View {
    func overParPage() -> some View {
        font(.system(.body, design: .rounded))
            .foregroundStyle(OverParTheme.ink)
            .background(OverParTheme.canvas.ignoresSafeArea())
            .toolbarBackground(.automatic, for: .navigationBar)
    }

    func overParFormPage() -> some View {
        scrollContentBackground(.hidden)
            .background(OverParTheme.canvas.ignoresSafeArea())
            .font(.system(.body, design: .rounded))
            .foregroundStyle(OverParTheme.ink)
    }
}
