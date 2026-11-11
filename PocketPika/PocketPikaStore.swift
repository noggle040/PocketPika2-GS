import Foundation
import HealthKit
import CoreMotion
import SwiftUI

struct DayEntry: Identifiable {
    let id: String
    let label: String
    let steps: Int
}

// Local friendship history shown ONLY in the unfolded Duo's right column.
// Not a save export/backup feature; this is ordinary companion progress data.
struct PikaDiaryEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let title: String
    let detail: String
    let icon: String
    let friendshipChange: Int

    init(timestamp: Date = Date(), title: String, detail: String,
         icon: String, friendshipChange: Int = 0) {
        self.id = UUID()
        self.timestamp = timestamp
        self.title = title
        self.detail = detail
        self.icon = icon
        self.friendshipChange = friendshipChange
    }
}

private struct PikaSave: Codable {
    var createdAt = Date()
    var watts = 0
    var lifetimeSteps = 0
    var friendship = 10
    // Modelled GS goodwill points. Original GS numerical cutoffs are unverified.
    var friendshipPoints: Int? = nil
    // Day through which the previous-day friendship penalties have been processed.
    var friendshipCheckedOn: Date? = nil
    // Local calendar-day check-ins. Optional for backward-compatible v0.8 saves.
    var visitedDays: [Date]? = nil
    // Optional fields ensure upgrades retain existing Health, Ice Water and friendship data.
    var diaryEntries: [PikaDiaryEntry]? = nil
    var dailyMilestoneDate: Date? = nil
    var dailyMilestoneLevels: [Int]? = nil
    var source = "none"
    var sourceBegan = Date()
    var healthRecorded = 0
    var motionCursor: Date? = nil
    var giftsGiven = 0
    var bestStreak = 0
    var lastGift: Date? = nil
    var lastPet: Date? = nil
    var currentCard = 0
    var pendingWin = 0
    var streak = 0
}

@MainActor
final class PocketPikaStore: ObservableObject {
    @Published private(set) var watts = 0
    @Published private(set) var lifetimeSteps = 0
    @Published private(set) var friendship = 10
    @Published private(set) var friendshipState = "PLAYMATES"
    @Published private(set) var friendshipPoints = 0
    @Published private(set) var checkedInToday = false
    @Published private(set) var dailyCareReport = "Marill is looking forward to today's check-in."
    @Published private(set) var diaryEntries: [PikaDiaryEntry] = []
    @Published private(set) var achievedDailyMilestones: [Int] = []
    @Published private(set) var latestDailyMilestone: Int? = nil
    @Published private(set) var todaySteps = 0
    @Published private(set) var lastWeek: [DayEntry] = []
    @Published private(set) var sourceName = "Not connected"
    @Published private(set) var message = "Let's explore together!"
    @Published private(set) var isLoading = false
    @Published private(set) var isRequestingHealth = false
    @Published private(set) var connectionStatus = "Choose Apple Health or iPhone Motion to start counting steps."
    @Published private(set) var currentCard = 0
    @Published private(set) var pendingWin = 0
    @Published private(set) var streak = 0
    @Published private(set) var bestStreak = 0
    @Published private(set) var lastCardResult = ""
    @Published private(set) var giftsGiven = 0

    private let saveKey = "pocket-marill-gs.v2"
    // Stored separately so existing v0.2–v0.5.1 saves decode unchanged.
    private let stepCreditDateKey = "pocket-marill-gs.v2.credit-date"
    private let stepCreditCountKey = "pocket-marill-gs.v2.credit-count"
    private let health = HKHealthStore()
    private let pedometer = CMPedometer()
    private var game: PikaSave
    private var processingDailyCare = false

    // CUSTOM companion goals (not the official GS firmware settings).
    let minimumDailyCareSteps = 3_000
    private let lowStepFriendshipPenalty = 550
    private let missedVisitFriendshipPenalty = 150

    // CUSTOM, one-time-per-day milestones. No bonus Ice Water: 20 steps = 1 Ice Water remains unchanged.
    let dailyMilestoneTargets: [Int] = [3_000, 5_000, 10_000, 15_000, 20_000, 25_000]
    private let lifetimeMilestoneTargets: [Int] = [5_000, 25_000, 100_000, 150_000, 300_000, 1_000_000]

