# Pocket Pika GS v0.4 — Original GIF Gallery Sync

This is a **fan-made digital Pocket Pikachu 2 GS** for the iPhone Duo. It is a new SwiftUI app, not Nintendo's original executable firmware.

## Changes from v0.2 / v0.3

- The app resembles the **silver-glitter US Pokémon Pikachu 2 GS handheld** with a dark bezel, LCD, D-pad, A/B, START and SELECT controls.
- If a step source is not already connected, first launch presents an **Apple Health / iPhone Motion step source chooser**. On sideloaded iPhones, try iPhone Motion first.
- **Original GIF gallery sync:** When no animations are saved, the app attempts to download original animated GIF assets from the [Serebii Pokémon Pikachu 2 gallery](https://www.serebii.net/virtualpet/pokemonpikachu2/) to its own private Documents folder. The user has asserted permission to use this site's files for this project. On success, GIFs become available offline. The GIF files are **not included** in this source ZIP; downloads happen when the app first runs. The gallery can also be re-synced in START → Settings.
- GIF playback uses each image's real animation frames/delays and nearest-neighbor pixel scaling. Up/down on the companion screen switches between GIFs in the current category.
- The companion chooses different animation categories by time of day. Friendship and gift pages use their own GIF categories if the site provides them.
- Manual GIF/PNG/JPEG import still exists as an alternative if the site is unreachable.
- Watts, games, existing step-source choice and saved progress continue using the prior bundle identifier and save key.

## Important limitations

- The exact original GIFs were **not downloadable in this development environment**, so their live retrieval has not been verified on an iPhone. The app will show a status message if the website blocks or changes the HTML/image links. The GIF selection parser specifically looks for HTML `<img>` descriptions containing *Animated Pocket Pikachu 2*.
- This is a privately built, unofficial companion. Site ownership does not itself grant ownership of Nintendo/Pokémon characters or trademarks. Do not redistribute the source assets without the necessary rights.
- Step history begins when the source is first enabled, so old walks cannot accidentally be counted twice.
- iPhone Motion uses Apple's pedometer history; Apple Health requires signing entitlements that may be unavailable with some sideload methods.
- Infrared Mystery Gift with original hardware is not implemented.

## Build with your existing GitHub repository

Existing repository: https://github.com/noggle040/PocketPika2-GS

1. Extract `PocketPikaGS-v0.4-update.zip` on your computer.
2. Go to the repo, choose **Add file → Upload files**, and drag the extracted `PocketPika` folder and `README.md` onto the GitHub upload form. It should show the new `PocketPika/SpriteLibrary.swift`, updated `PocketPika/PocketPikaView.swift`, and README as changes. Commit directly to `main`.
3. Your **existing** `.github/workflows/build-ipa.yml` should rebuild the IPA automatically. There's no need to edit the GitHub workflow for the runtime gallery sync.
4. Open the green Actions run and download `PocketPikaGS-unsigned-IPA`. Extract and sideload the IPA.
5. On first run: select **iPhone Motion** and allow the app to download sprites. If necessary press START → Settings → **Download or refresh original GIFs**.

You can use the `scripts/collect_serebii_gifs.py` helper to download original GIFs to a folder for testing in an internet-enabled environment. The app does not depend on the script.

## Sources / attribution

- GIF gallery and original handheld documentation: https://www.serebii.net/virtualpet/pokemonpikachu2/
- Pokémon Pikachu 2 GS is a Nintendo/The Pokémon Company product; this project is not associated with them.
