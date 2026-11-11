local wow = require("spec.helpers.wow")

describe("Catches", function()
	local ns
	before_each(function()
		ns = wow.boot()
		_G.MasterAnglerDB = nil
		ns.InitDB()
		wow.maps.best = 20
		wow.maps.info[20] = { mapType = 3, parentMapID = 10 }
		wow.maps.position = {
			GetXY = function()
				return 0.4567, 0.1234
			end,
		}
		wow.serverTime = 1700000123
		wow.gameHour, wow.gameMinute = 14, 30
	end)
	after_each(function()
		wow.restore()
	end)

	local function fire(event, ...)
		ns.events.scripts.OnEvent(ns.events, event, ...)
	end

	local function catches()
		return ns.Char().catches
	end

	local function openFishing(slots)
		wow.loot.fishing = true
		wow.loot.slots = slots
		fire("LOOT_OPENED")
	end

	describe("ZoneMap", function()
		it("returns the map itself when it is a zone", function()
			assert.equals(20, ns.Catches.ZoneMap(20))
		end)

		it("walks up to the Zone type", function()
			wow.maps.info[30] = { mapType = 5, parentMapID = 20 }
			assert.equals(20, ns.Catches.ZoneMap(30))
		end)

		it("stops at the limit and returns the start map", function()
			wow.maps.info[1] = { mapType = 5, parentMapID = 2 }
			wow.maps.info[2] = { mapType = 5, parentMapID = 1 }
			assert.equals(1, ns.Catches.ZoneMap(1))
		end)

		it("returns the start map without map info or a parent", function()
			assert.equals(99, ns.Catches.ZoneMap(99))
			wow.maps.info[40] = { mapType = 5, parentMapID = 0 }
			assert.equals(40, ns.Catches.ZoneMap(40))
			wow.maps.info[41] = { mapType = 5 }
			assert.equals(41, ns.Catches.ZoneMap(41))
		end)

		it("handles nil", function()
			assert.is_nil(ns.Catches.ZoneMap(nil))
		end)

		it("works when the Zone enum is missing", function()
			_G.Enum = {}
			assert.equals(20, ns.Catches.ZoneMap(20))
		end)
	end)

	describe("Where", function()
		it("returns the zone and the position rounded to 0.1%", function()
			local zone, x, y = ns.Catches.Where()
			assert.equals(20, zone)
			assert.equals(457, x)
			assert.equals(123, y)
		end)

		it("returns -1 for a nil position", function()
			wow.maps.position = nil
			local zone, x, y = ns.Catches.Where()
			assert.same({ 20, -1, -1 }, { zone, x, y })
		end)

		it("returns -1 for a secret position", function()
			wow.maps.position = wow.markSecret({})
			local _, x, y = ns.Catches.Where()
			assert.same({ -1, -1 }, { x, y })
		end)

		it("returns -1 for secret coordinates and a failing GetXY", function()
			local secret = wow.markSecret(0.5)
			wow.maps.position = {
				GetXY = function()
					return secret, 0.5
				end,
			}
			local _, x = ns.Catches.Where()
			assert.equals(-1, x)
			wow.maps.position = {
				GetXY = function()
					error("boom")
				end,
			}
			_, x = ns.Catches.Where()
			assert.equals(-1, x)
		end)

		it("returns -1 for a position outside the zone map", function()
			wow.maps.position = {
				GetXY = function()
					return 1.2, -0.01
				end,
			}
			local _, x, y = ns.Catches.Where()
			assert.same({ -1, -1 }, { x, y })
		end)

		it("returns -1 for a NaN position", function()
			wow.maps.position = {
				GetXY = function()
					return 0 / 0, 0.5
				end,
			}
			local _, x, y = ns.Catches.Where()
			assert.same({ -1, -1 }, { x, y })
		end)

		it("returns nil with no map", function()
			wow.maps.best = nil
			assert.is_nil(ns.Catches.Where())
		end)
	end)

	describe("recording", function()
		local fish = function(id)
			return { link = wow.itemLink(id), quantity = 1 }
		end

		it("a fishing loot with two items and coins adds two rows after two slot-cleared events", function()
			openFishing({
				fish(6291),
				{ link = nil, isCoin = true, quantity = 50 },
				{ link = wow.itemLink(6292), quantity = 3 },
			})
			assert.equals(0, #catches())
			fire("LOOT_SLOT_CLEARED", 1)
			fire("LOOT_SLOT_CLEARED", 2)
			fire("LOOT_SLOT_CLEARED", 3)
			assert.equals(2, #catches())
			assert.same({ 6291, 20, 457, 123, 1700000123, 870, 1 }, catches()[1])
			assert.same({ 6292, 20, 457, 123, 1700000123, 870, 3 }, catches()[2])
		end)

		it("skips an entry flagged as coin even with a link", function()
			openFishing({ { link = wow.itemLink(5), quantity = 1, isCoin = true } })
			fire("LOOT_SLOT_CLEARED", 1)
			assert.equals(0, #catches())
		end)

		it("uses the row index constants", function()
			openFishing({ fish(6291) })
			fire("LOOT_SLOT_CLEARED", 1)
			local row = catches()[1]
			assert.equals(6291, row[ns.Catches.ITEM])
			assert.equals(20, row[ns.Catches.MAP])
			assert.equals(457, row[ns.Catches.X])
			assert.equals(123, row[ns.Catches.Y])
			assert.equals(1700000123, row[ns.Catches.TIME])
			assert.equals(870, row[ns.Catches.GAME_MINUTE])
			assert.equals(1, row[ns.Catches.QTY])
		end)

		it("a non-fishing loot adds none", function()
			wow.loot.fishing = false
			wow.loot.slots = { fish(1) }
			fire("LOOT_OPENED")
			fire("LOOT_SLOT_CLEARED", 1)
			assert.equals(0, #catches())
		end)

		it("a slot that is not cleared adds none", function()
			openFishing({ fish(6291) })
			fire("LOOT_CLOSED")
			fire("LOOT_SLOT_CLEARED", 1)
			assert.equals(0, #catches())
		end)

		it("a second LOOT_OPENED does not double the rows", function()
			openFishing({ fish(6291) })
			fire("LOOT_OPENED")
			fire("LOOT_SLOT_CLEARED", 1)
			fire("LOOT_SLOT_CLEARED", 1)
			assert.equals(1, #catches())
		end)

		it("a LOOT_OPENED after a slot is cleared does not record it again", function()
			openFishing({ fish(6291), fish(6292) })
			fire("LOOT_SLOT_CLEARED", 1)
			wow.loot.slots[1] = {}
			fire("LOOT_OPENED")
			fire("LOOT_SLOT_CLEARED", 1)
			fire("LOOT_SLOT_CLEARED", 2)
			assert.equals(2, #catches())
			assert.equals(6292, catches()[2][ns.Catches.ITEM])
		end)

		it("a slot cleared twice adds one row", function()
			openFishing({ fish(6291) })
			fire("LOOT_SLOT_CLEARED", 1)
			fire("LOOT_SLOT_CLEARED", 1)
			assert.equals(1, #catches())
		end)

		it("read-only mode adds none", function()
			openFishing({ fish(6291) })
			local char = ns.Char()
			ns.readOnly = true
			fire("LOOT_SLOT_CLEARED", 1)
			assert.equals(0, #char.catches)
		end)

		it("stores -1 and map 0 with no map", function()
			wow.maps.best = nil
			openFishing({ fish(6291) })
			fire("LOOT_SLOT_CLEARED", 1)
			assert.same({ 6291, 0, -1, -1, 1700000123, 870, 1 }, catches()[1])
		end)

		it("falls back to quantity 1 for a missing or bad quantity", function()
			openFishing({ { link = wow.itemLink(5) }, { link = wow.itemLink(6), quantity = 0 } })
			fire("LOOT_SLOT_CLEARED", 1)
			fire("LOOT_SLOT_CLEARED", 2)
			assert.equals(1, catches()[1][ns.Catches.QTY])
			assert.equals(1, catches()[2][ns.Catches.QTY])
		end)

		it("uses 0 for an unknown game time and server time", function()
			_G.GetGameTime = function()
				return nil
			end
			_G.GetServerTime = function()
				return nil
			end
			openFishing({ fish(6291) })
			fire("LOOT_SLOT_CLEARED", 1)
			assert.equals(0, catches()[1][ns.Catches.GAME_MINUTE])
			assert.equals(0, catches()[1][ns.Catches.TIME])
		end)

		it("skips a slot with a link that has no item ID", function()
			openFishing({ { link = "|Hcurrency:1|h[x]|h", quantity = 1 } })
			fire("LOOT_SLOT_CLEARED", 1)
			assert.equals(0, #catches())
		end)

		it("does nothing without a character", function()
			openFishing({ fish(6291) })
			wow.player.name = nil
			fire("LOOT_SLOT_CLEARED", 1)
			wow.player.name = "Tester"
			assert.equals(0, #catches())
		end)

		it("notifies subscribers after each append and survives a failing one", function()
			local calls = 0
			ns.Catches.Subscribe(function()
				error("boom")
			end)
			ns.Catches.Subscribe(function()
				calls = calls + 1
			end)
			openFishing({ fish(1), fish(2) })
			fire("LOOT_SLOT_CLEARED", 1)
			fire("LOOT_SLOT_CLEARED", 2)
			assert.equals(2, calls)
			assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
		end)
	end)

	describe("stats", function()
		it("prints the row count and the number of different items", function()
			openFishing({
				{ link = wow.itemLink(1), quantity = 1 },
				{ link = wow.itemLink(1), quantity = 1 },
				{ link = wow.itemLink(2), quantity = 1 },
			})
			fire("LOOT_SLOT_CLEARED", 1)
			fire("LOOT_SLOT_CLEARED", 2)
			fire("LOOT_SLOT_CLEARED", 3)
			assert.same({ 3, 2 }, { ns.Catches.Stats() })
			_G.SlashCmdList.MASTERANGLER("stats")
			assert.is_truthy(_G.DEFAULT_CHAT_FRAME.lines[1]:find("3 catches of 2 different items", 1, true))
		end)

		it("skips malformed rows in the distinct count", function()
			local char = ns.Char()
			char.catches = { "bad", {}, { 7 } }
			assert.same({ 3, 1 }, { ns.Catches.Stats() })
		end)

		it("prints the newer-database warning instead of counts in read-only mode", function()
			ns.readOnly = true
			_G.SlashCmdList.MASTERANGLER("stats")
			assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
			assert.is_truthy(_G.DEFAULT_CHAT_FRAME.lines[1]:find(ns.L.DB_NEWER, 1, true))
		end)

		it("prints zero for a new character and without a character", function()
			assert.same({ 0, 0 }, { ns.Catches.Stats() })
			wow.player.name = nil
			assert.same({ 0, 0 }, { ns.Catches.Stats() })
		end)
	end)
end)
