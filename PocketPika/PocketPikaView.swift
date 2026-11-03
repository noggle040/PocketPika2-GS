import SwiftUI
import UniformTypeIdentifiers

private enum ShellColor {
    static let caseSilver = Color(red: 0.99, green: 0.75, blue: 0.14)
    static let caseBright = Color(red: 1.00, green: 0.92, blue: 0.39)
    static let caseDark = Color(red: 0.77, green: 0.48, blue: 0.09)
    static let bezel = Color(red: 0.095, green: 0.14, blue: 0.23)
    static let lcd = Color(red: 0.70, green: 0.86, blue: 0.67)
    static let lcdShade = Color(red: 0.48, green: 0.68, blue: 0.49)
    static let ink = Color(red: 0.12, green: 0.21, blue: 0.18)
    static let back = Color(red: 0.07, green: 0.11, blue: 0.18)
    static let bright = Color(red: 0.99, green: 0.96, blue: 0.86)
}

private enum DevicePage: Int, CaseIterable, Identifiable {
    case companion, steps, presents, cards, friend, options
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .companion: return "PIKA"
        case .steps: return "STEPS"
        case .presents: return "GIFT"
        case .cards: return "CARDS"
        case .friend: return "FRIEND"
        case .options: return "OPTIONS"
        }
    }
    var symbol: String {
        switch self {
        case .companion: return "house.fill"
        case .steps: return "clock.fill"
        case .presents: return "gift.fill"
        case .cards: return "suit.club.fill"
        case .friend: return "heart.fill"
        case .options: return "gearshape.fill"
        }
    }
}

struct PocketPikaView: View {
    @EnvironmentObject private var store: PocketPikaStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sprites = SpriteLibrary()
    @State private var page: DevicePage = .companion
    @State private var giftAmount = 10
    @State private var stepsPage = 0
    @State private var showingSetup = false
    @State private var showingOptions = false

