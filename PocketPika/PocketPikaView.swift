import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum ShellColor {
    static let caseSilver = Color(red: 0.12, green: 0.55, blue: 0.91)
    static let caseBright = Color(red: 0.45, green: 0.80, blue: 1.00)
    static let caseDark = Color(red: 0.05, green: 0.28, blue: 0.57)
    static let bezel = Color(red: 0.095, green: 0.14, blue: 0.23)
    static let lcd = Color(red: 0.85, green: 0.96, blue: 1.00)
    static let lcdShade = Color(red: 0.51, green: 0.76, blue: 0.89)
    static let ink = Color(red: 0.06, green: 0.17, blue: 0.31)
    static let back = Color(red: 0.07, green: 0.11, blue: 0.18)
    static let bright = Color(red: 0.99, green: 0.96, blue: 0.86)
}

private enum DevicePage: Int, CaseIterable, Identifiable {
    case companion, steps, presents, cards, friend, options
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .companion: return "MARILL"
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
        case .cards: return "circle.hexagongrid.fill"
        case .friend: return "heart.fill"
        case .options: return "gearshape.fill"
        }
    }
}


// Recreates the documented Pokémon Marill 2 GS *daily activity windows*.
// This is a behavioral recreation, not firmware emulation. Original randomness,
// minute-accurate sleep timeout, and GS numeric friendship thresholds are unknown.
private struct PikaActivity {
    let keyword: String
    let fallback: String
    let title: String
}

private enum PikaDailyLife {
    static func activity(at date: Date, friendship: String, steps: Int,
                         todaySteps: Int) -> PikaActivity {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        // A fresh roll is made when the previous activity ends, not every
        // frame. Weighted choices imitate the unpredictable check-in feeling.
        func choose(_ choices: [PikaActivity]) -> PikaActivity {
            choices.randomElement() ?? PikaActivity(keyword: "Wave", fallback: "idle", title: "HELLO")
        }
        func a(_ keyword: String, _ fallback: String) -> PikaActivity {
            PikaActivity(keyword: keyword, fallback: fallback, title: keyword.uppercased())
        }
        if friendship == "STRANGER" { return a("Poké Ball", "friend") }
        if friendship == "MEANIE" && Int.random(in: 0..<10) < 7 {
            return a("Marill's Back", "friend")
        }
        // CUSTOM walking rewards. Rare activities appear during daytime;
        // their relative chances are modeled rather than GS firmware-accurate.
        // They do not override bedtime or Marill's low-friendship reactions.
        if hour >= 8 && hour < 20 && friendship != "STRANGER" && friendship != "MEANIE" {
            let odds: Int
            if todaySteps >= 20_000 { odds = 18 }
            else if todaySteps >= 15_000 { odds = 12 }
            else if todaySteps >= 10_000 || steps >= 150_000 { odds = 8 }
            else { odds = 0 }
            if odds > 0 && Int.random(in: 0..<100) < odds {
                var rareScenes = [a("Writing Name", "play"),
                                  a("Very Happy Marill", "friend"),
                                  a("Yo-yo", "play")]
                if todaySteps >= 15_000 { rareScenes.append(a("Hula Hoop", "play")) }
                if todaySteps >= 20_000 { rareScenes.append(a("Art time", "play")) }
                if hour >= 18 { rareScenes.append(a("Fireworks", "play")) }
                if steps >= 1_000_000 { rareScenes.append(a("Very Friendly", "friend")) }
                return choose(rareScenes)
            }
        }
        switch hour {
        case 0..<7, 21..<24:
            return a("Marill Sleeps", "sleep")
        case 7..<8:
            return choose([a("Mealtime", "meal"), a("Brush Teeth", "bath")])
        case 8..<12:
            return choose([a("Yo-yo", "play"), a("Rolling", "walk"), a("Poké Ball TV", "play"),
                           a("Radio", "play"), a("Hula Hoop", "play"), a("Aerobics", "walk"),
                           a("Art time", "play"), a("Writing Name", "play")])
        case 12..<13:
            return choose([a("Pokémon Food", "meal"), a("Brush Teeth", "bath")])
        case 13..<15:
            return choose([a("Heading", "walk"), a("Rolling", "walk"), a("Swing", "play"),
                           a("Skipping", "walk"), a("Fishing", "play"), a("Hiding", "play"),
                           a("Hula Hoop", "play"), a("Dig", "play"), a("Pull Ups", "play")])
        case 15..<16:
            return choose([a("Eat Apple", "meal"), a("Juice", "meal"), a("Ice Cream", "meal")])
        case 16..<18:
            return choose([a("Heading", "walk"), a("Rolling", "walk"), a("Swing", "play"),
                           a("Skipping", "walk"), a("Fishing", "play"), a("Radio", "play"),
                           a("Hula Hoop", "play"), a("Digging in Sand", "play"),
                           a("Pull Ups", "play")])
        case 18..<19:
            return choose([a("Mealtime", "meal"), a("Brush Teeth", "bath")])
        case 19..<20:
            return choose([a("Sparkler", "play"), a("Night time View", "play"),
                           a("Fireworks", "play"), a("Radio", "play")])
        default: // 8 pm–9 pm
            return a("Bath Time", "bath")
        }
    }

