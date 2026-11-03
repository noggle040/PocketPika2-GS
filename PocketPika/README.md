# Pocket Pika GS v0.8.2 — Open-Duo Diary + Walking Milestones

## Install
Upload **all four `.swift` files** straight into `PocketPika/` in the existing
`noggle040/PocketPika2-GS` GitHub repository. Replace the three files there;
add `PocketPikaSound.swift` if it is not already present. Leave the existing
`project.yml`, assets, scripts, and GitHub workflow alone. The GitHub Actions
IPA builder will run automatically. This release is source-only until that
Xcode build succeeds.

## Requested behavior
- **Friendship diary appears exclusively in the right panel when the Duo is
  unfolded.** No diary text or event feed appears anywhere on the closed LCD.
- Entries include daily check-ins, Watt gifts (with friendship-point change),
  daily-care penalties, daily walking milestones, and lifetime step milestones.
  The most recent 12 are visible; the newest 120 remain stored locally.
- One-time **per-calendar-day** milestone markers at 3,000 / 5,000 / 10,000 /
  15,000 / 20,000 / 25,000 steps; all reset the next day. Each is logged once.
- From 10,000+ steps in a day, Pikachu occasionally has special activity scenes.
  Their approximate frequency increases at 15K and 20K steps. Certain rare
  activities also become available after 150,000 lifetime steps.
- The 10K / 15K / 20K / 25K rewards may trigger a brief happy celebration.
- Original-style daily routines, random greetings, easy touch controls, retro
  button/gift/game sounds, and 60-second **foreground** step refresh remain.
- Apple Health imports and existing data use the **same UserDefaults save key**.
  No backup/export system was added. Watts are still **20 steps = 1 Watt**.
- Friendship custom goals unchanged: fewer than **3,000 steps yesterday −550**;
  no check-in yesterday **−150 more**. Daily review once per completed day;
  failed/unverifiable Health history will not impose a step penalty.
- **No alarm** or notifications.

## Accuracy
Milestone unlock probabilities, friendship-point cutoffs and neglect penalties
are custom modeled rules, NOT an exact dump of Nintendo firmware. GIFs are from the pre-existing SpriteLibrary. The app performs a single
best-effort fetch of missing milestone animations from the existing Serebii
gallery; if unavailable, matching scenes fall back to a normal slot.

## Verification
`swiftc -frontend -parse` on every Swift source (Linux); no real iOS SDK
compilation/physical-Duo runtime test has occurred yet. Inspect GitHub Actions
before installing a compiled IPA.