    var body: some View {
        GeometryReader { geometry in
            // The Duo's cover is portrait (about 1:1.45) while the inner display
            // is landscape. Use the actual available shape rather than an arbitrary
            // minimum width, so the outer screen is always a full handheld.
            let unfolded = geometry.size.width > geometry.size.height * 1.10
            ZStack {
                if unfolded {
                    let deviceScale = min((geometry.size.width * 0.50) / 320, (geometry.size.height - 18) / 470)
                    HStack(spacing: 12) {
                        handheld
                            .frame(width: 320, height: 470)
                            .scaleEffect(deviceScale)
                            .frame(width: 320 * deviceScale, height: 470 * deviceScale)
                        ScrollView {
                            expandedPanel
                                .padding(.vertical, 10)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(.horizontal, 12)
                } else {
                    let scale = min(geometry.size.width / 320, geometry.size.height / 470)
                    handheld
                        .frame(width: 320, height: 470)
                        .scaleEffect(scale)
                        .frame(width: 320 * scale, height: 470 * scale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(unfolded ? ShellColor.back : ShellColor.caseBright)
        }
        .ignoresSafeArea(.container, edges: .all)
        .statusBarHidden()
        .sheet(isPresented: $showingSetup) {
            StepSourceSheet(store: store, showDismiss: false)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingOptions) {
            DeviceOptionsSheet(store: store, sprites: sprites)
                .presentationDetents([.medium, .large])
        }
        .task {
            if store.sourceName == "Not connected" { showingSetup = true }
            await store.refresh()
            if sprites.galleryCount == 0 { await sprites.syncFromSerebii() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh() } }
        }
    }

    // One 320 x 470 virtual handheld. On the Duo's closed cover display,
    // it scales to the full screen instead of being placed inside a scrolling card.
    private var handheld: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(ShellColor.caseDark.opacity(0.75))
                .frame(width: 70, height: 5)
                .padding(.top, 13)
                .padding(.bottom, 7)

            VStack(spacing: 3) {
                HStack(spacing: 0) {
                    Text("COLOR").font(.system(size: 8, weight: .heavy, design: .monospaced))
                    Spacer()
                    Text("GS").font(.system(size: 19, weight: .black, design: .rounded)).italic()
                }
                .foregroundStyle(ShellColor.bright)
                .padding(.horizontal, 19)
                .frame(height: 25)

                lcdScreen
                    .frame(width: 256, height: 193)
                    .padding(.horizontal, 11)

                Text("POKÉMON PIKACHU 2")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(ShellColor.bright)
                    .frame(height: 18)
            }
            .padding(.vertical, 7)
            .frame(width: 296, height: 259)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 25, bottomLeadingRadius: 39, bottomTrailingRadius: 39, topTrailingRadius: 25)
                    .fill(LinearGradient(colors: [Color(red: 0.15, green: 0.20, blue: 0.27), ShellColor.bezel], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .padding(.top, 5)

            HStack(alignment: .center, spacing: 0) {
                dpad
                    .frame(width: 118, alignment: .leading)
                VStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 36, weight: .black))
                        .rotationEffect(.degrees(-24))
                    Text("PIKA")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                }
                .foregroundStyle(ShellColor.bezel.opacity(0.86))
                .frame(width: 67)
                VStack(spacing: 13) {
                    circleButton("A", size: 52, action: tapA)
                    circleButton("B", size: 39, action: tapB)
                        .offset(x: -17)
                }
                .frame(width: 91, alignment: .trailing)
            }
            .frame(width: 294, height: 130)

            HStack(spacing: 35) {
                ovalButton("SELECT") { page = .friend }
                ovalButton("START") { showingOptions = true }
            }
            .frame(height: 35)

            Spacer(minLength: 0)
            Text("POCKET PIKA GS  ·  YELLOW v0.5.2")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(0.45)
                .foregroundStyle(ShellColor.bezel.opacity(0.7))
                .frame(height: 15)
        }
        .frame(width: 320, height: 470)
        .background(
            LinearGradient(colors: [ShellColor.caseBright, ShellColor.caseSilver, ShellColor.caseBright],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay { GlitterSurface().allowsHitTesting(false) }
        .clipShape(RoundedRectangle(cornerRadius: 35))
        .overlay(RoundedRectangle(cornerRadius: 35).strokeBorder(.white.opacity(0.26), lineWidth: 2))
        .shadow(color: .black.opacity(0.17), radius: 6, x: 0, y: 5)
    }

    private var lcdScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Text(page.label)
                Spacer()
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    Text(timeline.date, format: .dateTime.hour().minute())
                }
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .frame(height: 19)
            .padding(.horizontal, 6)

            Group {
                switch page {
                case .companion: companionScreen
                case .steps: stepScreen
                case .presents: giftScreen
                case .cards: cardScreen
                case .friend: friendScreen
                case .options: optionsScreen
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            HStack(spacing: 0) {
                ForEach(DevicePage.allCases) { item in
                    Button {
                        page = item
                        if item == .options { showingOptions = true }
                    } label: {
                        Image(systemName: item.symbol)
                            .font(.system(size: 11, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 25)
                            .foregroundStyle(page == item ? ShellColor.bright : ShellColor.ink)
                            .background(page == item ? ShellColor.ink : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.label)
                }
            }
            .padding(2)
            .background(ShellColor.lcdShade.opacity(0.45))
        }
        .foregroundStyle(ShellColor.ink)
        .background(ShellColor.lcd)
        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(ShellColor.lcdShade, lineWidth: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var sceneSlot: String {
        switch store.currentScene {
        case "BREAKFAST": return "meal"
        case "STROLLING": return "walk"
        case "PLAYTIME", "DAYDREAMING": return "play"
        case "BATH TIME": return "bath"
        case "SLEEPY", "DREAMING": return "sleep"
        default: return "idle"
        }
    }

    private var companionScreen: some View {
        VStack(spacing: 5) {
            ZStack {
                if let sprite = sprites.animation(for: sceneSlot) {
                    AnimatedPixelSprite(animation: sprite)
                        .frame(maxWidth: .infinity, maxHeight: 147)
                        .padding(.horizontal, 8)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.artframe")
                            .font(.system(size: 34, weight: .light))
                        Text(sprites.isSyncing ? "LOADING ORIGINAL GIFS" : "CONNECT TO GIF GALLERY")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                        Text("START → SETTINGS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Text(sprites.galleryCount > 0 ? sprites.title(for: sceneSlot) : store.currentScene)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer()
                Label("\(store.watts) W", systemImage: "bolt.fill")
            }
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
        }
        .padding(.horizontal, 9)
    }

    private var stepScreen: some View {
        VStack(spacing: 10) {
            if stepsPage == 0 {
                Text("TODAY'S STEPS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                Text(store.todaySteps.formatted())
                    .font(.system(size: 37, weight: .black, design: .monospaced))
                Text("\(store.stepsToNextWatt) steps to next Watt")
                    .font(.system(size: 10, design: .monospaced))
            } else if stepsPage == 1 {
                Text("LAST 7 DAYS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(store.lastWeek) { entry in
                        VStack(spacing: 3) {
                            Rectangle().fill(ShellColor.ink)
                                .frame(width: 13, height: max(2, CGFloat(entry.steps) / 120))
                            Text(entry.label.prefix(1).uppercased())
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        }
                    }
                }
                .frame(height: 105, alignment: .bottom)
            } else {
                Text("ALL TIME")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                Text(store.lifetimeSteps.formatted())
                    .font(.system(size: 35, weight: .black, design: .monospaced))
                Text("TOTAL STEPS")
                    .font(.system(size: 11, design: .monospaced))
            }
            Text("← / →  CHANGE VIEW")
                .font(.system(size: 8, design: .monospaced))
        }
    }

    private var giftScreen: some View {
        VStack(spacing: 10) {
            Text("GIVE A PRESENT")
                .font(.system(size: 13, weight: .black, design: .monospaced))
            if let sprite = sprites.animation(for: "gift") {
                AnimatedPixelSprite(animation: sprite)
                    .frame(height: 90)
            } else {
                Image(systemName: "gift.fill").font(.system(size: 41))
            }
            Text("\(giftAmount) W")
                .font(.system(size: 29, weight: .black, design: .monospaced))
            Text("↑ / ↓  AMOUNT    A = GIVE")
                .font(.system(size: 9, design: .monospaced))
        }
    }

    private var cardScreen: some View {
        VStack(spacing: 8) {
            Text("HIGHER OR LOWER")
                .font(.system(size: 12, weight: .black, design: .monospaced))
            Text(store.currentlyPlaying ? String(store.currentCard) : "?")
                .font(.system(size: 54, weight: .black, design: .monospaced))
            Text(store.currentlyPlaying ? "POT: \(store.pendingWin) W" : "A = BET 5 W")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            Text(store.currentlyPlaying ? "↑ HIGHER   ↓ LOWER   B BANK" : "Guesses cost 5 Watts")
                .font(.system(size: 9, design: .monospaced))
        }
    }

    private var friendScreen: some View {
        VStack(spacing: 12) {
            if let sprite = sprites.animation(for: "friend") {
                AnimatedPixelSprite(animation: sprite)
                    .frame(height: 96)
            } else {
                Image(systemName: "heart.fill").font(.system(size: 40))
            }
            Text(store.levelName)
                .font(.system(size: 17, weight: .black, design: .monospaced))
            Text("FRIENDSHIP  \(store.friendship) / 100")
                .font(.system(size: 12, design: .monospaced))
            Text("A = PAT")
                .font(.system(size: 10, design: .monospaced))
        }
    }

    private var optionsScreen: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape.fill").font(.system(size: 36))
            Text("STEP SOURCE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            Text(store.sourceName)
                .font(.system(size: 14, weight: .black, design: .monospaced))
            Text("A / START  →  SETTINGS")
                .font(.system(size: 9, design: .monospaced))
        }
    }

    private var dpad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(ShellColor.bezel)
                .frame(width: 111, height: 37)
            RoundedRectangle(cornerRadius: 6)
                .fill(ShellColor.bezel)
                .frame(width: 37, height: 111)
            Circle().fill(ShellColor.caseDark)
                .frame(width: 26, height: 26)
            arrow("chevron.up", x: 0, y: -37) { tapDirection(.up) }
            arrow("chevron.down", x: 0, y: 37) { tapDirection(.down) }
            arrow("chevron.left", x: -37, y: 0) { tapDirection(.left) }
            arrow("chevron.right", x: 37, y: 0) { tapDirection(.right) }
        }
        .frame(width: 112, height: 112)
    }

    private enum Direction { case up, down, left, right }

    private func arrow(_ icon: String, x: CGFloat, y: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(ShellColor.caseBright)
                .frame(width: 35, height: 35)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: x, y: y)
    }

    private func circleButton(_ title: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(ShellColor.caseBright)
                .frame(width: size, height: size)
                .background(ShellColor.bezel, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func ovalButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Capsule().fill(ShellColor.bezel).frame(width: 33, height: 16)
                    .overlay(Capsule().strokeBorder(ShellColor.caseBright.opacity(0.2)))
                Text(title)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(ShellColor.bezel)
            }
        }
        .buttonStyle(.plain)
    }

    private func tapA() {
        switch page {
        case .companion:
            store.patPika()
            sprites.advance(sceneSlot)
        case .friend: store.patPika()
        case .steps: Task { await store.refresh() }
        case .presents: store.giveWatts(giftAmount)
        case .cards: if !store.currentlyPlaying { store.startCardGame() } else { store.bankWin() }
        case .options: showingOptions = true
        }
    }

    private func tapB() {
        if page == .cards && store.currentlyPlaying { store.bankWin() }
        else { page = .companion }
    }

    private func tapDirection(_ direction: Direction) {
        if page == .companion && (direction == .up || direction == .down) {
            sprites.advance(sceneSlot, by: direction == .up ? 1 : -1)
            return
        }
        if page == .cards && store.currentlyPlaying {
            if direction == .up { store.guess(true) }
            if direction == .down { store.guess(false) }
            return
        }
        if page == .presents && (direction == .up || direction == .down) {
            let gifts = [10, 25, 50, 100, 200, 500]
            let currentIndex = gifts.firstIndex(of: giftAmount) ?? 0
            giftAmount = gifts[min(gifts.count - 1, max(0, currentIndex + (direction == .up ? 1 : -1)))]
            return
        }
        if page == .steps && (direction == .left || direction == .right) {
            stepsPage = (stepsPage + (direction == .right ? 1 : 2)) % 3
            return
        }
        let pages = DevicePage.allCases
        page = pages[(page.rawValue + ((direction == .right || direction == .down) ? 1 : pages.count - 1)) % pages.count]
        if page == .options { showingOptions = true }
    }

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("POCKET PIKA GS")
                .font(.system(size: 25, weight: .black, design: .rounded))
                .foregroundStyle(ShellColor.bright)
            Text("\(sprites.galleryCount) original GS animations available")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ShellColor.bright.opacity(0.85))
            Text("Your digital walking companion")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(ShellColor.bright.opacity(0.65))
            HStack(spacing: 10) {
                statCard("STEPS", store.todaySteps.formatted())
                statCard("WATTS", store.watts.formatted())
            }
            HStack(spacing: 10) {
                statCard("FRIEND", "\(store.friendship)%")
                statCard("SOURCE", store.sourceName)
            }
            Text(store.message)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(ShellColor.bright)
            Button { showingOptions = true } label: {
                Label("Step source & GIF gallery", systemImage: "gearshape.fill")
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(ShellColor.caseBright, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(ShellColor.bezel)
            }
            Text("D-PAD: Navigate  ·  ↑↓ on Pika: change GIF\nA: Pat/Select  ·  B: Back  ·  START: Settings")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ShellColor.bright.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(ShellColor.bright.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
    }

    private func statCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 10, weight: .heavy, design: .monospaced))
            Text(value).font(.system(size: 21, weight: .black, design: .rounded)).minimumScaleFactor(0.55).lineLimit(1)
        }
        .foregroundStyle(ShellColor.bright)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(ShellColor.caseBright.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
    }
}