    static func greeting(_ roll: Int, friendship: String) -> PikaActivity {
        func a(_ word: String, _ title: String) -> PikaActivity {
            PikaActivity(keyword: word, fallback: "idle", title: title)
        }
        switch friendship {
        case "STRANGER": return a("Poké Ball", "MARILL IS HIDING")
        case "MEANIE": return a("Marill's Back", "MARILL TURNS AWAY")
        case "BEST PALS":
            return [a("Wave", "MARILL WAVES"), a("Very Happy Marill", "HAPPY TO SEE YOU"),
                    a("Very Friendly", "BEST PALS"), a("Wave", "MARILL WAVES")][roll % 4]
        case "FRIENDS":
            return [a("Wave", "MARILL WAVES"), a("Come Here, Marill", "WELCOME BACK"),
                    a("Greetings", "HELLO AGAIN"), a("Wave", "MARILL WAVES")][roll % 4]
        default:
            return [a("Greetings", "MARILL LOOKS OVER"), a("Marill Walks", "MARILL WALKS"),
                    a("Falls Over", "MARILL STUMBLES"), a("Greetings", "HELLO MARILL")][roll % 4]
        }
    }

    static func giftReaction(_ watts: Int) -> PikaActivity {
        let name: String
        switch watts {
        case 0..<100: name = "Marill Yawn"
        case 100..<200: name = "Thanks"
        case 200..<400: name = "Happy Marill"
        case 400..<500: name = "Wink"
        default: name = "Thank You"
        }
        return PikaActivity(keyword: name, fallback: "gift", title: "A PRESENT FOR MARILL")
    }
}

