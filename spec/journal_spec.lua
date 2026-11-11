local wow = require("spec.helpers.wow")

describe("Journal", function()
	local ns
	before_each(function()
		ns = wow.boot()
	end)
	after_each(function()
		wow.restore()
	end)

	local function row(item, map, time, qty)
		return { item, map, 500, 500, time, 0, qty or 1 }
	end

	local function zoneOf(index, mapID)
		for _, zone in ipairs(index.zones) do
			if zone.mapID == mapID then
				return zone
			end
		end
	end

	it("counts mine and alt items per zone", function()
		local chars = {
			["Me-R"] = { catches = { row(1, 10, 100), row(2, 10, 200), row(1, 11, 300) } },
			["Alt-R"] = { catches = { row(3, 10, 400), row(4, 10, 500) } },
		}
		local index = ns.Journal.Build(chars, "Me-R")
		assert.same({ mapID = 10, mine = 2, alts = 2 }, zoneOf(index, 10))
		assert.same({ mapID = 11, mine = 1, alts = 0 }, zoneOf(index, 11))
	end)

	it("lists ??? only for items that only alts caught in that zone", function()
		local chars = {
			["Me-R"] = { catches = { row(1, 10, 100) } },
			["Alt-R"] = { catches = { row(2, 10, 100), row(1, 11, 100) } },
		}
		local index = ns.Journal.Build(chars, "Me-R")
		assert.is_true(index.pages[10][1].mine)
		assert.same({ itemID = 2, mine = false }, index.pages[10][2])
		assert.same({ itemID = 1, mine = false }, index.pages[11][1])
	end)

	it("an item caught by both counts as mine", function()
		local chars = {
			["Me-R"] = { catches = { row(1, 10, 100) } },
			["Alt-R"] = { catches = { row(1, 10, 50, 9) } },
		}
		local page = ns.Journal.Build(chars, "Me-R").pages[10]
		assert.equals(1, #page)
		assert.is_true(page[1].mine)
		assert.equals(1, page[1].count)
	end)

	it("sums the quantities", function()
		local chars = { ["Me-R"] = { catches = { row(1, 10, 100, 2), row(1, 10, 200, 3) } } }
		assert.equals(5, ns.Journal.Build(chars, "Me-R").pages[10][1].count)
	end)

	it("keeps the first and last catch times", function()
		local chars = { ["Me-R"] = { catches = { row(1, 10, 300), row(1, 10, 100), row(1, 10, 200) } } }
		local entry = ns.Journal.Build(chars, "Me-R").pages[10][1]
		assert.equals(100, entry.first)
		assert.equals(300, entry.last)
	end)

	it("sorts mine by count descending, then ??? by item ID", function()
		local chars = {
			["Me-R"] = { catches = { row(5, 10, 1), row(6, 10, 1, 4), row(7, 10, 1, 4), row(8, 10, 1, 2) } },
			["Alt-R"] = { catches = { row(30, 10, 1), row(20, 10, 1) } },
		}
		local page = ns.Journal.Build(chars, "Me-R").pages[10]
		local order = {}
		for _, entry in ipairs(page) do
			order[#order + 1] = entry.itemID
		end
		assert.same({ 6, 7, 8, 5, 20, 30 }, order)
	end)

	it("sorts the zones by map ID as a stable default", function()
		local chars = { ["Me-R"] = { catches = { row(1, 30, 1), row(1, 10, 1), row(1, 20, 1) } } }
		local ids = {}
		for _, zone in ipairs(ns.Journal.Build(chars, "Me-R").zones) do
			ids[#ids + 1] = zone.mapID
		end
		assert.same({ 10, 20, 30 }, ids)
	end)

	it("handles empty input", function()
		assert.same({ zones = {}, pages = {} }, ns.Journal.Build({}, "Me-R"))
		assert.same({ zones = {}, pages = {} }, ns.Journal.Build(nil, "Me-R"))
	end)

	it("handles a character without catches and malformed rows", function()
		local chars = {
			["Me-R"] = { catches = { "bad", { "x", 10 }, { 1, "y" }, row(1, 10, 1) } },
			["Old-R"] = {},
			["Bad-R"] = "text",
			["Alt-R"] = { catches = "nope" },
		}
		local index = ns.Journal.Build(chars, "Me-R")
		assert.equals(1, #index.zones)
		assert.equals(1, #index.pages[10])
	end)

	it("treats a missing quantity and time as 1 and 0", function()
		local chars = { ["Me-R"] = { catches = { { 1, 10 } } } }
		local entry = ns.Journal.Build(chars, "Me-R").pages[10][1]
		assert.equals(1, entry.count)
		assert.equals(0, entry.first)
	end)

	it("a missing time does not replace a known first catch", function()
		local chars = { ["Me-R"] = { catches = { { 1, 10, 0, 0, 0 }, { 1, 10, 0, 0, 500 }, { 1, 10, 0, 0, 0 } } } }
		local entry = ns.Journal.Build(chars, "Me-R").pages[10][1]
		assert.equals(500, entry.first)
		assert.equals(500, entry.last)
	end)
end)