// Deterministic translucent specks on the custom yellow GS shell.
private struct GlitterSurface: View {
    var body: some View {
        Canvas { context, size in
            for i in 0..<470 {
                let x = CGFloat((i * 73 + 47) % 997) / 997 * size.width
                let y = CGFloat((i * 181 + 13) % 991) / 991 * size.height
                let r: CGFloat = i.isMultiple(of: 5) ? 1.0 : 0.5
                let rect = CGRect(x: x, y: y, width: r, height: r)
                context.fill(Path(ellipseIn: rect), with: .color((i.isMultiple(of: 3) ? Color.white : ShellColor.caseDark).opacity(0.16)))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct StepSourceSheet: View {
    @ObservedObject var store: PocketPikaStore
    let showDismiss: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("CONNECT YOUR STEPS")
                        .font(.system(size: 21, weight: .black, design: .rounded))
                    Spacer()
                    if showDismiss { Button("Close") { dismiss() } }
                }
                Text("Choose a source to earn one Watt for every 20 new steps. This screen stays open until Apple Health or Motion has responded.")
                    .font(.system(size: 13, design: .rounded))

                Button {
                    store.enableHealth()
                } label: {
                    Label("Connect Apple Health", systemImage: "heart.text.square")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isRequestingHealth)

                Button {
                    store.enableMotion()
                } label: {
                    Label("Use iPhone Motion instead", systemImage: "figure.walk")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                }
                .buttonStyle(.bordered)
                .disabled(store.isRequestingHealth)

                if store.isRequestingHealth {
                    ProgressView("Opening Health permissions…")
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("CURRENT: \(store.sourceName)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Text(store.connectionStatus)
                        .font(.system(size: 12, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("HealthKit signing access can't be verified in advance on iOS. Tap Connect Apple Health to test it; an error appears above if the sideload signature lacks permission.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Continue to handheld") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.sourceName == "Not connected" || store.isRequestingHealth)

                Text("Health read permission is private: a completed request does not prove access was granted. If the count stays at zero, check Health → Data Access & Devices → Pocket Pika GS, or use Motion.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(22)
        }
    }
}

private struct DeviceOptionsSheet: View {
    @ObservedObject var store: PocketPikaStore
    @ObservedObject var sprites: SpriteLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSlot = "idle"
    @State private var pickingFile = false
    @State private var showingSource = false

    var body: some View {
        NavigationStack {
            Form {
                Section("STEP TRACKING") {
                    LabeledContent("Current", value: store.sourceName)
                    LabeledContent("HealthKit signing", value: "Test with Connect")
                    Text(store.connectionStatus).font(.footnote)
                    Button("Change step source") { showingSource = true }
                    Button("Refresh now") { Task { await store.refresh() } }
                }
                Section("ORIGINAL GS GIF GALLERY") {
                    LabeledContent("Gallery", value: "\(sprites.galleryCount) animations")
                    if sprites.isSyncing { ProgressView("Downloading GIFs") }
                    Text(sprites.syncStatus).font(.footnote)
                    Button("Download or refresh original GIFs") {
                        Task { await sprites.syncFromSerebii() }
                    }
                    .disabled(sprites.isSyncing)
                    Text("Animations are downloaded from the Serebii Pocket Pikachu 2 guide to local storage. A network connection is needed on first setup; subsequent playback works offline.")
                        .font(.footnote)
                    Text("You can also import a GIF or PNG to override the selected scene; pixel scaling stays crisp.")
                        .font(.footnote)
                    Picker("Animation", selection: $selectedSlot) {
                        ForEach(SpriteLibrary.slots, id: \.key) { slot in
                            Text(slot.title).tag(slot.key)
                        }
                    }
                    LabeledContent("Loaded", value: sprites.name(for: selectedSlot))
                    Button("Import GIF / PNG") { pickingFile = true }
                    if let message = sprites.errorMessage {
                        Text(message).foregroundStyle(.red)
                    }
                    Text("GS artwork is from the linked Serebii gallery, as authorized for this project. The Pokémon character remains owned by its rights holders.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("CONTROLS") {
                    Text("D-Pad selects menus, A confirms, B goes back, START opens this screen, and SELECT shows friendship.")
                        .font(.footnote)
                }
            }
            .navigationTitle("GS Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.gif, .png, .jpeg]) { result in
            switch result {
            case .success(let url): sprites.importSprite(url, into: selectedSlot)
            case .failure(let error): sprites.errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showingSource) {
            StepSourceSheet(store: store, showDismiss: true)
                .presentationDetents([.medium, .large])
        }
    }
}
