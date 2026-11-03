# Pocket Pika GS v0.8.3 — LCD layout and sprite backdrop fix

## What changes
- Fixes Friend and Gift LCD content from overflowing the green display into the blue bezel and yellow controls. Screens now have a fixed 250 × 144 point content viewport and smaller, compact Friend/Gift layouts.
- White canvas backgrounds around the original Serebii GIFs are removed (edge-connected near-white pixels only) so Pikachu displays directly against the green LCD while retaining the colored sprite and animated frames.
- No change to the Apple Health step import, 3,000-step care requirement, friendship diary, sound, GIF gallery downloads, or milestone rules.
- Changes the visible version marker to YELLOW v0.8.3.

## How to upload
Open the GitHub `PocketPika/` folder and replace **only** `PocketPikaView.swift` and `SpriteLibrary.swift`. Do not replace or delete the existing Store or Sound files.

## Testing
Swift syntax parsed successfully. Full iOS compile / display behavior must be checked through the GitHub Actions Xcode workflow and on your Duo.
