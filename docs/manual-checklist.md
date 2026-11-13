# Manual checklist

Run each check in the Forever client with `/console scriptErrors 1`.
Record "pass", "fail", or "not run" with the date in the Result column.
No check was run by the agent: the game client is not available to it.

| # | Check | Result |
| --- | --- | --- |
| MC1 | Addon loads on Forever without a Lua error (`/console scriptErrors 1`) | not run |
| MC2 | `/masterangler help` lists the commands | not run |
| MC3 | The settings panel shows the "Master Angler" category | not run |
| MC10 | With a fishing pole in hand, music and ambience go silent and the bobber splash is audible | not run |
| MC11 | With the pole taken off, the sound values come back | not run |
| MC12 | Exit the game with the pole in hand, log in, take the pole off: the sound values come back | not run |
| MC13 | Kill the client process with the pole in hand, log in with no pole: the sound values come back | not run |
| MC14 | A double right-click on the world with the pole and no lure applies the strongest lure, and the next one casts | not run |
| MC45 | With the line out and the bobber splash, a double right-click anywhere on the world loots the bobber | not run |
| MC15 | A double right-click with no pole does nothing | not run |
| MC16 | A double right-click on an NPC or on UI does not cast | not run |
| MC17 | The right-click camera turn still works after a cast | not run |
| MC18 | A right-click on the bobber loots normally | not run |
| MC19 | `/dump GetWeaponEnchantInfo()` with a lure on the pole: note if the time is in ms or in s, and confirm the lure refresh at 30 seconds | not run |
| MC20 | With the pole in hand, the Interact key applies a lure or casts | not run |
| MC21 | With the line out, the Interact key loots the bobber at the splash | not run |
| MC22 | With a vendor NPC in front, the Interact key opens the vendor | not run |
| MC23 | With a mob corpse in front, the Interact key loots it | not run |
| MC24 | In combat, the Interact key acts normally | not run |
| MC25 | With the "Interact key casts" setting off, the Interact key acts normally | not run |
| MC26 | With no pole, the Interact key acts normally | not run |
| MC27 | With the pole in hand, the Interact override stays stable: no repeated `UPDATE_BINDINGS` loop (check `/etrace`) | not run |
| MC28 | `/reload` with the line out: the Interact key still loots the bobber (spell ID is the 8th return of `UnitChannelInfo`) | not run |
| MC29 | With the game menu, settings or key bindings open, the Interact key acts normally | not run |
| MC30 | Catch a fish, then `/masterangler stats` shows one more catch | not run |
| MC31 | `/dump MasterAnglerDB.chars["<Name-Realm>"].catches[#MasterAnglerDB.chars["<Name-Realm>"].catches]` shows the zone map ID and plausible x and y | not run |
| MC32 | The loot of a mob corpse adds no row | not run |
| MC33 | With full bags, a fishing catch that stays in the loot window adds no row | not run |
| MC34 | The minimap button shows, drags and keeps its place after `/reload` | not run |
| MC35 | Left-click on the minimap button opens the journal with the fish list in four columns | not run |
| MC37 | A caught fish shows with icon and name | not run |
| MC38 | A click on a fish opens its detail with totals, first and last catch, and the zones where it was caught | not run |
| MC39 | On an alt, the fish of the main character show as `???` | not run |
| MC46 | The search box filters the list, and "Go back" from a detail keeps the filtered results | not run |
| MC40 | Escape closes the journal window | not run |
| MC41 | The journal window looks like a Blizzard panel | not run |
| MC42 | `/masterangler minimap` and the settings checkbox hide and show the button together | not run |
| MC43 | Settings panel: the five toggles (double right-click, auto-lure, Interact key, sound profile, minimap button) show and keep their value after `/reload` | not run |
| MC44 | Journal, tooltip and settings texts in deDE, esES, frFR, itIT, ptBR | not run |
