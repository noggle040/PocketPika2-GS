import SwiftUI

private enum Palette {
    static let ink = Color(red: 0.17, green: 0.20, blue: 0.30)
    static let blue = Color(red: 0.10, green: 0.24, blue: 0.42)
    static let gold = Color(red: 0.96, green: 0.79, blue: 0.35)
    static let cream = Color(red: 1.00, green: 0.94, blue: 0.77)
    static let lcd = Color(red: 0.69, green: 0.88, blue: 0.77)
    static let aqua = Color(red: 0.39, green: 0.75, blue: 0.72)
    static let magenta = Color(red: 0.76, green: 0.31, blue: 0.53)
}

private enum PikaTab: String, CaseIterable, Identifiable {
    case home = "HABITAT"
    case clock = "STEPS"
    case gift = "GIFT"
    case coin = "CARDS"
    case setup = "SETUP"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .clock: return "clock.fill"
        case .gift: return "gift.fill"
        case .coin: return "suit.spade.fill"
        case .setup: return "gearshape.fill"
        }
    }
}

struct PocketPikaView: View {
    @EnvironmentObject private var store: PocketPikaStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: PikaTab = .home
    @State private var giftAmount = 10

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    header
                    if geometry.size.width >= 720 {
                        HStack(alignment: .top, spacing: 24) {
                            devicePanel.frame(maxWidth: 525)
                            controlsPanel.frame(maxWidth: 455)
                        }
                    } else {
                        VStack(spacing: 20) {
                            devicePanel
                            controlsPanel
                        }
                    }
                    Text("A FAN-MADE COLOR STEP COMPANION • SAVES ON THIS DEVICE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(Palette.cream.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 1050)
                .padding(.horizontal, 15)
                .padding(.top, 15)
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity)
            }
            .background(
                LinearGradient(colors: [Palette.blue, Palette.ink, Color(red: 0.06, green: 0.12, blue: 0.21)],
                               startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            )
            .refreshable { await store.refresh() }
        }
        .tint(Palette.magenta)
        .task { await store.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh() } }
        }
        .onChange(of: tab) { previous, next in
            if previous == .coin && next != .coin { store.leaveCardGame() }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("POCKET PIKA").font(.system(size: 25, weight: .black, design: .rounded)).tracking(1.3)
                Text("COLOR GS • WALK TOGETHER").font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(1.1)
            }
            Spacer(minLength: 8)
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                Text("\(store.watts.formatted()) W")
            }
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Palette.cream.opacity(0.14), in: Capsule())
        }
        .foregroundStyle(Palette.cream)
    }

    private var devicePanel: some View {
        VStack(spacing: 15) {
            HStack {
                Text("POCKET PIKA 2")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                Spacer()
                Text("COLOR")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Palette.blue, in: Capsule())
                    .foregroundStyle(Palette.cream)
            }
            .foregroundStyle(Palette.ink)

            VStack(spacing: 10) {
                HStack {
                    Label(store.currentScene, systemImage: "sun.max.fill")
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(context.date, style: .time)
                    }
                }
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .lineLimit(1)
                PetSceneView(scene: store.currentScene, friendship: store.friendship)
                    .frame(maxWidth: .infinity)
                    .frame(height: 218)
                    .background(Palette.lcd.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
                    .accessibilityLabel("Animated pixel companion, \(store.currentScene.lowercased())")

                Text(store.message)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(minHeight: 40)

                HStack(spacing: 8) {
                    tinyMetric("TODAY", store.todaySteps.formatted())
                    tinyMetric("WATTS", "\(store.watts) W")
                    tinyMetric("BOND", "\(store.friendship)%")
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(14)
            .background(Palette.lcd, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Palette.ink, lineWidth: 5))

            HStack(spacing: 8) {
                Circle().fill(Palette.magenta).frame(width: 10, height: 10)
                Text("20 STEPS = 1 WATT")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                Spacer()
                Image(systemName: "bolt.fill")
            }
            .foregroundStyle(Palette.ink)
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Palette.cream, Palette.gold], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 28)
        )
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Palette.ink, lineWidth: 4))
        .shadow(color: .black.opacity(0.25), radius: 13, y: 8)
    }

    private func tinyMetric(_ heading: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(heading).font(.system(size: 9, weight: .heavy, design: .monospaced))
            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Palette.cream.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
    }

    private var controlsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PikaTab.allCases) { item in
                        Button {
                            tab = item
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: item.symbol).font(.system(size: 16))
                                Text(item.rawValue).font(.system(size: 9, weight: .heavy, design: .monospaced))
                            }
                            .frame(minWidth: 57)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 10)
                            .foregroundStyle(tab == item ? Palette.ink : Palette.cream)
                            .background(tab == item ? Palette.gold : Palette.cream.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Group {
                switch tab {
                case .home: homePanel
                case .clock: stepsPanel
                case .gift: giftPanel
                case .coin: cardPanel
                case .setup: setupPanel
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(17)
        .background(Palette.cream.opacity(0.10), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Palette.cream.opacity(0.18)))
        .foregroundStyle(Palette.cream)
    }

    private var homePanel: some View {
        VStack(alignment: .leading, spacing: 17) {
            sectionTitle("YOUR COMPANION", sub: "Daily scenes change with the time")
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.levelName).font(.system(size: 19, weight: .black, design: .rounded))
                    Text("Friendship").font(.system(size: 11, design: .monospaced))
                }
                Spacer()
                Text("\(store.friendship)/100").font(.system(size: 24, weight: .black, design: .rounded))
            }
            ProgressView(value: Double(store.friendship), total: 100)
                .tint(Palette.gold)
            Button { store.patPika() } label: {
                Label("PAT YOUR FRIEND", systemImage: "hand.raised.fill")
            }.buttonStyle(PikaButtonStyle())
            HStack(spacing: 10) {
                infoTile("NEXT WATT", "\(store.stepsToNextWatt) steps")
                infoTile("ALL-TIME", store.lifetimeSteps.formatted())
            }
            Text(store.milestone)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(Palette.gold)
            Text("Unlike a typical virtual pet, this companion cares for itself. Visit throughout the day to catch different activities.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Palette.cream.opacity(0.75))
        }
    }

    private var stepsPanel: some View {
        VStack(alignment: .leading, spacing: 17) {
            sectionTitle("ACTIVITY CLOCK", sub: "Seven days of real movement")
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 43, weight: .black, design: .monospaced))
            }
            HStack {
                Text("TODAY  \(store.todaySteps.formatted()) / \(store.dailyGoal.formatted())")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                Spacer()
                Text("\(Int(store.dailyProgress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            ProgressView(value: store.dailyProgress)
                .tint(Palette.gold)
            HStack(alignment: .bottom, spacing: 8) {
                if store.lastWeek.isEmpty {
                    Text("Connect a step source to see your week.")
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 90)
                } else {
                    ForEach(store.lastWeek) { day in
                        VStack(spacing: 6) {
                            Text("\(day.steps)")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .minimumScaleFactor(0.55)
                                .lineLimit(1)
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Palette.aqua)
                                .frame(height: max(5, 90 * CGFloat(min(day.steps, 12_000)) / 12_000))
                                .frame(height: 90, alignment: .bottom)
                            Text(day.label.uppercased())
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            infoTile("LIFETIME STEPS", store.lifetimeSteps.formatted())
            Text("Weekly history comes from your selected step source. Watts start accumulating only after you connect it.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.cream.opacity(0.75))
        }
    }

    private var giftPanel: some View {
        VStack(alignment: .leading, spacing: 17) {
            sectionTitle("GIVE A GIFT", sub: "Spending Watts builds friendship")
            HStack {
                Image(systemName: "gift.fill").font(.system(size: 42)).foregroundStyle(Palette.gold)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(store.watts.formatted()) W")
                        .font(.system(size: 27, weight: .black, design: .rounded))
                    Text("AVAILABLE").font(.system(size: 10, weight: .bold, design: .monospaced))
                }
            }
            Text("CHOOSE WATTS")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
            HStack(spacing: 8) {
                ForEach([10, 25, 50, 100], id: \.self) { value in
                    Button("\(value)") { giftAmount = value }
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(giftAmount == value ? Palette.ink : Palette.cream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(giftAmount == value ? Palette.gold : Palette.cream.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 10))
                        .buttonStyle(.plain)
                }
            }
            Button { store.giveWatts(giftAmount) } label: {
                Label("GIVE \(giftAmount) WATTS", systemImage: "heart.fill")
            }
            .buttonStyle(PikaButtonStyle())
            .disabled(store.watts < giftAmount)
            Text("Total Watts gifted: \(store.giftsGiven.formatted())")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Text("Larger gifts earn more friendship. Save your Watts from walking or play higher-or-lower to try to win more.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Palette.cream.opacity(0.75))
        }
    }

    private var cardPanel: some View {
        VStack(alignment: .leading, spacing: 17) {
            sectionTitle("HIGHER OR LOWER", sub: "Pocket Pikachu 2-style card game")
            HStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text(store.currentlyPlaying ? "\(store.currentCard)" : "?")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .frame(width: 115, height: 145)
                        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Palette.magenta)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.gold, lineWidth: 4))
                    Text("CURRENT").font(.system(size: 10, weight: .heavy, design: .monospaced))
                }
                VStack(alignment: .leading, spacing: 9) {
                    Text("BANK: \(store.pendingWin) W")
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                    Text("STREAK: \(store.streak)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                    Text("BEST: \(store.bestStreak)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                    Text("BET: 5 W")
                        .font(.system(size: 12, design: .monospaced))
                }
            }
            Text(store.lastCardResult.isEmpty ? "Guess higher or lower. Correct answers double your pot; ties lose." : store.lastCardResult)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(minHeight: 46, alignment: .leading)
            if store.currentlyPlaying {
                HStack(spacing: 10) {
                    Button("↑ HIGHER") { store.guess(true) }.buttonStyle(PikaButtonStyle())
                    Button("↓ LOWER") { store.guess(false) }.buttonStyle(PikaButtonStyle())
                }
                Button("BANK \(store.pendingWin) W") { store.bankWin() }
                    .buttonStyle(PikaButtonStyle(secondary: true))
            } else {
                Button("BET 5 W • DEAL") { store.startCardGame() }
                    .buttonStyle(PikaButtonStyle())
                    .disabled(store.watts < 5)
            }
            Text("Cards range from 2 through 12. This is a just-for-fun in-app game using earned Watts, not real money.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.cream.opacity(0.75))
        }
    }

    private var setupPanel: some View {
        VStack(alignment: .leading, spacing: 17) {
            sectionTitle("STEP SOURCE", sub: "Choose one source; no double counting")
            HStack {
                Image(systemName: "figure.walk").foregroundStyle(Palette.gold)
                Text("\(store.sourceName)").font(.system(size: 14, weight: .bold, design: .monospaced))
                Spacer()
                if store.isLoading { ProgressView().tint(Palette.gold) }
            }
            Button { store.enableHealth() } label: {
                Label("USE APPLE HEALTH", systemImage: "heart.text.square")
            }.buttonStyle(PikaButtonStyle())
            Button { store.enableMotion() } label: {
                Label("USE IPHONE MOTION", systemImage: "iphone.gen3.radiowaves.left.and.right")
            }.buttonStyle(PikaButtonStyle(secondary: true))
            Button { Task { await store.refresh() } } label: {
                Label("REFRESH STEPS", systemImage: "arrow.clockwise")
            }.buttonStyle(PikaButtonStyle(secondary: true))
            Text("Apple Health requires special signing entitlements. If it shows zero steps after granting access, switch to iPhone Motion and take a short walk to test. Motion-only history is limited by iOS.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Palette.cream.opacity(0.75))
            Text("There is no infrared Mystery Gift transfer to Pokémon Gold/Silver/Crystal. Your progress stays private and on your device.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.cream.opacity(0.65))
        }
    }

    private func sectionTitle(_ title: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 21, weight: .black, design: .rounded))
            Text(sub).font(.system(size: 12, design: .rounded)).foregroundStyle(Palette.cream.opacity(0.70))
        }
    }

    private func infoTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 10, weight: .heavy, design: .monospaced))
            Text(value).font(.system(size: 20, weight: .black, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.cream.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct PikaButtonStyle: ButtonStyle {
    var secondary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .foregroundStyle(secondary ? Palette.cream : Palette.ink)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 15)
            .background(secondary ? Palette.cream.opacity(0.15) : Palette.gold, in: RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct PetSceneView: View {
    let scene: String
    let friendship: Int

    private var sceneIcon: String {
        switch scene {
        case "BREAKFAST": return "fork.knife"
        case "STROLLING": return "figure.walk"
        case "PLAYTIME": return "figure.run"
        case "BATH TIME": return "drop.fill"
        case "SLEEPY", "DREAMING": return "moon.zzz.fill"
        default: return "cloud.sun.fill"
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.75)) { timeline in
            let pulse = Int(timeline.date.timeIntervalSince1970 * 2) % 2 == 0
            ZStack {
                GeometryReader { geo in
                    Canvas { context, size in
                        let horizon = CGRect(x: 0, y: size.height * 0.77, width: size.width, height: size.height * 0.23)
                        context.fill(Path(horizon), with: .color(Color(red: 0.45, green: 0.67, blue: 0.55)))
                        for index in 0..<7 {
                            let px = CGFloat(index) * size.width / 7
                            let rect = CGRect(x: px, y: size.height * (0.78 + (index % 2 == 0 ? 0.02 : 0.08)), width: 5, height: 12)
                            context.fill(Path(rect), with: .color(Palette.blue.opacity(0.48)))
                        }
                    }
                    PixelPalView(eyesClosed: scene == "SLEEPY" || scene == "DREAMING", wave: pulse)
                        .frame(width: min(geo.size.width * 0.78, 290), height: geo.size.height * 0.84)
                        .position(x: geo.size.width / 2, y: geo.size.height * (pulse ? 0.47 : 0.49))
                }
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: sceneIcon)
                            .font(.system(size: 27, weight: .black))
                            .foregroundStyle(Palette.blue.opacity(0.8))
                            .padding(12)
                    }
                    Spacer()
                    HStack {
                        Text(friendship >= 80 ? "♥ ♥ ♥" : friendship >= 40 ? "♥ ♥" : "♥")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(Palette.magenta)
                        Spacer()
                        Text(scene == "DREAMING" || scene == "SLEEPY" ? "Z z z" : (pulse ? "♪" : "♫"))
                            .font(.system(size: 17, weight: .black, design: .monospaced))
                            .foregroundStyle(Palette.blue)
                    }
                }
                .padding(10)
            }
        }
    }
}

