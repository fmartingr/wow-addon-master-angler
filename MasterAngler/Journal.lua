local _, ns = ...

ns.Journal = {}
local Journal = ns.Journal

local function sortPage(page)
	table.sort(page, function(a, b)
		if a.mine ~= b.mine then
			return a.mine
		end
		if a.mine and a.count ~= b.count then
			return a.count > b.count
		end
		return a.itemID < b.itemID
	end)
end

local function addRow(pages, row, isMine)
	if type(row) ~= "table" then
		return
	end
	local itemID = row[ns.Catches.ITEM]
	local mapID = row[ns.Catches.MAP]
	if type(itemID) ~= "number" or type(mapID) ~= "number" then
		return
	end
	pages[mapID] = pages[mapID] or {}
	local entry = pages[mapID][itemID]
	if not entry then
		entry = { itemID = itemID, mine = false }
		pages[mapID][itemID] = entry
	end
	if not isMine then
		return
	end
	local quantity = tonumber(row[ns.Catches.QTY]) or 1
	local time = tonumber(row[ns.Catches.TIME]) or 0
	if not entry.mine then
		entry.mine, entry.count, entry.first, entry.last = true, 0, time, time
	end
	entry.count = entry.count + quantity
	-- A time of 0 means the server time was unknown, so it never replaces a real first catch.
	if time > 0 then
		entry.first = entry.first > 0 and math.min(entry.first, time) or time
		entry.last = math.max(entry.last, time)
	end
end

function Journal.Build(chars, currentKey)
	local keyed = {}
	for key, char in pairs(type(chars) == "table" and chars or {}) do
		if type(char) == "table" and type(char.catches) == "table" then
			for _, row in ipairs(char.catches) do
				addRow(keyed, row, key == currentKey)
			end
		end
	end
	local result = { zones = {}, pages = {} }
	for mapID, items in pairs(keyed) do
		local page, mine, alts = {}, 0, 0
		for _, entry in pairs(items) do
			page[#page + 1] = entry
			if entry.mine then
				mine = mine + 1
			else
				alts = alts + 1
			end
		end
		sortPage(page)
		result.pages[mapID] = page
		result.zones[#result.zones + 1] = { mapID = mapID, mine = mine, alts = alts }
	end
	table.sort(result.zones, function(a, b)
		return a.mapID < b.mapID
	end)
	return result
end