struct PocketPikaView: View {
    @EnvironmentObject private var store: PocketPikaStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sprites = SpriteLibrary()
    @State private var page: DevicePage = .companion
    @State private var giftAmount = 10
    @State private var stepsPage = 0
    @State private var guessHigher = true
    @State private var showingSetup = false
    @State private var showingOptions = false
    @State private var showingBreakdown = false
    @State private var showingCardGame = false
    @State private var lcdSleeping = false
    @State private var lastButtonPress = Date()
    @State private var worldClock = Date()
    @State private var greetingEnds: Date? = nil
    @State private var greetingNumber = 0
    @State private var birthdayCelebrationEnds: Date? = nil
    @AppStorage("pocket-marill-gs.scene-word") private var storedSceneWord = ""
    @AppStorage("pocket-marill-gs.scene-fallback") private var storedSceneFallback = "idle"
    @AppStorage("pocket-marill-gs.scene-expiry") private var storedSceneExpiry = 0.0
    @AppStorage("pocket-marill-gs.scene-hour") private var storedSceneHour = -1
    @AppStorage("pocket-marill-gs.birthday-month-day") private var birthdayMonthDay = ""
    @State private var giftReactionEnds: Date? = nil
    @State private var milestoneReactionEnds: Date? = nil
    @State private var milestoneCelebrated: Int = 0
    @State private var lastGiftWatts = 0
    @AppStorage("pocket-marill-gs.virtual-lcd-sleep") private var virtualLCDSleep = true

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
        .sheet(isPresented: $showingBreakdown) {
            NavigationStack {
                ScrollView {
                    expandedPanel
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
                .background(ShellColor.back.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("POCKET MARRIL DATA")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(ShellColor.bright)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showingBreakdown = false }
                            .foregroundStyle(ShellColor.caseBright)
                    }
                }
                .toolbarBackground(ShellColor.back, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(ShellColor.back)
        }
        .fullScreenCover(isPresented: $showingCardGame) {
            FullScreenCardGameView(store: store, sprites: sprites) {
                showingCardGame = false
                page = .companion
            }
            .ignoresSafeArea()
        }
        .task {
            store.recordVisit()
            if store.sourceName == "Not connected" { showingSetup = true }
            chooseActivityIfNeeded()
            beginGreeting()
            beginBirthdayCelebrationIfToday()
            await store.refresh()
            if sprites.galleryCount == 0 { await sprites.reloadBundledAnimations() }
            await sprites.syncMilestoneAnimations()
        }
        .onChange(of: store.latestDailyMilestone) { _, newest in
            guard let newest, newest >= 10_000 else { return }
            milestoneCelebrated = newest
            milestoneReactionEnds = Date().addingTimeInterval(8)
            worldClock = Date()
            PocketPikaSound.shared.play(.win)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.recordVisit()
                lastButtonPress = Date()
                lcdSleeping = false
                chooseActivityIfNeeded()
                beginGreeting()
                beginBirthdayCelebrationIfToday()
                Task { await store.refresh() }
            }
        }
        // A virtual battery-saving LCD timeout. iOS controls actual phone lock.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 2_000_000_000) }
                catch { return }
                worldClock = Date()
                chooseActivityIfNeeded()
                if virtualLCDSleep && worldClock.timeIntervalSince(lastButtonPress) >= 75 {
                    lcdSleeping = true
                }
            }
        }
        // Check for new steps once a minute while this scene is active.
        // This task is canceled by SwiftUI when the Duo app leaves the foreground.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 60_000_000_000) }
                catch { break }
                guard !Task.isCancelled else { break }
                await store.refresh()
            }
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

                Text("POCKET MARRIL")
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
                    .frame(width: 124, alignment: .leading)
                VStack(spacing: 5) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 36, weight: .black))
                        .rotationEffect(.degrees(-24))
                    Text("MARILL")
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
                ovalButton("SELECT") { if acceptButton() { showPage(.friend) } }
                ovalButton("START") { if acceptButton() { showingOptions = true } }
            }
            .frame(height: 35)

            Spacer(minLength: 0)
            Text("POCKET MARRIL  ·  v1.0")
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
        ZStack {
            if lcdSleeping {
                Rectangle().fill(ShellColor.lcdShade.opacity(0.7))
                    .overlay {
                        Text("A  TO  WAKE")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(ShellColor.ink.opacity(0.45))
                    }
                    .accessibilityLabel("LCD asleep. Press A to wake Marill")
            } else {
                activeLCDScreen
            }
        }
        .background(ShellColor.lcd)
        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(ShellColor.lcdShade, lineWidth: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var activeLCDScreen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(page.label)
                Button {
                    if acceptButton() { showingBreakdown = true }
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 10, weight: .black))
                        .frame(width: 20, height: 19)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View all data and friendship diary")
                Spacer(minLength: 2)
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    Text(timeline.date, format: .dateTime.hour().minute())
                }
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .frame(height: 19)
            .padding(.horizontal, 6)

            // The LCD's usable content stage is 144pt tall. Give every page
            // an explicit viewport so vertically hungry layouts cannot stretch
            // the green display over the navy bezel or the handheld buttons.
            ZStack {
                switch page {
                case .companion: companionScreen
                case .steps: stepScreen
                case .presents: giftScreen
                case .cards: cardScreen
                case .friend: friendScreen
                case .options: optionsScreen
                }
            }
            .frame(width: 250, height: 144)
            .clipped()

            HStack(spacing: 0) {
                ForEach([DevicePage.steps, .presents, .cards]) { item in
                    Button {
                        if acceptButton() { showPage(item) }
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
    }

    private var displayedActivity: PikaActivity {
        if birthdayCelebrationEnds.map({ $0 > worldClock }) == true {
            return PikaActivity(keyword: "Very Happy Marill", fallback: "friend", title: "HAPPY BIRTHDAY!")
        }
        if let ends = giftReactionEnds, ends > worldClock {
            return PikaDailyLife.giftReaction(lastGiftWatts)
        }
        if let ends = milestoneReactionEnds, ends > worldClock {
            return PikaActivity(keyword: "Very Happy Marill", fallback: "friend",
                                title: "\(milestoneCelebrated.formatted()) STEPS! AMAZING!")
        }
        let hour = Calendar.current.component(.hour, from: worldClock)
        if let ends = greetingEnds, ends > worldClock, hour >= 7 && hour < 21 {
            return PikaDailyLife.greeting(greetingNumber, friendship: store.friendshipState)
        }
        if !storedSceneWord.isEmpty {
            return PikaActivity(keyword: storedSceneWord, fallback: storedSceneFallback,
                                title: storedSceneWord.uppercased())
        }
        return PikaDailyLife.activity(at: worldClock, friendship: store.friendshipState,
                                       steps: store.lifetimeSteps, todaySteps: store.todaySteps)
    }

    private var isUsersBirthdayToday: Bool {
        guard birthdayMonthDay.count == 5 else { return false }
        let components = Calendar.current.dateComponents([.month, .day], from: Date())
        guard let month = components.month, let day = components.day else { return false }
        return birthdayMonthDay == String(format: "%02d-%02d", month, day)
    }

    private func beginBirthdayCelebrationIfToday() {
        worldClock = Date()
        if isUsersBirthdayToday {
            birthdayCelebrationEnds = Date().addingTimeInterval(12)
        }
    }

    private func chooseActivityIfNeeded() {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        guard storedSceneWord.isEmpty || storedSceneExpiry <= now.timeIntervalSince1970 || storedSceneHour != hour else { return }
        let chosen = PikaDailyLife.activity(at: now, friendship: store.friendshipState,
                                            steps: store.lifetimeSteps, todaySteps: store.todaySteps)
        storedSceneWord = chosen.keyword
        storedSceneFallback = chosen.fallback
        storedSceneHour = hour
        // Activities persist across app restarts. Between 100-300 seconds is a
        // fan approximation: the original GS firmware's RNG isn't published.
        storedSceneExpiry = now.addingTimeInterval(Double(Int.random(in: 100...300))).timeIntervalSince1970
    }



    // Only A wakes the original device's LCD. The other buttons are ignored
    // while the virtual screen is asleep.
    private func acceptButton() -> Bool {
        store.recordVisit()
        feedback()
        PocketPikaSound.shared.play(.tap)
        if lcdSleeping {
            return false
        }
        lastButtonPress = Date()
        return true
    }

    private func beginGreeting() {
        worldClock = Date()
        greetingNumber = Int.random(in: 0..<100)
        greetingEnds = Date().addingTimeInterval(6)
    }

    private func showGreetingAfterWake() {
        store.recordVisit()
        PocketPikaSound.shared.play(.wake)
        lcdSleeping = false
        lastButtonPress = Date()
        page = .companion
        beginGreeting()
    }

    private var companionScreen: some View {
        let activity = displayedActivity
        return VStack(spacing: 4) {
            ZStack {
                if let sprite = sprites.animation(named: activity.keyword, fallbackSlot: activity.fallback) {
                    AnimatedPixelSprite(animation: sprite)
                        .id(activity.keyword)
                        .frame(maxWidth: .infinity, maxHeight: 147)
                        .padding(.horizontal, 8)
                } else {
                    VStack(spacing: 7) {
                        Image(systemName: "photo.artframe").font(.system(size: 31, weight: .light))
                        Text(sprites.isSyncing ? "LOADING MARILL" : "START → SYNC GIFS")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    }
                }
            }
            .overlay {
                if birthdayCelebrationEnds.map({ $0 > worldClock }) == true {
                    BirthdayCelebrationOverlay()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 4) {
                Text(activity.title)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 1)
                Text("\(store.watts) Ice Cubes")
            }
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .frame(height: 15)
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
                Text("\(store.stepsToNextWatt) steps to next Ice Cube")
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
            Text("↑/↓ VIEWS   A REFRESH")
                .font(.system(size: 8, design: .monospaced))
        }
    }

    private var giftScreen: some View {
        VStack(spacing: 3) {
            Text("GIVE A PRESENT")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .lineLimit(1)
            if let sprite = sprites.animation(named: PikaDailyLife.giftReaction(max(1, giftAmount)).keyword, fallbackSlot: "gift") {
                AnimatedPixelSprite(animation: sprite)
                    .frame(width: 186, height: 72)
            } else {
                Image(systemName: "gift.fill").font(.system(size: 31))
                    .frame(height: 72)
            }
            Text("\(giftAmount) Ice Cubes")
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .lineLimit(1)
            Text("↑ MORE   ↓ LESS   A GIVE")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .lineLimit(1)
        }
        .frame(width: 242, height: 140)
    }

    private var cardScreen: some View {
        VStack(spacing: 4) {
            Text("HIGHER OR LOWER")
                .font(.system(size: 11, weight: .black, design: .monospaced))
            Text(store.currentlyPlaying ? String(store.currentCard) : "?")
                .font(.system(size: 37, weight: .black, design: .monospaced))
            Text(store.currentlyPlaying ? "POT: \(store.pendingWin) Ice Cubes" : "A = START (5 Ice Cubes)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))

            if store.currentlyPlaying {
                HStack(spacing: 8) {
                    Text("↑ HIGHER")
                        .foregroundStyle(guessHigher ? ShellColor.lcd : ShellColor.ink)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(guessHigher ? ShellColor.ink : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                    Text("↓ LOWER")
                        .foregroundStyle(!guessHigher ? ShellColor.lcd : ShellColor.ink)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(!guessHigher ? ShellColor.ink : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                }
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                Text("A GUESS   B BANK & EXIT")
                    .font(.system(size: 8, design: .monospaced))
            }
            if !store.lastCardResult.isEmpty {
                Text(store.lastCardResult)
                    .font(.system(size: 8, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 236)
            }
        }
    }

    private var friendshipSpriteName: String {
        switch store.friendshipState {
        case "STRANGER": return "Poké Ball"
        case "MEANIE": return "Grumpy Marill"
        case "PLAYMATES": return "Friendly Marill"
        case "FRIENDS": return "Very Friendly"
        default: return "Very Happy Marill"
        }
    }

    private var originalFriendshipLabel: String { store.friendshipState }

    private var friendScreen: some View {
        VStack(spacing: 3) {
            if let sprite = sprites.animation(named: friendshipSpriteName, fallbackSlot: "friend") {
                AnimatedPixelSprite(animation: sprite)
                    .frame(width: 170, height: 65)
            } else {
                Image(systemName: "heart.fill").font(.system(size: 27))
                    .frame(height: 65)
            }
            Text(originalFriendshipLabel)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .lineLimit(1)
            HStack(spacing: 8) {
                Text(store.checkedInToday ? "✓ CHECKED IN" : "CHECK IN TODAY")
                Text("•")
                Text("\(min(store.todaySteps, store.minimumDailyCareSteps).formatted()) / 3,000")
            }
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .lineLimit(1)
            Text("B BACK   ·   SELECT STATUS")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .lineLimit(1)
        }
        .frame(width: 244, height: 140)
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

    // One 3×3 hit grid: four distinct 41-point targets with no overlap.
    // This is easier to tap than four tiny, partially overlapping arrows.
    private var dpad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(ShellColor.bezel)
                .frame(width: 121, height: 42)
            RoundedRectangle(cornerRadius: 7)
                .fill(ShellColor.bezel)
                .frame(width: 42, height: 121)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: 41, height: 41)
                    dpadButton("chevron.up", .up)
                    Color.clear.frame(width: 41, height: 41)
                }
                HStack(spacing: 0) {
                    dpadButton("chevron.left", .left)
                    Circle().fill(ShellColor.caseDark)
                        .frame(width: 28, height: 28)
                        .frame(width: 41, height: 41)
                    dpadButton("chevron.right", .right)
                }
                HStack(spacing: 0) {
                    Color.clear.frame(width: 41, height: 41)
                    dpadButton("chevron.down", .down)
                    Color.clear.frame(width: 41, height: 41)
                }
            }
        }
        .frame(width: 123, height: 123)
    }

    private enum Direction { case up, down, left, right }

    private func dpadButton(_ symbol: String, _ direction: Direction) -> some View {
        Button {
            tapDirection(direction)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(ShellColor.caseBright)
                .frame(width: 41, height: 41)
                .contentShape(Rectangle())
        }
        .buttonStyle(HandheldPressStyle())
        .accessibilityLabel(direction == .up ? "Up: change choice" :
                            direction == .down ? "Down: change choice" :
                            direction == .left ? "Previous screen" : "Next screen")
    }

    private func circleButton(_ title: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(ShellColor.caseBright)
                .frame(width: size, height: size)
                .background(ShellColor.bezel, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 2))
                .frame(width: max(48, size), height: max(48, size))
                .contentShape(Rectangle())
        }
        .buttonStyle(HandheldPressStyle())
        .accessibilityLabel(title == "A" ? "A: confirm" : "B: back")
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
            .frame(width: 72, height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(HandheldPressStyle())
        .accessibilityLabel(title == "SELECT" ? "Select: Marill friendship" : "Start: settings")
    }

    private func feedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // Always bank a live card-game pot when leaving the screen.
    private func showPage(_ next: DevicePage) {
        if page == .cards && next != .cards { store.leaveCardGame() }
        page = next
        if next == .cards { showingCardGame = true }
        if next == .options { showingOptions = true }
    }

    private func tapA() {
        // A wakes the LCD without also spending Ice Cubes or navigating.
        if lcdSleeping { feedback(); showGreetingAfterWake(); return }
        guard acceptButton() else { return }
        switch page {
        case .companion:
            beginGreeting() // checking in triggers a greeting, not free friendship
        case .friend:
            showPage(.companion)
        case .steps:
            Task { await store.refresh() }
        case .presents:
            guard store.watts >= giftAmount else { return }
            store.giveWatts(giftAmount)
            PocketPikaSound.shared.play(giftAmount >= 100 ? .bigGift : .gift)
            lastGiftWatts = giftAmount
            giftReactionEnds = Date().addingTimeInterval(7)
            worldClock = Date()
            showPage(.companion)
        case .cards:
            if store.currentlyPlaying {
                store.guess(guessHigher)
                PocketPikaSound.shared.play(store.currentlyPlaying ? .win : .lose)
            } else { store.startCardGame() }
        case .options:
            showingOptions = true
        }
    }

    private func tapB() {
        guard acceptButton() else { return }
        showPage(.companion)
    }

    // Four easy destinations, with the original three icons on the LCD.
    // Up/down only changes choices; Marill's activities are now autonomous.
    private func tapDirection(_ direction: Direction) {
        guard acceptButton() else { return }
        switch direction {
        case .left, .right:
            let pages: [DevicePage] = [.companion, .steps, .presents, .cards]
            let current = pages.firstIndex(of: page) ?? 0
            let offset = direction == .right ? 1 : pages.count - 1
            showPage(pages[(current + offset) % pages.count])
        case .up, .down:
            switch page {
            case .companion, .friend:
                break // no manual GIF cycling on the living-Marill screen
            case .steps:
                stepsPage = (stepsPage + (direction == .down ? 1 : 2)) % 3
            case .presents:
                let gifts = [10, 25, 50, 100, 200, 500]
                let current = gifts.firstIndex(of: giftAmount) ?? 0
                let offset = direction == .up ? 1 : gifts.count - 1
                giftAmount = gifts[(current + offset) % gifts.count]
            case .cards:
                guessHigher = direction == .up
            case .options:
                showingOptions = true
            }
        }
    }

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("POCKET MARRIL")
                .font(.system(size: 25, weight: .black, design: .rounded))
                .foregroundStyle(ShellColor.bright)
            Text("\(sprites.galleryCount) Marill sprites available")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ShellColor.bright.opacity(0.85))
            Text("Your digital walking companion")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(ShellColor.bright.opacity(0.65))
            HStack(spacing: 10) {
                statCard("STEPS", store.todaySteps.formatted())
                statCard("ICE CUBES", store.watts.formatted())
            }
            HStack(spacing: 10) {
                statCard("FRIEND", store.friendshipState)
                statCard("SOURCE", store.sourceName)
            }
            Text(store.message)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(ShellColor.bright)
            unfoldedMilestones
            unfoldedFriendshipDiary
            Button { showingOptions = true } label: {
                Label("Step source & GIF gallery", systemImage: "gearshape.fill")
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(ShellColor.caseBright, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(ShellColor.bezel)
            }
            Text("←→ screens  ·  ↑↓ choices\nA: confirm / wake  ·  B: back  ·  START: settings  ·  SELECT: friendship")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ShellColor.bright.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(ShellColor.bright.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
    }

    // These panels are referenced ONLY from expandedPanel, so they are never
    // instantiated on the closed Duo cover screen.
    private var unfoldedMilestones: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("DAILY WALKING MILESTONES", systemImage: "figure.walk")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                Spacer(minLength: 4)
                Text(store.nextDailyMilestone.map { "NEXT \($0.formatted())" } ?? "ALL REACHED")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(ShellColor.bright.opacity(0.72))
            }
            HStack(spacing: 5) {
                ForEach(store.dailyMilestoneTargets, id: \.self) { target in
                    let reached = store.achievedDailyMilestones.contains(target)
                    VStack(spacing: 4) {
                        Image(systemName: reached ? "star.fill" : "star")
                            .font(.system(size: 12))
                        Text(target >= 1_000 ? "\(target / 1_000)K" : "\(target)")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(reached ? ShellColor.bezel : ShellColor.bright)
                    .padding(.vertical, 10)
                    .background(reached ? ShellColor.caseBright : ShellColor.caseBright.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 9))
                }
            }
            Text("10K+ unlocks occasional special Marill activities. Milestones reset daily; Ice Cubes still come only from steps.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(ShellColor.bright.opacity(0.7))
        }
        .padding(13)
        .background(ShellColor.caseBright.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var unfoldedFriendshipDiary: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label("FRIENDSHIP DIARY", systemImage: "book.closed.fill")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(ShellColor.bright)
            Text("Diary and gift history")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(ShellColor.bright.opacity(0.65))
            if store.diaryEntries.isEmpty {
                Text("Check in, go walking or give Marill a gift to start the diary.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(ShellColor.bright.opacity(0.75))
            } else {
                ForEach(Array(store.diaryEntries.prefix(12))) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: entry.icon)
                            .font(.system(size: 15))
                            .frame(width: 21)
                            .foregroundStyle(ShellColor.caseBright)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(entry.title)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                Spacer(minLength: 4)
                                if entry.friendshipChange != 0 {
                                    Text(entry.friendshipChange > 0
                                         ? "+\(entry.friendshipChange)" : "\(entry.friendshipChange)")
                                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(entry.friendshipChange > 0
                                                         ? ShellColor.caseBright : .orange)
                                }
                            }
                            Text(entry.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(ShellColor.bright.opacity(0.58))
                            Text(entry.detail)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(ShellColor.bright.opacity(0.83))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(ShellColor.bright)
                    }
                    .padding(.vertical, 8)
                    Divider().overlay(ShellColor.bright.opacity(0.16))
                }
            }
        }
        .padding(14)
        .background(ShellColor.caseBright.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
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

private struct HandheldPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.68 : 1.0)
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
                Text("Choose a source to earn one Ice Cube for every 20 new steps. This screen stays open until Apple Health or Motion has responded.")
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

                Text("Health read permission is private: a completed request does not prove access was granted. If the count stays at zero, check Health → Data Access & Devices → Pocket Marril, or use Motion.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(22)
        }
    }
}