// Hand-drawn, original pixel companion: no game ROMs or ripped sprites.
private struct PixelPalView: View {
    let eyesClosed: Bool
    let wave: Bool

    private let pixels = [
        ".......KK................KK.......",
        ".......KYYK..............KYYK......",
        ".......KYYYK............KYYYK......",
        "........KYYYK..........KYYYK.......",
        "........KYYYYK........KYYYYK.......",
        ".........KYYYYKKKKKKKKYYYYK........",
        ".........KYYYYYYYYYYYYYYYYK........",
        "........KYYYYYYYYYYYYYYYYYYK.......",
        ".......KYYYYYYYYYYYYYYYYYYYYK......",
        ".......KYYYYYYYYYYYYYYYYYYYYK......",
        "......KYYYYYKYYYYYYYYKYYYYYYK.....",
        "......KYYYYKKYYYYYYYYKKYYYYYK.....",
        "......KYYYYKKYYYYYYYYKKYYYYYK.....",
        "......KYYYYYYYYBKKBYYYYYYYYYK.....",
        "......KYYRYYYYYYYYYYYYYYYYRYYK.....",
        ".......KRRRYYYYYYYYYYYYRRRK.......",
        ".......KYYYYYYYYYYYYYYYYYYK.......",
        "........KYYYYYYYYYYYYYYYYK........",
        ".........KKYYYYYYYYYYYYKK.........",
        "..........KYYYYYYYYYYK...........",
        ".........KYYYYYYYYYYYYK..........",
        "........KYYYYYYYYYYYYYYK.........",
        "........KKYYYYYKKYYYYYKK.........",
        "..........KKKKK..KKKKK..........."
    ]