    init() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let loaded = try? JSONDecoder().decode(PikaSave.self, from: data) {
            game = loaded
        } else {
            game = PikaSave()
        }
        // Preserve the previous Ice Water bank/step history and map existing friendliness.
        if game.friendshipPoints == nil {
            game.friendshipPoints = game.giftsGiven == 0
                ? 0 : min(7_000, max(-1_500, (game.friendship - 10) * 50))
        }
        let today = Calendar.current.startOfDay(for: Date())
        if game.friendshipCheckedOn == nil { game.friendshipCheckedOn = today }
        // Migration: existing v0.8 installations have no historic visit log.
        // Start checking *today* instead of penalizing unknowable past visits.
        let isDailyCareMigration = game.visitedDays == nil
        if isDailyCareMigration {
            game.visitedDays = [today]
            game.friendshipCheckedOn = today
        }
        let isDiaryMigration = game.diaryEntries == nil
        if isDiaryMigration {
            game.diaryEntries = [PikaDiaryEntry(title: "Our adventure continues",
                detail: "Marill's friendship diary is ready. Future check-ins, gifts and achievements appear here.",
                icon: "book.closed.fill")]
        }
        present()
        if isDailyCareMigration || isDiaryMigration { persist() }
    }

    static func state(for points: Int) -> String {
        // ESTIMATED thresholds derived from the separate original *monochrome*
        // fan emulator. The GS has the same five named states but its numerical
        // boundaries have not been verified from original hardware/firmware.
        if points <= -1_500 { return "STRANGER" }
        if points <= -500 { return "MEANIE" }
        if points < 1_500 { return "PLAYMATES" }
        if points < 3_000 { return "FRIENDS" }
        return "BEST PALS"
    }

    var levelName: String { friendshipState }

    var currentScene: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<6: return "DREAMING"
        case 6..<9: return "BREAKFAST"
        case 9..<12: return "STROLLING"
        case 12..<16: return "DAYDREAMING"
        case 16..<19: return "PLAYTIME"
        case 19..<21: return "BATH TIME"
        default: return "SLEEPY"
        }
    }

    var stepsToNextWatt: Int { 20 - (lifetimeSteps % 20) }
    var milestone: String {
        switch lifetimeSteps {
        case 1_000_000...: return "MILLION STEP CLUB!"
        case 300_000...: return "SKATEBOARD UNLOCKED"
        case 150_000...: return "ADVENTURE EXPERT"
        case 25_000...: return "WHEELING ALONG"
        case 5_000...: return "FIRST ADVENTURE"
        default: return "NEXT: 5,000 STEPS"
        }
    }

    var dailyGoal: Int { minimumDailyCareSteps }
    var dailyProgress: Double { min(1.0, Double(todaySteps) / Double(dailyGoal)) }
    var nextDailyMilestone: Int? { dailyMilestoneTargets.first(where: { $0 > todaySteps }) }
    var unlockedRareActivities: Bool { todaySteps >= 10_000 || lifetimeSteps >= 150_000 }
    var currentlyPlaying: Bool { currentCard > 0 }

    // Only deliberate use of the app records a visit. The background/foreground
    // step refresh timer does NOT count as checking in with Marill.
    func recordVisit() {
        let today = Calendar.current.startOfDay(for: Date())
        let calendar = Calendar.current
        var visited = game.visitedDays ?? []
        guard !visited.contains(where: { calendar.isDate($0, inSameDayAs: today) }) else { return }
        visited.append(today)
        // Keep enough history for a month of offline use, but bound the save.
        game.visitedDays = Array(visited.suffix(45))
        dailyCareReport = "Checked in today. Get 3,000 steps to protect your friendship."
        addDiary(title: "You visited Marill",
                 detail: "Today's check-in is complete. Marill is happy you stopped by.",
                 icon: "hand.wave.fill")
        persist()
    }

    func refresh() async {
        if game.source == "health" { await syncHealth() }
        else if game.source == "motion" { await syncMotion() }
    }

    // iOS does not expose a public SecTask entitlement preflight to apps.
    // Ask HealthKit directly; it will report a capability/signing error if unavailable.

    func enableHealth() {
        guard !isRequestingHealth else { return }
        guard HKHealthStore.isHealthDataAvailable(),
              let steps = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            connectionStatus = "Apple Health isn't available on this device. Choose iPhone Motion."
            message = connectionStatus
            return
        }
        isRequestingHealth = true
        connectionStatus = "Requesting step-count access from Apple Health. If no prompt appears, Health may have been previously configured, or your signing profile may lack HealthKit."
        health.requestAuthorization(toShare: [], read: [steps]) { [weak self] completed, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isRequestingHealth = false
                if let error {
                    self.connectionStatus = "Apple Health request failed: \(error.localizedDescription) [code \((error as NSError).code)]. The sideload signature may lack HealthKit; iPhone Motion can work without it."
                    self.message = self.connectionStatus
                    return
                }
                guard completed else {
                    self.connectionStatus = "HealthKit did not complete the authorization request. Try again or use iPhone Motion."
                    self.message = self.connectionStatus
                    return
                }
                self.switchSource("health")
                self.connectionStatus = "Health authorization request completed. iOS does not disclose read-permission decisions; verify the Steps access in the Health app."
                await self.syncHealth()
            }
        }
    }

    func enableMotion() {
        guard CMPedometer.isStepCountingAvailable() else {
            connectionStatus = "iPhone Motion step counting isn't available on this device."
            message = connectionStatus
            return
        }
        switchSource("motion")
        connectionStatus = "iPhone Motion selected. iOS may ask for Motion & Fitness access when the first step query runs."
        Task { await syncMotion() }
    }

    private func switchSource(_ newSource: String) {
        guard game.source != newSource else { return }
        // Start a new baseline now so changing sources never awards the same steps twice.
        game.source = newSource
        game.sourceBegan = Date()
        game.healthRecorded = 0
        game.motionCursor = game.sourceBegan
        // Switching step providers must not erase yesterday's care check.
        message = "Connected. Your next steps will earn Ice Water!"
        persist()
    }

    func giveWatts(_ amount: Int) {
        guard amount > 0 else { return }
        guard game.watts >= amount else {
            message = "Not enough Ice Water yet. Let's walk!"
            return
        }
        game.watts -= amount
        // One gift Ice Water earns approximately one goodwill point. The original
        // GS conversion curve is undocumented; larger gifts naturally add more.
        game.friendshipPoints = min(8_000, (game.friendshipPoints ?? 0) + amount)
        game.giftsGiven += amount
        game.lastGift = Date()
        message = "Marill received \(amount) Ice Water! \(Self.state(for: game.friendshipPoints ?? 0))."
        addDiary(title: "You gave Marill a gift",
                 detail: "Spent \(amount.formatted()) Ice Water. Friendship is now \(Self.state(for: game.friendshipPoints ?? 0)).",
                 icon: "gift.fill", friendshipChange: amount)
        persist()
    }

    // The original device doesn't award friendship for simply pressing A.
    func patPika() { message = "Marill notices you checking in." }

    func startCardGame() {
        guard !currentlyPlaying else { return }
        guard game.watts >= 5 else { message = "The card game needs 5 Ice Water."; return }
        game.watts -= 5
        game.currentCard = Int.random(in: 2...14)
        game.pendingWin = 0
        game.streak = 0
        lastCardResult = "Guess higher or lower. Equal cards count as a win!"
        persist()
    }

    func guess(_ higher: Bool) {
        guard game.currentCard > 0 else { return }
        let old = game.currentCard
        let newCard = Int.random(in: 2...14)
        // 2002 GS FAQ: A is high, 2 is low, a tie wins either choice.
        let correct = newCard == old || (higher ? newCard > old : newCard < old)
        if correct {
            game.streak += 1
            game.bestStreak = max(game.bestStreak, game.streak)
            // Recorded payout schedule of the original GS card game (1-14 wins).
            let prizes = [8, 12, 17, 25, 40, 55, 77, 100, 130, 170, 250, 380, 555, 777]
            game.pendingWin = prizes[min(game.streak - 1, prizes.count - 1)]
            game.currentCard = newCard
            lastCardResult = "\(old) → \(newCard). Correct! Bank \(game.pendingWin) W or risk it."
        } else {
            lastCardResult = "\(old) → \(newCard). Miss! The 5 W wager is gone."
            game.pendingWin = 0
            game.currentCard = 0
            game.streak = 0
        }
        persist()
    }

    func bankWin() {
        guard game.currentCard > 0 else { return }
        let prize = game.pendingWin
        game.watts += prize
        game.currentCard = 0
        game.pendingWin = 0
        game.streak = 0
        lastCardResult = "You banked \(prize) Ice Water. Nice!"
        persist()
    }

    // Bank the current pot when navigating away; never silently lose earned Ice Water.
    func leaveCardGame() {
        if currentlyPlaying { bankWin() }
    }

    private func present() {
        watts = game.watts
        lifetimeSteps = game.lifetimeSteps
        let score = game.friendshipPoints ?? 0
        friendshipPoints = score
        friendshipState = Self.state(for: score)
        let today = Calendar.current.startOfDay(for: Date())
        checkedInToday = (game.visitedDays ?? []).contains { Calendar.current.isDate($0, inSameDayAs: today) }
        // Preserve a numeric dashboard estimate; the original presents states,
        // not a measurable friendship percentage.
        friendship = min(100, max(0, ((score + 1_500) * 100) / 4_500))
        giftsGiven = game.giftsGiven
        currentCard = game.currentCard
        pendingWin = game.pendingWin
        streak = game.streak
        bestStreak = game.bestStreak
        diaryEntries = (game.diaryEntries ?? []).sorted { $0.timestamp > $1.timestamp }
        let day = Calendar.current.startOfDay(for: Date())
        achievedDailyMilestones = game.dailyMilestoneDate.map {
            Calendar.current.isDate($0, inSameDayAs: day) ? (game.dailyMilestoneLevels ?? []) : []
        } ?? []
        sourceName = game.source == "health" ? "Apple Health" : (game.source == "motion" ? "iPhone Motion" : "Not connected")
    }

    private func persist() {
        present()
        if let data = try? JSONEncoder().encode(game) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    // Keep the history bounded for fast launch and a small on-device footprint.
    private func addDiary(title: String, detail: String, icon: String,
                          friendshipChange: Int = 0, at date: Date = Date()) {
        var entries = game.diaryEntries ?? []
        entries.append(PikaDiaryEntry(timestamp: date, title: title, detail: detail,
                                      icon: icon, friendshipChange: friendshipChange))
        game.diaryEntries = Array(entries.suffix(120))
    }

    private func recordDailyMilestones(at now: Date) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: now)
        if let recordedDay = game.dailyMilestoneDate,
           !calendar.isDate(recordedDay, inSameDayAs: day) {
            game.dailyMilestoneDate = day
            game.dailyMilestoneLevels = []
            latestDailyMilestone = nil
        }
        if game.dailyMilestoneDate == nil { game.dailyMilestoneDate = day }
        var reached = game.dailyMilestoneLevels ?? []
        var newest: Int? = nil
        for goal in dailyMilestoneTargets where todaySteps >= goal && !reached.contains(goal) {
            reached.append(goal)
            newest = goal
            let detail: String
            if goal == 3_000 {
                detail = "You've met today's friendship-care step goal. Keep your daily check-in too!"
            } else if goal == 10_000 {
                detail = "10,000 steps in one day! Special Marill activities can now appear more often today."
            } else if goal >= 15_000 {
                detail = "A huge walking day. More special Marill activities are available today."
            } else {
                detail = "A new one-day step record milestone. Marill has more exploring to do!"
            }
            addDiary(title: "\(goal.formatted()) steps today!", detail: detail,
                     icon: goal >= 10_000 ? "star.fill" : "figure.walk", at: now)
        }
        game.dailyMilestoneLevels = reached.sorted()
        // Publish a signal only when a new milestone was just reached.
        if let newest { latestDailyMilestone = newest }
    }

    private func addNewSteps(_ newSteps: Int) {
        guard newSteps > 0 else { return }
        let previousLifetime = game.lifetimeSteps
        let oldWatts = game.lifetimeSteps / 20
        game.lifetimeSteps += newSteps
        let newWatts = game.lifetimeSteps / 20
        let delta = newWatts - oldWatts
        game.watts += delta
        if delta > 0 { message = "\(newSteps.formatted()) new steps! +\(delta) Ice Water." }
        for goal in lifetimeMilestoneTargets where previousLifetime < goal && game.lifetimeSteps >= goal {
            addDiary(title: "\(goal.formatted()) lifetime steps!",
                     detail: goal == 1_000_000
                         ? "One million steps! Marill has reached a legendary milestone."
                         : "An all-time walking achievement. Keep exploring with Marill!",
                     icon: "rosette", at: Date())
        }
        persist()
    }

    // The value earned for this calendar day, across both step sources.
    // This prevents switching Health/Motion or pressing Refresh from paying twice.
    private func creditedSteps(for day: Date) -> Int {
        let defaults = UserDefaults.standard
        if let savedDate = defaults.object(forKey: stepCreditDateKey) as? Date,
           Calendar.current.isDate(savedDate, inSameDayAs: day) {
            return max(0, defaults.integer(forKey: stepCreditCountKey))
        }
        // Migrate a v0.5.1 Health save that already awarded steps since
        // connection earlier today. If none were awarded, import all of today.
        if game.source == "health" && Calendar.current.isDate(game.sourceBegan, inSameDayAs: day) {
            return max(0, game.healthRecorded)
        }
        return 0
    }

    private func recordCreditedSteps(_ count: Int, for day: Date) {
        UserDefaults.standard.set(day, forKey: stepCreditDateKey)
        UserDefaults.standard.set(max(0, count), forKey: stepCreditCountKey)
    }

    private func syncHealth() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            connectionStatus = "Apple Health is unavailable on this device."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let now = Date()
            let day = Calendar.current.startOfDay(for: now)
            // Import today's *entire* step total instead of querying only
            // the tiny interval since the Health button was pressed.
            let currentTotal = try await healthSteps(from: day, to: now)
            let alreadyCredited = creditedSteps(for: day)
            let newSteps = max(0, currentTotal - alreadyCredited)
            todaySteps = currentTotal
            if newSteps > 0 { addNewSteps(newSteps) }
            recordCreditedSteps(max(alreadyCredited, currentTotal), for: day)
            // Older releases used this as a since-connected watermark. Keep
            // the saved property for compatibility but do not use it for deltas.
            game.healthRecorded = max(game.healthRecorded, currentTotal)
            if currentTotal > 0 {
                connectionStatus = "Apple Health shows \(currentTotal.formatted()) steps today. Imported \(newSteps.formatted()) new steps into Pocket Marril."
            } else {
                connectionStatus = "Apple Health returned no readable steps for today. If Health itself shows steps, open Settings > Health > Data Access & Devices > Pocket Marril and enable reading Steps. HealthKit cannot reveal whether read permission was denied."
            }
            recordDailyMilestones(at: now)
            await refreshWeek(isHealth: true, now: now)
            await applyFriendshipNeglect(now: now, isHealth: true)
            persist()
        } catch {
            connectionStatus = "Apple Health step query failed: \(error.localizedDescription) [code \((error as NSError).code)]. Check Steps read permission or use iPhone Motion."
            message = connectionStatus
        }
    }

    private func syncMotion() async {
        guard CMPedometer.isStepCountingAvailable() else { return }
        isLoading = true
        defer { isLoading = false }
        let now = Date()
        let day = Calendar.current.startOfDay(for: now)
        let cutoff = now.addingTimeInterval(-6 * 86_400)
        let cursor = max(game.motionCursor ?? game.sourceBegan, cutoff)
        do {
            // Motion can still catch up on steps from prior days without
            // mixing them into today's Health/Motion reconciliation.
            let earlierSteps: Int
            if cursor < day {
                earlierSteps = (try? await motionSteps(from: cursor, to: day)) ?? 0
            } else {
                earlierSteps = 0
            }
            let currentTotal = try await motionSteps(from: day, to: now)
            let alreadyCredited = creditedSteps(for: day)
            let newToday = max(0, currentTotal - alreadyCredited)
            game.motionCursor = now
            todaySteps = currentTotal
            addNewSteps(earlierSteps + newToday)
            recordCreditedSteps(max(alreadyCredited, currentTotal), for: day)
            connectionStatus = "iPhone Motion shows \(currentTotal.formatted()) steps today. Added \((earlierSteps + newToday).formatted()) uncounted steps."
            recordDailyMilestones(at: now)
            await refreshWeek(isHealth: false, now: now)
            await applyFriendshipNeglect(now: now, isHealth: false)
            persist()
        } catch {
            message = "Motion data unavailable: \(error.localizedDescription)"
            connectionStatus = message
        }
    }

    private func applyFriendshipNeglect(now: Date, isHealth: Bool) async {
        // Evaluate each *completed* calendar day only once. A visit is recorded
        // independently; recurring step refreshes cannot manufacture check-ins.
        guard !processingDailyCare else { return }
        processingDailyCare = true
        defer { processingDailyCare = false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let lastReviewedDay = game.friendshipCheckedOn else {
            game.friendshipCheckedOn = today
            persist()
            return
        }
        let last = calendar.startOfDay(for: lastReviewedDay)
        guard last < today else { return }
        let elapsed = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        guard elapsed > 0 else { return }

        // Motion history is short, so don't claim to know older daily totals.
        let reviewCount = min(elapsed, isHealth ? 30 : 6)
        let oldestReview = calendar.date(byAdding: .day, value: -reviewCount, to: today) ?? last
        let visited = game.visitedDays ?? []
        var missedVisits = 0
        var lowStepDays = 0
        var stepHistoryUsable = todaySteps > 0 || lastWeek.contains(where: { $0.steps > 0 })

        // First read the step history. If it is unavailable, we only apply the
        // separate missed-check-in rule, not an unjustified step penalty.
        for offset in 0..<reviewCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: oldestReview),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
            if !visited.contains(where: { calendar.isDate($0, inSameDayAs: day) }) {
                missedVisits += 1
            }
            if stepHistoryUsable {
                do {
                    let steps = try await (isHealth
                        ? healthSteps(from: day, to: nextDay)
                        : motionSteps(from: day, to: nextDay))
                    if steps < minimumDailyCareSteps { lowStepDays += 1 }
                } catch {
                    // One failed historical query invalidates the complete
                    // step penalty batch, but recorded check-in history remains.
                    lowStepDays = 0
                    stepHistoryUsable = false
                }
            }
        }

        let loss = lowStepDays * lowStepFriendshipPenalty
                 + missedVisits * missedVisitFriendshipPenalty
        game.friendshipCheckedOn = today
        if loss > 0 {
            game.friendshipPoints = max(-1_500, (game.friendshipPoints ?? 0) - loss)
            let stepsSummary = lowStepDays == 1 ? "1 low-step day" : "\(lowStepDays) low-step days"
            let visitsSummary = missedVisits == 1 ? "1 missed check-in" : "\(missedVisits) missed check-ins"
            message = "Marill missed you: \(stepsSummary), \(visitsSummary). Friendship -\(loss)."
            dailyCareReport = message
            addDiary(title: "Marill missed you",
                     detail: "\(stepsSummary), \(visitsSummary). Daily care decreased friendship by \(loss) points.",
                     icon: "heart.slash.fill", friendshipChange: -loss, at: now)
        } else if !stepHistoryUsable {
            dailyCareReport = "Daily check-ins reviewed. Step penalties skipped because step history isn't verifiable."
        } else {
            dailyCareReport = "All checked days met Marill's care goals!"
        }
        // Do not wipe the visit log on date rollover. Keep only the horizon
        // that the program can still reconcile next time it is launched.
        game.visitedDays = visited.filter { $0 >= (calendar.date(byAdding: .day, value: -45, to: today) ?? today) }
        persist()
    }

    private func refreshWeek(isHealth: Bool, now: Date) async {
        var week: [DayEntry] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let df = DateFormatter()
        df.dateFormat = "EE"
        for offset in (0..<7).reversed() {
            guard let start = calendar.date(byAdding: .day, value: -offset, to: today),
                  let next = calendar.date(byAdding: .day, value: 1, to: start) else { continue }
            let end = min(next, now)
            let count: Int
            if isHealth { count = (try? await healthSteps(from: start, to: end)) ?? 0 }
            else { count = (try? await motionSteps(from: start, to: end)) ?? 0 }
            week.append(DayEntry(id: ISO8601DateFormatter().string(from: start), label: df.string(from: start), steps: count))
        }
        lastWeek = week
    }

    private func healthSteps(from start: Date, to end: Date) async throws -> Int {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount), start < end else { return 0 }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error {
                    let nsError = error as NSError
                    // HealthKit sends errorNoData (11) for empty statistics
                    // intervals. An empty interval is zero steps, not a crash.
                    if nsError.domain == HKErrorDomain && nsError.code == HKError.Code.errorNoData.rawValue {
                        continuation.resume(returning: 0)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                continuation.resume(returning: max(0, Int(stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0)))
            }
            health.execute(query)
        }
    }

    private func motionSteps(from start: Date, to end: Date) async throws -> Int {
        guard start < end else { return 0 }
        return try await withCheckedThrowingContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { result, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: max(0, result?.numberOfSteps.intValue ?? 0))
            }
        }
    }
}

