# Manual checklist

Run each check in the Forever client with `/console scriptErrors 1`.
Record "pass", "fail", or "not run" with the date in the Result column.
No check was run by the agent: the game client is not available to it.

| # | Check | Result |
| --- | --- | --- |
| MC1 | Addon loads on Forever without a Lua error (`/console scriptErrors 1`) | not run |
| MC2 | `/masterangler help` lists the commands | not run |
| MC3 | The settings panel shows the "Master Angler" category | not run |
| MC4 | Save the set with pole, hat and boots (`/masterangler savegear`) and the chat shows the item count | not run |
| MC5 | Toggle fishing mode on and off out of combat: the set equips and the old gear returns | not run |
| MC6 | Toggle in combat: the chat tells you, and the swap runs when combat ends | not run |
| MC7 | Toggle on, then `/reload`, then toggle off: the old gear returns | not run |
| MC8 | Toggle on with a set item in the bank: one chat warning, the other slots equip | not run |
| MC9 | Toggle with full bags and a two-handed pole: the offhand empties or one chat warning shows | not run |
| MC10 | With fishing mode on, music and ambience go silent and the bobber splash is audible | not run |
| MC11 | With fishing mode off, the sound values come back | not run |
| MC12 | Exit the game with fishing mode on, log in, turn the mode off: the sound values come back | not run |
| MC13 | Kill the client process with fishing mode on, log in with the mode off: the sound values come back | not run |
| MC14 | A double right-click on the world with the pole and no lure applies the strongest lure, and the next one casts | not run |
| MC15 | A double right-click with no pole and fishing mode off does nothing | not run |
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
| MC26 | With fishing mode off and no pole, the Interact key acts normally | not run |
| MC27 | With the pole in hand, the Interact override stays stable: no repeated `UPDATE_BINDINGS` loop (check `/etrace`) | not run |
| MC28 | `/reload` with the line out: the Interact key still loots the bobber (spell ID is the 8th return of `UnitChannelInfo`) | not run |
| MC29 | With the game menu, settings or key bindings open, the Interact key acts normally | not run |