private struct BirthdayCelebrationOverlay: View {
    @State private var floating = false
    @State private var sparkle = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("🎈").offset(y: floating ? -7 : 5)
                Spacer()
                Text("🎈").offset(y: floating ? 5 : -7)
            }
            HStack {
                Text("✨").opacity(sparkle ? 1 : 0.45)
                Spacer()
                Text("✨").opacity(sparkle ? 0.45 : 1)
            }
            Spacer()
            HStack {
                Text("🎉").offset(y: floating ? -4 : 4)
                Spacer()
                Text("🎂").scaleEffect(sparkle ? 1.08 : 0.94)
            }
        }
        .font(.system(size: 25))
        .padding(5)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { floating = true }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { sparkle = true }
        }
        .accessibilityLabel("Animated balloons, confetti, and birthday cake")
    }
}

private struct FullScreenCardGameView: View {
    @ObservedObject var store: PocketPikaStore
    @ObservedObject var sprites: SpriteLibrary
    let onClose: () -> Void

    @State private var reactionName = ""
    @State private var reactionID = UUID()
    @State private var reactionForPlayerWin = false
    @State private var higherChoice = true

    private let playerWinReactions = ["Marill Card Flop", "Grumpy Marill", "Game loss"]
    private let marillWinReactions = ["Happy Marill", "Very Happy Marill", "Game win"]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(red: 0.02, green: 0.08, blue: 0.20),
                                        Color(red: 0.03, green: 0.28, blue: 0.55),
                                        Color(red: 0.02, green: 0.08, blue: 0.20)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 18) {
                    HStack {
                        Button(action: closeGame) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                        .accessibilityLabel("Close card game")
                        Spacer()
                        Text("POCKET MARRIL")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.88))
                        Spacer()
                        Image(systemName: "suit.spade.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color(red: 0.49, green: 0.79, blue: 1))
                            .frame(width: 34)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                    VStack(spacing: 6) {
                        Text("HIGHER OR LOWER")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.9))
                        Text(store.currentlyPlaying ? "GUESS THE NEXT CARD" : "PLAY AGAINST MARILL")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.64, green: 0.83, blue: 1))
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(LinearGradient(colors: [.white, Color(red: 0.81, green: 0.92, blue: 1)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.65), lineWidth: 3))
                            .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 12)
                        VStack(spacing: 10) {
                            HStack {
                                Text(store.currentlyPlaying ? cardRank(store.currentCard) : "?")
                                    .font(.system(size: 46, weight: .black, design: .rounded))
                                Spacer()
                                Image(systemName: "suit.spade.fill")
                                    .font(.system(size: 27, weight: .black))
                            }
                            Spacer()
                            Image(systemName: "suit.spade.fill")
                                .font(.system(size: 76, weight: .black))
                            Spacer()
                            HStack {
                                Text(store.currentlyPlaying ? cardRank(store.currentCard) : "?")
                                Spacer()
                                Image(systemName: "suit.spade.fill")
                            }
                            .rotationEffect(.degrees(180))
                            .font(.system(size: 23, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(Color(red: 0.08, green: 0.24, blue: 0.44))
                        .padding(25)
                    }
                    .frame(width: min(geometry.size.width * 0.63, 270), height: min(geometry.size.height * 0.30, 285))

                    VStack(spacing: 5) {
                        Text(store.currentlyPlaying ? "POT  ·  \(store.pendingWin) ICE CUBES" : "5 ICE CUBES TO PLAY")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        if store.currentlyPlaying {
                            Text("STREAK  \(store.streak)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.64, green: 0.83, blue: 1))
                        }
                        if !store.lastCardResult.isEmpty {
                            Text(store.lastCardResult)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(maxWidth: 340)
                        }
                    }

                    if store.currentlyPlaying {
                        HStack(spacing: 14) {
                            choiceButton("LOWER", symbol: "arrow.down", color: Color(red: 0.22, green: 0.60, blue: 0.92)) {
                                store.guess(false)
                                PocketPikaSound.shared.play(store.currentlyPlaying ? .win : .lose)
                            }
                            choiceButton("HIGHER", symbol: "arrow.up", color: Color(red: 0.10, green: 0.43, blue: 0.78)) {
                                store.guess(true)
                                PocketPikaSound.shared.play(store.currentlyPlaying ? .win : .lose)
                            }
                        }
                        Button(action: { store.bankWin(); PocketPikaSound.shared.play(.gift) }) {
                            Label("BANK \(store.pendingWin) ICE CUBES", systemImage: "tray.and.arrow.down.fill")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.24)))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 30)
                    } else {
                        Button {
                            store.startCardGame()
                            PocketPikaSound.shared.play(.tap)
                        } label: {
                            Label("START GAME  ·  5 ICE CUBES", systemImage: "play.fill")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 19)
                                .background(Color(red: 0.20, green: 0.67, blue: 1), in: RoundedRectangle(cornerRadius: 18))
                                .foregroundStyle(Color(red: 0.02, green: 0.12, blue: 0.26))
                        }
                        .padding(.horizontal, 30)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 24)

                if !reactionName.isEmpty {
                    CardGameReactionOverlay(
                        sprites: sprites,
                        animationName: reactionName,
                        playerWon: reactionForPlayerWin,
                        onTap: dismissReaction
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .overlay(alignment: .bottom) {
                if let marill = sprites.animation(named: "Greetings", fallbackSlot: "idle"), reactionName.isEmpty {
                    AnimatedPixelSprite(animation: marill)
                        .frame(width: 106, height: 96)
                        .frame(maxWidth: .infinity)
                        .offset(y: 15)
                        .allowsHitTesting(false)
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onChange(of: store.lastCardResult) { _, result in
            if result.contains("Correct!") {
                showReaction(playerWon: true)
            } else if result.contains("Miss!") {
                showReaction(playerWon: false)
            }
        }
        .task(id: reactionID) {
            guard !reactionName.isEmpty else { return }
            do { try await Task.sleep(for: .seconds(3.2)) } catch { return }
            guard !Task.isCancelled else { return }
            dismissReaction()
        }
    }

    private func cardRank(_ value: Int) -> String {
        switch value {
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        case 14: return "A"
        default: return String(value)
        }
    }

    private func choiceButton(_ title: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 19)
                .background(color, in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 7)
        }
    }

    private func showReaction(playerWon: Bool) {
        let choices = playerWon ? playerWinReactions : marillWinReactions
        reactionName = choices.randomElement() ?? (playerWon ? "Grumpy Marill" : "Happy Marill")
        reactionForPlayerWin = playerWon
        reactionID = UUID()
    }

    private func dismissReaction() {
        withAnimation(.easeOut(duration: 0.25)) { reactionName = "" }
    }

    private func closeGame() {
        store.leaveCardGame()
        onClose()
    }
}

