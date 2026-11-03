import Foundation
import HealthKit
import CoreMotion
import SwiftUI

struct DayEntry: Identifiable {
    let id: String
    let label: String
    let steps: Int
}

private struct PikaSave: Codable {
    var createdAt = Date()
    var watts = 0
    var lifetimeSteps = 0
    var friendship = 10
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

    private let saveKey = "pocket-pika-gs.v2"
    private let health = HKHealthStore()
    private let pedometer = CMPedometer()
    private var game: PikaSave

    init() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let loaded = try? JSONDecoder().decode(PikaSave.self, from: data) {
            game = loaded
        } else {
            game = PikaSave()
        }
        present()
    }

    var levelName: String {
        switch friendship {
        case 80...: return "BEST PALS"
        case 55..<80: return "FRIENDS"
        case 30..<55: return "PLAYMATES"
        case 10..<30: return "CURIOUS"
        default: return "SHY"
        }
    }

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

    var dailyGoal: Int { 7_500 }
    var dailyProgress: Double { min(1.0, Double(todaySteps) / Double(dailyGoal)) }
    var currentlyPlaying: Bool { currentCard > 0 }

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
        message = "Connected. Your next steps will earn Watts!"
        persist()
    }

    func giveWatts(_ amount: Int) {
        guard amount > 0 else { return }
        guard game.watts >= amount else { message = "Not enough Watts yet. Let's walk!"; return }
        game.watts -= amount
        let bonus = max(1, amount / 10) + (amount >= 100 ? 4 : 0)
        game.friendship = min(100, game.friendship + bonus)
        game.giftsGiven += amount
        game.lastGift = Date()
        message = amount >= 100 ? "A huge surprise! You're best friends in the making!" : "A gift! Pika does a happy dance!"
        persist()
    }

    func patPika() {
        if let last = game.lastPet, Date().timeIntervalSince(last) < 45 {
            message = "Your little friend is still smiling!"
            return
        }
        game.lastPet = Date()
        game.friendship = min(100, game.friendship + 1)
        message = "A gentle pat makes your friend happy."
        persist()
    }

    func startCardGame() {
        guard !currentlyPlaying else { return }
        guard game.watts >= 5 else { message = "The card game needs 5 Watts."; return }
        game.watts -= 5
        game.currentCard = Int.random(in: 2...12)
        game.pendingWin = 5
        game.streak = 0
        lastCardResult = "Guess if the next card is higher or lower. Ties lose!"
        persist()
    }

    func guess(_ higher: Bool) {
        guard game.currentCard > 0 else { return }
        let old = game.currentCard
        let newCard = Int.random(in: 2...12)
        let correct = higher ? newCard > old : newCard < old
        if correct {
            game.streak += 1
            game.bestStreak = max(game.bestStreak, game.streak)
            game.pendingWin = min(game.pendingWin * 2, 1_280)
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
        lastCardResult = "You banked \(prize) Watts. Nice!"
        persist()
    }

    // Bank the current pot when navigating away; never silently lose earned Watts.
    func leaveCardGame() {
        if currentlyPlaying { bankWin() }
    }

    private func present() {
        watts = game.watts
        lifetimeSteps = game.lifetimeSteps
        friendship = game.friendship
        giftsGiven = game.giftsGiven
        currentCard = game.currentCard
        pendingWin = game.pendingWin
        streak = game.streak
        bestStreak = game.bestStreak
        sourceName = game.source == "health" ? "Apple Health" : (game.source == "motion" ? "iPhone Motion" : "Not connected")
    }

    private func persist() {
        present()
        if let data = try? JSONEncoder().encode(game) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func addNewSteps(_ newSteps: Int) {
        guard newSteps > 0 else { return }
        let oldWatts = game.lifetimeSteps / 20
        game.lifetimeSteps += newSteps
        let newWatts = game.lifetimeSteps / 20
        let delta = newWatts - oldWatts
        game.watts += delta
        if delta > 0 { message = "\(newSteps.formatted()) new steps! +\(delta) Watts." }
        persist()
    }

    private func syncHealth() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let now = Date()
            let day = Calendar.current.startOfDay(for: now)
            let base = game.sourceBegan
            async let sinceEnabled = healthSteps(from: base, to: now)
            async let today = healthSteps(from: day, to: now)
            let (cumulative, todayCount) = try await (sinceEnabled, today)
            let delta = max(0, cumulative - game.healthRecorded)
            game.healthRecorded = max(game.healthRecorded, cumulative)
            addNewSteps(delta)
            todaySteps = todayCount
            await refreshWeek(isHealth: true, now: now)
            persist()
        } catch {
            message = "Health steps unavailable: \(error.localizedDescription). Try Motion."
            connectionStatus = message
        }
    }

    private func syncMotion() async {
        guard CMPedometer.isStepCountingAvailable() else { return }
        isLoading = true
        defer { isLoading = false }
        let now = Date()
        let day = Calendar.current.startOfDay(for: now)
        // iOS exposes only a limited motion history. Never double-count the old interval.
        let cutoff = now.addingTimeInterval(-6 * 86_400)
        let cursor = max(game.motionCursor ?? game.sourceBegan, cutoff)
        do {
            async let sinceLast = motionSteps(from: cursor, to: now)
            async let today = motionSteps(from: day, to: now)
            let (newSteps, todayCount) = try await (sinceLast, today)
            game.motionCursor = now
            addNewSteps(newSteps)
            todaySteps = todayCount
            await refreshWeek(isHealth: false, now: now)
            persist()
        } catch {
            message = "Motion data unavailable: \(error.localizedDescription)"
            connectionStatus = message
        }
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
                if let error { continuation.resume(throwing: error); return }
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
