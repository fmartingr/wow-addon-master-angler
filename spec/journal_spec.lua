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

	local function ids(index)
		local list = {}
		for _, entry in ipairs(index.fish) do
			list[#list + 1] = entry.itemID
		end
		return list
	end

	it("has one entry for each item with totals and first and last times", function()
		local chars = { ["Me-R"] = { catches = { row(1, 10, 300, 2), row(1, 11, 100), row(1, 10, 200, 3) } } }
		local entry = ns.Journal.Build(chars, "Me-R").byItem[1]
		assert.is_true(entry.mine)
		assert.equals(6, entry.count)
		assert.equals(100, entry.first)
		assert.equals(300, entry.last)
	end)

	it("lists the zones of an item with count and last time, most caught first", function()
		local chars = { ["Me-R"] = { catches = { row(1, 10, 100), row(1, 11, 400, 5), row(1, 10, 300) } } }
		local zones = ns.Journal.Build(chars, "Me-R").byItem[1].zones
		assert.same({ mapID = 11, count = 5, first = 400, last = 400 }, zones[1])
		assert.same({ mapID = 10, count = 2, first = 100, last = 300 }, zones[2])
	end)

	it("breaks a tie of zone counts by map ID", function()
		local chars = { ["Me-R"] = { catches = { row(1, 30, 1), row(1, 20, 1) } } }
		local zones = ns.Journal.Build(chars, "Me-R").byItem[1].zones
		assert.same({ 20, 30 }, { zones[1].mapID, zones[2].mapID })
	end)

	it("an item that only alts caught has no data", function()
		local chars = {
			["Me-R"] = { catches = { row(1, 10, 100) } },
			["Alt-R"] = { catches = { row(2, 10, 100) } },
		}
		local index = ns.Journal.Build(chars, "Me-R")
		assert.same({ itemID = 2, mine = false }, index.byItem[2])
	end)

	it("an item caught by both counts as mine and uses only my data", function()
		local chars = {
			["Me-R"] = { catches = { row(1, 10, 100) } },
			["Alt-R"] = { catches = { row(1, 11, 50, 9) } },
		}
		local entry = ns.Journal.Build(chars, "Me-R").byItem[1]
		assert.is_true(entry.mine)
		assert.equals(1, entry.count)
		assert.equals(1, #entry.zones)
	end)

	it("sorts mine by count descending, then alt-only by item ID", function()
		local chars = {
			["Me-R"] = { catches = { row(5, 10, 1), row(6, 10, 1, 4), row(7, 10, 1, 4), row(8, 10, 1, 2) } },
			["Alt-R"] = { catches = { row(30, 10, 1), row(20, 10, 1) } },
		}
		assert.same({ 6, 7, 8, 5, 20, 30 }, ids(ns.Journal.Build(chars, "Me-R")))
	end)

	it("handles empty input", function()
		assert.same({ fish = {}, byItem = {} }, ns.Journal.Build({}, "Me-R"))
		assert.same({ fish = {}, byItem = {} }, ns.Journal.Build(nil, "Me-R"))
	end)

	it("handles a character without catches and malformed rows", function()
		local chars = {
			["Me-R"] = { catches = { "bad", { "x", 10 }, { 1, "y" }, row(1, 10, 1) } },
			["Old-R"] = {},
			["Bad-R"] = "text",
			["Alt-R"] = { catches = "nope" },
		}
		local index = ns.Journal.Build(chars, "Me-R")
		assert.same({ 1 }, ids(index))
	end)

	it("treats a missing quantity and time as 1 and 0", function()
		local chars = { ["Me-R"] = { catches = { { 1, 10 } } } }
		local entry = ns.Journal.Build(chars, "Me-R").byItem[1]
		assert.equals(1, entry.count)
		assert.equals(0, entry.first)
	end)
end)