private struct CardGameReactionOverlay: View {
    @ObservedObject var sprites: SpriteLibrary
    let animationName: String
    let playerWon: Bool
    let onTap: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(red: 0.01, green: 0.05, blue: 0.15),
                                        Color(red: 0.03, green: 0.30, blue: 0.62),
                                        Color(red: 0.01, green: 0.05, blue: 0.15)],
                               startPoint: .top, endPoint: .bottom)
                VStack(spacing: 22) {
                    Text(playerWon ? "YOU WIN THIS ROUND" : "MARILL WINS THIS ROUND")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                    if let animation = sprites.animation(named: animationName, fallbackSlot: "play") {
                        AnimatedPixelSprite(animation: animation)
                            .frame(width: min(geometry.size.width * 0.9, 390), height: min(geometry.size.height * 0.52, 370))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    } else {
                        ProgressView().tint(.white).scaleEffect(1.8)
                    }
                    Text(animationName.uppercased())
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(Color(red: 0.75, green: 0.88, blue: 1))
                    Text("TAP TO CONTINUE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .accessibilityLabel(playerWon ? "Marill reacts to your win" : "Marill celebrates winning")
    }
}

private struct DeviceOptionsSheet: View {
    @ObservedObject var store: PocketPikaStore
    @ObservedObject var sprites: SpriteLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSlot = "idle"
    @State private var pickingFile = false
    @State private var showingSource = false
    @AppStorage("pocket-marill-gs.virtual-lcd-sleep") private var virtualLCDSleep = true
    @AppStorage("pocket-marill-gs.sound-enabled") private var soundEnabled = true
    @AppStorage("pocket-marill-gs.birthday-month-day") private var birthdayMonthDay = ""

