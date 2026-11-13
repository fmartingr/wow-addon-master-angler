# Changelog

## 0.2.0

- A fishing pole in the main hand is the only fishing state. The double right-click, the Interact key and the sound profile work when a pole is equipped.
- Removed fishing mode, the fishing set, `/masterangler mode`, `/masterangler savegear` and the minimap right-click.
- Auto-lure finds the lures in the bags again. It uses `C_Item.GetItemCount`, because the Forever client has no global `GetItemCount`.

## 0.1.0

- Fishing set and fishing mode: `/masterangler savegear` and `/masterangler mode`, with a swap after combat.
- Sound profile in fishing mode, restored after a crash.
- Double right-click to apply the best lure, cast Fishing and reel in the bobber.
- Auto-lure when the pole has none or less than 30 seconds left.
- Interact key takeover with give-back rules.
- Catch log and `/masterangler stats`.
- Fish journal with a searchable four-column list and a detail view of where you caught each fish.
- Minimap button, settings panel and addon icon.
- Seven locales.
