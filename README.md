# Pocket Marril

Blue-themed Marill companion based on the working PocketPika2-GS v0.8.3 app.

Includes 48 approved two-pose looping GIF animations, bundled for offline use.
Scene captions have been removed from the in-app images; the existing app supplies
its activity labels. No shiny or green Marill sprites or remote sprite downloads.

Ice Water replaces Watts throughout the visible interface, gifts, game and diary.
Economy is unchanged: 20 steps = 1 Ice Water, with the same gift costs, rewards,
friendship, daily care, step tracking, milestones and unfolded Duo layout.
The save's internal watts property remains unchanged for data compatibility.
App display name: Pocket Marril. Separate bundle ID: com.noggle040.pocketmarillgs.

## Build

Use a separate pocket-marill branch of noggle040/PocketPika2-GS, or a separate
repository with these files at its root. The included workflow builds an unsigned
PocketMarril-unsigned.ipa on the original xcode-27 runner configuration.
All character assets are now included; no asset download is needed.

## Status

Source and asset validation completed. Not compiled or tested on an iPhone.
GitHub rejected branch creation with HTTP 403 (integration lacks write access),
so no workflow has been started. The approved animations remain two-pose loops,
not frame-for-frame reproductions of the original Pikachu GIFs.
