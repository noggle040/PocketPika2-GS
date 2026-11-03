# Pocket Pika GS — step-powered color companion

A new fan-made, Pocket Pikachu 2 GS-inspired iPhone app, designed for foldable iPhone layouts.
Native SwiftUI, no game ROM, Nintendo sprite sheet, or copyrighted music bundled.

**Version:** 0.2 (first experimental build). It has not yet been built with Xcode or tested on a phone.

## What is implemented
- Color handheld-style shell with original hand-drawn pixel companion and time-of-day scenes (breakfast, walk, daydream, play, bath, sleep).
- Fits a folded single screen; unfolds into a two-panel layout.
- Apple Health step reading when properly signed; Core Motion iPhone pedometer fallback without special HealthKit signing rights.
- Earn one Watt for every 20 *credited* steps, with carryover; activity starts counting after selecting a source and refreshes on launch/resume.
- Seven-day step chart and daily progress ring.
- Spend 10/25/50/100 Watts to make friends. Pat once per 45 seconds.
- Higher-or-lower card mini-game (5 W wager, double-or-nothing; ties lose; bank available).
- Lifetime milestone labels and on-device persisted data.
- A CI build that assembles an unsigned IPA for a sideloading tool that handles signing.

## Not yet implemented / important differences from original hardware
- This is an original homage, **not Nintendo's original Pocket Pikachu 2 GS firmware**.
- No infrared Mystery Gift with physical Game Boy Color Gold/Silver/Crystal hardware.
- No custom alarm melody composer, device-to-device IR exchanges, original copyrighted art/sound effects, or true pedometer counting while backgrounded without a data-source sync.
- HealthKit step reads require the signing profile to allow the HealthKit entitlement. Otherwise use **iPhone Motion**. HealthKit privacy rules may return zero steps without telling the app if read permission is denied.
- iPhone Motion history is limited (usually about a week), so check the app periodically. On changing step sources the app begins at a *new baseline* so it cannot double-count previously credited steps.
- Walking starts crediting only **after** a source is connected. This avoids an enormous retroactive Watts windfall from historical Apple Health data.
- No data leaves the device and no user account is needed.

## Build an IPA on GitHub Actions

1. Create a new empty repository at `https://github.com/new?name=PocketPika2-GS` (leave the default branch `main`).
2. Extract this ZIP on your Windows PC.
3. In the new repository choose **Add file → Upload files**, and drag in **all extracted project files and directories**, including the hidden `.github` folder containing `.github/workflows/build-ipa.yml`.
4. Commit to `main`. Open your repository's **Actions** tab. The workflow should run on the commit. If it doesn't, select **Build Pocket Pika GS IPA → Run workflow**.
5. On a green success run, download `PocketPikaGS-unsigned-IPA` from **Artifacts**. Extract the resulting `PocketPikaGS-unsigned.ipa` from the artifact ZIP.
6. Sign/sideload the unsigned IPA with your existing tool. Launch and choose either **Apple Health** or **iPhone Motion** in Setup.

## Developer note
XcodeGen creates `PocketPika.xcodeproj` from `project.yml`. GitHub Actions uses a macOS `xcode-27` runner. There are no third-party Swift packages.

## License / trademark
This independent fan app is not affiliated with Nintendo, Creatures, GAME FREAK, or The Pokémon Company. Pokémon and Pocket Pikachu are trademarks of their respective owners. The code and original pixel drawing in this new project may be reused for personal projects; no third-party sprite files are included.
