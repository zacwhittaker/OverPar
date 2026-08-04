import SwiftUI

struct WatchDistanceView: View {
    @EnvironmentObject private var round: WatchRoundService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if round.isRoundActive {
                activeRound
            } else {
                waiting
            }
        }
        .onAppear { round.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { round.start() } else { round.stop() }
        }
    }

    private var activeRound: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Hole \(round.holeNumber)")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))

            Spacer(minLength: 1)

            if let distance = round.displayDistance {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(distance)")
                        .font(.system(size: 66, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                    Text(round.usesYards ? "yds" : "m")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(distance) \(round.usesYards ? "yards" : "metres") to green reference")
            } else {
                Text("—")
                    .font(.system(size: 66, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(round.accuracyText)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .padding(.top, 1)

            Spacer(minLength: 5)

            if round.rulesCompliant {
                Text("Raw distance")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Text("Use:")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                Text(round.clubName.isEmpty ? "No club suggestion" : round.clubName)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var waiting: some View {
        VStack(spacing: 8) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 32, weight: .bold))
            Text("Start a round on iPhone")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding()
    }
}

#Preview {
    WatchDistanceView()
        .environmentObject(WatchRoundService())
}
