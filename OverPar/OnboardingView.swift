import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var location: LocationService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var step = 0
    @State private var name = "Zac Whittaker"
    @State private var username = "zacwhittaker"
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 0) {
            if step > 0 { progressHeader }
            Group {
                switch step {
                case 0: welcome
                case 1: identity
                case 2: preferences
                case 3: locationPermission
                default: homeCourse
                }
            }
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .opacity
            ))
        }
        .fontDesign(.rounded)
        .foregroundStyle(OverParTheme.ink)
        .background(OverParTheme.canvas.ignoresSafeArea())
        .preferredColorScheme(.light)
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: step)
    }

    private var progressHeader: some View {
        HStack(spacing: 18) {
            Button {
                withAnimation { step -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(.white, in: Circle())
                    .overlay(Circle().stroke(OverParTheme.line))
            }
            .accessibilityLabel("Back")

            HStack(spacing: 7) {
                ForEach(1...4, id: \.self) { page in
                    Capsule()
                        .fill(page <= step ? OverParTheme.forest : OverParTheme.line)
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                }
            }
            .accessibilityLabel("Step \(step) of 4")
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var welcome: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    welcomeArtwork(width: min(geometry.size.width - 88, 238))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 26)

                    Label("OverPar", systemImage: "figure.golf")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(OverParTheme.forest)
                        .padding(.top, 24)

                    Text("Your round,\nbeautifully simple.")
                        .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 36 : 39, weight: .heavy, design: .rounded))
                        .tracking(-1.1)
                        .lineSpacing(-2)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.82)
                        .padding(.top, 12)

                    Text("Find courses, trust your distance and keep every round in one friendly place.")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(OverParTheme.secondary)
                        .lineSpacing(4)
                        .padding(.top, 14)

                    VStack(spacing: 14) {
                        Button("Get started") { step = 1 }
                            .buttonStyle(PrimaryButtonStyle())

                        Text("Private by default · Built for the course")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(OverParTheme.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func welcomeArtwork(width: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [OverParTheme.mint, Color.white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .stroke(OverParTheme.forest.opacity(0.08), lineWidth: 1)
            Image(systemName: "figure.golf")
                .font(.system(size: width * 0.34, weight: .medium))
                .foregroundStyle(OverParTheme.forest)
            Image(systemName: "flag.fill")
                .font(.system(size: width * 0.13, weight: .bold))
                .foregroundStyle(OverParTheme.forestDark)
                .offset(x: width * 0.31, y: -width * 0.23)
            Circle()
                .fill(.white)
                .frame(width: width * 0.075)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                .offset(x: -width * 0.27, y: width * 0.27)
        }
        .frame(width: width, height: width)
        .accessibilityHidden(true)
    }

    private var identity: some View {
        onboardingPage(
            eyebrow: "Make it yours",
            title: "Welcome to your clubhouse.",
            subtitle: "Set up the profile your friends will recognise."
        ) {
            VStack(spacing: 14) {
                onboardingField("Display name", value: $name, symbol: "person.fill", contentType: .name)
                onboardingField("Username", value: $username, symbol: "at", contentType: .username, autocapitalise: false)
                onboardingField("Email", value: $email, symbol: "envelope.fill", contentType: .emailAddress, autocapitalise: false)
                secureOnboardingField("Password", value: $password)
            }

            Text("Your username is public. Your email and exact location never appear on your profile.")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(OverParTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Create my clubhouse") {
                store.profile.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                store.profile.username = username
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
                step = 2
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || username.trimmingCharacters(in: .whitespaces).count < 3)
        }
    }

    private var preferences: some View {
        onboardingPage(
            eyebrow: "Your game",
            title: "Make it feel like yours.",
            subtitle: "Choose the defaults we’ll use around the course."
        ) {
            onboardingCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("DISTANCES").fieldCaption()
                    Picker("Distances", selection: $store.profile.units) {
                        Text("Yards").tag("yards")
                        Text("Metres").tag("metres")
                    }
                    .pickerStyle(.segmented)
                }
            }

            onboardingCard {
                VStack(spacing: 0) {
                    onboardingToggle(
                        "Right-handed",
                        detail: "Used to describe draws, fades and misses.",
                        symbol: "figure.golf",
                        value: $store.profile.isRightHanded
                    )
                    Divider().padding(.leading, 48)
                    onboardingToggle(
                        "Golf assistant",
                        detail: "Personal club suggestions in casual rounds.",
                        symbol: "sparkles",
                        value: $store.profile.assistantEnabled
                    )
                }
            }

            Button("Continue") { step = 3 }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var locationPermission: some View {
        onboardingPage(
            eyebrow: "Nearby courses",
            title: "Golf starts where you are.",
            subtitle: "Location powers nearby courses, honest distances and GPS shot logging."
        ) {
            VStack(spacing: 18) {
                ZStack {
                    ForEach([150.0, 112.0, 74.0], id: \.self) { size in
                        Circle()
                            .stroke(OverParTheme.forest.opacity(size == 74 ? 0.26 : 0.1), lineWidth: 2)
                            .frame(width: size, height: size)
                    }
                    Image(systemName: "location.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(OverParTheme.forest)
                }
                .frame(maxWidth: .infinity)

                onboardingCard {
                    VStack(alignment: .leading, spacing: 12) {
                        permissionPoint("Only while OverPar is open", "iphone")
                        permissionPoint("Never shown on your public profile", "lock.fill")
                        permissionPoint("You can continue without it", "hand.raised.fill")
                    }
                }
            }

            Button("Enable nearby courses") {
                location.requestForegroundPermission()
                step = 4
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Not now") { step = 4 }
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(OverParTheme.forest)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var homeCourse: some View {
        onboardingPage(
            eyebrow: "One last thing",
            title: "Pick your home course.",
            subtitle: "Pin one for quick access, or skip and choose later."
        ) {
            VStack(spacing: 12) {
                ForEach(store.courses.prefix(3)) { course in
                    Button {
                        store.profile.homeCourseID = course.id
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "flag.fill")
                                .font(.title3)
                                .foregroundStyle(OverParTheme.forest)
                                .frame(width: 44, height: 44)
                                .background(OverParTheme.mint, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(course.name)
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                Text("\(course.city) · \(course.roundHoleCount) holes · Par \(course.roundTotalPar)")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(OverParTheme.secondary)
                            }
                            Spacer()
                            Image(systemName: store.profile.homeCourseID == course.id ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(store.profile.homeCourseID == course.id ? OverParTheme.forest : OverParTheme.line)
                        }
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(OverParTheme.line))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Enter OverPar") {
                store.profile.hasCompletedOnboarding = true
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Choose later") {
                store.profile.homeCourseID = nil
                store.profile.hasCompletedOnboarding = true
            }
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(OverParTheme.forest)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func onboardingPage<Content: View>(
        eyebrow: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(eyebrow.uppercased())
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(OverParTheme.forest)
                    Text(title)
                        .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 32 : 35, weight: .heavy, design: .rounded))
                        .tracking(-0.8)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(OverParTheme.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 4)

                content()
                Spacer(minLength: 28)
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
    }

    private func onboardingField(
        _ label: String,
        value: Binding<String>,
        symbol: String,
        contentType: UITextContentType?,
        autocapitalise: Bool = true
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(OverParTheme.forest)
                .frame(width: 22)
            TextField(label, text: value)
                .textContentType(contentType)
                .textInputAutocapitalization(autocapitalise ? .words : .never)
                .autocorrectionDisabled(!autocapitalise)
                .foregroundStyle(OverParTheme.ink)
                .tint(OverParTheme.forest)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(OverParTheme.line, lineWidth: 1.2))
    }

    private func secureOnboardingField(_ label: String, value: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundStyle(OverParTheme.forest)
                .frame(width: 22)
            SecureField(label, text: value)
                .textContentType(.newPassword)
                .foregroundStyle(OverParTheme.ink)
                .tint(OverParTheme.forest)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(OverParTheme.line, lineWidth: 1.2))
    }

    private func onboardingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(OverParTheme.line))
    }

    private func onboardingToggle(
        _ title: String,
        detail: String,
        symbol: String,
        value: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(OverParTheme.forest)
                .frame(width: 36, height: 36)
                .background(OverParTheme.mint, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.headline, design: .rounded, weight: .bold))
                Text(detail).font(.system(.caption, design: .rounded)).foregroundStyle(OverParTheme.secondary)
            }
            Spacer()
            Toggle("", isOn: value).labelsHidden()
        }
        .padding(.vertical, 7)
    }

    private func permissionPoint(_ text: String, _ symbol: String) -> some View {
        Label {
            Text(text).font(.system(.subheadline, design: .rounded, weight: .semibold))
        } icon: {
            Image(systemName: symbol).foregroundStyle(OverParTheme.forest)
        }
    }
}

private extension View {
    func fieldCaption() -> some View {
        font(.system(.caption, design: .rounded, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(OverParTheme.secondary)
    }
}