    var body: some View {
        Canvas { context, size in
            let lines = pixels.map { Array($0) }
            let columns = lines.map(\.count).max() ?? 1
            let unit = min(size.width / CGFloat(columns), size.height / CGFloat(lines.count))
            let xOffset = (size.width - CGFloat(columns) * unit) / 2
            let yOffset = (size.height - CGFloat(lines.count) * unit) / 2
            for (y, line) in lines.enumerated() {
                for (x, item) in line.enumerated() {
                    var character = item
                    // Two-frame blinking animation for the eyes.
                    if eyesClosed && (y == 11 || y == 12), character == "K" { character = "B" }
                    let tint: Color
                    switch character {
                    case "K": tint = Palette.ink
                    case "Y": tint = Color(red: 0.99, green: 0.79, blue: 0.19)
                    case "R": tint = Color(red: 0.93, green: 0.37, blue: 0.35)
                    case "B": tint = Color(red: 0.44, green: 0.32, blue: 0.28)
                    default: continue
                    }
                    let pixel = CGRect(x: xOffset + CGFloat(x) * unit, y: yOffset + CGFloat(y) * unit,
                                       width: ceil(unit), height: ceil(unit))
                    context.fill(Path(pixel), with: .color(tint))
                }
            }
            if wave {
                let spark = CGRect(x: size.width * 0.78, y: size.height * 0.22, width: max(3, unit), height: max(3, unit))
                context.fill(Path(spark), with: .color(Palette.gold))
            }
        }
        .drawingGroup(opaque: false, colorMode: .nonLinear)
    }
}