    private var birthdaySelection: Binding<Date> {
        Binding(
            get: {
                let pieces = birthdayMonthDay.split(separator: "-").compactMap { Int($0) }
                var parts = DateComponents()
                parts.year = Calendar.current.component(.year, from: Date())
                parts.month = pieces.count == 2 ? pieces[0] : Calendar.current.component(.month, from: Date())
                parts.day = pieces.count == 2 ? pieces[1] : Calendar.current.component(.day, from: Date())
                return Calendar.current.date(from: parts) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.month, .day], from: date)
                if let month = parts.month, let day = parts.day {
                    birthdayMonthDay = String(format: "%02d-%02d", month, day)
                }
            }
        )
    }

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
                Section("YOUR BIRTHDAY") {
                    DatePicker("Birthday", selection: birthdaySelection, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    Text("On this month and day, Marill celebrates your birthday when you open the app. The year is not saved.")
                        .font(.footnote)
                }
                Section("MARILL SPRITE GALLERY") {
                    LabeledContent("Gallery", value: "\(sprites.galleryCount) animations")
                    if sprites.isSyncing { ProgressView("Downloading GIFs") }
                    Text(sprites.syncStatus).font(.footnote)
                    Button("Reload animations") {
                        Task { await sprites.reloadBundledAnimations() }
                    }
                    .disabled(sprites.isSyncing)
                    Text("Your approved blue Marill animations are included and work offline.")
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
                    Text("48 approved two-pose animations cover greetings, daily routines, friendship, gifts and special activities.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("ORIGINAL DEVICE BEHAVIOR") {
                    Toggle("Device-style sound effects", isOn: $soundEnabled)
                    Toggle("Virtual LCD sleep (75 seconds)", isOn: $virtualLCDSleep)
                    Text("Marill greets you on opening, then performs activities at their documented original times. The virtual LCD can go dark until you press A, but iOS controls the actual phone display and background execution.")
                        .font(.footnote)
                    Text("Five GS friendship states use estimated numeric cutoffs. CUSTOM CARE: under 3,000 steps in a day costs 550 goodwill, and missing that day's app check-in costs 150 more. Only completed days are reviewed. Walking milestones at 3K/5K/10K/15K/20K/25K are custom, with occasional rare activities after 10K; the original GS firmware randomizer is undocumented. Sound effects are synthesized. No alarm, backup export, or IR transfer is included.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("CONTROLS") {
                    Text("LEFT / RIGHT: Screens. UP / DOWN: Options. A: Confirm or wake screen. B: Back. SELECT: Friendship. START: Settings. Marill follows the original time-of-day routine automatically.")
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




