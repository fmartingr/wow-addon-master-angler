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
