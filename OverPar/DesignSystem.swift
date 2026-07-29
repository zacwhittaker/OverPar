import SwiftUI

enum OverParTheme {
    static let forest = Color(red: 0.043, green: 0.302, blue: 0.231)
    static let forestDark = Color(red: 0.031, green: 0.239, blue: 0.18)
    static let mint = Color(red: 0.91, green: 0.973, blue: 0.945)
    static let canvas = Color(red: 0.961, green: 0.973, blue: 0.965)
    static let surface = Color.white
    static let ink = Color(red: 0.075, green: 0.137, blue: 0.114)
    static let secondary = Color(red: 0.325, green: 0.4, blue: 0.369)
    static let line = Color(red: 0.875, green: 0.906, blue: 0.886)
}

struct OverParCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .background(OverParTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(OverParTheme.line, lineWidth: 1))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(.white)
            .background(OverParTheme.forest, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SectionHeading: View {
    var eyebrow: String
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(eyebrow.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(OverParTheme.forest)
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(OverParTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusPill: View {
    var text: String
    var symbol: String = "checkmark.circle.fill"

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(OverParTheme.forest)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(OverParTheme.mint, in: Capsule())
    }
}

struct GolfClubIcon: View {
    let club: GolfClub
    var size: CGFloat = 54
    var selected = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(selected ? Color.white.opacity(0.16) : OverParTheme.mint)
            ClubSilhouette(category: club.category)
                .stroke(
                    selected ? Color.white : OverParTheme.forest,
                    style: StrokeStyle(lineWidth: max(2, size * 0.045), lineCap: .round, lineJoin: .round)
                )
                .padding(size * 0.17)
            Text(club.iconLabel)
                .font(.system(size: size * 0.19, weight: .heavy, design: .rounded))
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
        path.move(to: top)
        path.addLine(to: neck)

        switch category {
        case .driver, .miniDriver:
            path.addCurve(
                to: CGPoint(x: rect.maxX * 0.12, y: rect.maxY * 0.82),
                control1: CGPoint(x: rect.maxX * 0.38, y: rect.maxY * 0.62),
                control2: CGPoint(x: rect.maxX * 0.18, y: rect.maxY * 0.66)
            )
            path.addCurve(
                to: neck,
                control1: CGPoint(x: rect.maxX * 0.04, y: rect.maxY),
                control2: CGPoint(x: rect.maxX * 0.38, y: rect.maxY)
            )
        case .fairwayWood:
            path.addCurve(
                to: CGPoint(x: rect.maxX * 0.14, y: rect.maxY * 0.84),
                control1: CGPoint(x: rect.maxX * 0.38, y: rect.maxY * 0.67),
                control2: CGPoint(x: rect.maxX * 0.18, y: rect.maxY * 0.68)
            )
            path.addCurve(to: neck, control1: CGPoint(x: rect.maxX * 0.12, y: rect.maxY), control2: CGPoint(x: rect.maxX * 0.42, y: rect.maxY))
        case .hybrid:
            path.addLine(to: CGPoint(x: rect.maxX * 0.16, y: rect.maxY * 0.76))
            path.addQuadCurve(to: CGPoint(x: rect.maxX * 0.2, y: rect.maxY * 0.96), control: CGPoint(x: rect.minX, y: rect.maxY * 0.86))
            path.addLine(to: CGPoint(x: rect.maxX * 0.54, y: rect.maxY * 0.9))
            path.closeSubpath()
        case .putter:
            path.addLine(to: CGPoint(x: rect.maxX * 0.42, y: rect.maxY * 0.86))
            path.addLine(to: CGPoint(x: rect.maxX * 0.12, y: rect.maxY * 0.86))
            path.addLine(to: CGPoint(x: rect.maxX * 0.12, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX * 0.58, y: rect.maxY))
        case .chipper:
            path.addLine(to: CGPoint(x: rect.maxX * 0.16, y: rect.maxY * 0.78))
            path.addLine(to: CGPoint(x: rect.maxX * 0.2, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX * 0.58, y: rect.maxY * 0.88))
            path.closeSubpath()
        case .pitchingWedge, .gapWedge, .sandWedge, .lobWedge:
            path.addLine(to: CGPoint(x: rect.maxX * 0.13, y: rect.maxY * 0.74))
            path.addLine(to: CGPoint(x: rect.maxX * 0.24, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX * 0.58, y: rect.maxY * 0.86), control: CGPoint(x: rect.maxX * 0.5, y: rect.maxY))
            path.closeSubpath()
        case .utilityIron, .iron:
            path.addLine(to: CGPoint(x: rect.maxX * 0.12, y: rect.maxY * 0.76))
            path.addLine(to: CGPoint(x: rect.maxX * 0.2, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX * 0.57, y: rect.maxY * 0.9))
            path.closeSubpath()
        case .custom:
            path.addLine(to: CGPoint(x: rect.maxX * 0.18, y: rect.maxY * 0.82))
            path.addLine(to: CGPoint(x: rect.maxX * 0.3, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX * 0.58, y: rect.maxY * 0.88))
        }
        return path
    }
}

extension View {
    func overParPage() -> some View {
        font(.system(.body, design: .rounded))
            .foregroundStyle(OverParTheme.ink)
            .background(OverParTheme.canvas.ignoresSafeArea())
            .preferredColorScheme(.light)
    }

    func overParFormPage() -> some View {
        scrollContentBackground(.hidden)
            .background(OverParTheme.canvas.ignoresSafeArea())
            .font(.system(.body, design: .rounded))
            .foregroundStyle(OverParTheme.ink)
            .preferredColorScheme(.light)
    }
}
