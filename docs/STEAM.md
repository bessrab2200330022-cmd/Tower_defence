# Steam release notes

Working notes, not a substitute for Valve's documentation. Verify current fees, policies and timelines at [partner.steamgames.com](https://partner.steamgames.com/doc/home) before acting on anything here — they change.

## Sequence

1. **Register as a Steam partner.** Steam Direct charges a recoupable fee per app (US$100 at the time of writing, returned once the app earns US$1,000). Expect identity and tax verification — do this early, it is the step with the longest human-in-the-loop delay.
2. **Create the app and get the store page live.** The page needs a review pass from Valve before it goes public, and there is a minimum window between the page going live and the earliest release date. Wishlists accumulated before launch are the single biggest driver of launch-day visibility, so this should happen *months* before you are ready to ship.
3. **Upload builds early and often.** Get the pipeline working long before it matters. A broken upload discovered on launch week is entirely avoidable.
4. **Set up the store assets.** Capsule images at several sizes, trailer, screenshots, short and long descriptions. Budget real time for this; it is not a Friday afternoon job, and the capsule art is doing most of the work on the store page.
5. **Build review.** Valve reviews the build itself before release, separately from the store page.

## Technical integration

**GodotSteam** wraps the Steamworks SDK for Godot. It requires a Godot build with the extension, or the GDExtension variant.

Keep it behind a wrapper in `game/`, for example `game/platform/steam_service.gd`, exposing something narrow:

```gdscript
func unlock_achievement(id: String) -> void
func is_available() -> bool
func save_to_cloud(path: String) -> bool
```

Two reasons. First, `sim/` and the tests must never see a native dependency — the whole test suite runs on a stock headless binary and should stay that way. Second, if you later ship on itch.io, GOG or Epic, only the wrapper changes.

Everything the wrapper needs should be driven off the existing event queue: `ENEMY_KILLED`, `GAME_WON`, `WAVE_CLEARED` are already emitted with the data an achievement would want.

## Achievements

Design them so they are checkable from the event stream rather than from special-cased code paths:

- Clear a map without losing a life.
- Win using only one damage type.
- Kill N enemies with splash damage.
- Clear the last wave with fewer than three towers.

Each of these is a counter over drained events, which means it is also testable headlessly.

## Cloud saves

The save format is a seed plus a command log (see backlog item 7), which is a few kilobytes at most and trivially cloud-syncable. Steam Cloud is configured per app with path patterns — keep saves in `user://saves/`.

## Build and upload

Export templates must match the engine version exactly. `export_presets.cfg` already defines Windows and Linux presets, but **CI does not build them yet** — the workflow runs tests, the smoke boot and autoplay only. Backlog item 15 is the job of adding a tag-triggered export, and uploading means `steamcmd` on top of that, with credentials in repository secrets.

Be careful with Steam Guard on a CI machine — Valve's guidance on automated build accounts is the thing to follow here, rather than working around 2FA.

## Pricing and launch

- Regional pricing matters more than the headline number for total revenue.
- A launch discount and a Next Fest demo are the two conventional visibility levers.
- Reviews compound; the first fifty matter disproportionately.

## What to verify before trusting any of this

Fees, revenue split, review timelines, the minimum store-page-live window, and Steam Direct's terms all change. This file was written from general knowledge, not from a live reading of Valve's docs. Check the source.
