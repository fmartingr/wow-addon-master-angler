local _, ns = ...

ns.Journal = {}
local Journal = ns.Journal

local function sortFish(fish)
	table.sort(fish, function(a, b)
		if a.mine ~= b.mine then
			return a.mine
		end
		if a.mine and a.count ~= b.count then
			return a.count > b.count
		end
		return a.itemID < b.itemID
	end)
end

local function sortZones(zones)
	table.sort(zones, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.mapID < b.mapID
	end)
end

local function entryFor(byItem, itemID)
	local entry = byItem[itemID]
	if not entry then
		entry = { itemID = itemID, mine = false }
		byItem[itemID] = entry
	end
	return entry
end

local function addMine(entry, mapID, quantity, time)
	if not entry.mine then
		entry.mine, entry.count, entry.first, entry.last, entry.zones = true, 0, time, time, {}
	end
	entry.count = entry.count + quantity
	entry.first = math.min(entry.first, time)
	entry.last = math.max(entry.last, time)
	for _, zone in ipairs(entry.zones) do
		if zone.mapID == mapID then
			zone.count = zone.count + quantity
			zone.first = math.min(zone.first, time)
			zone.last = math.max(zone.last, time)
			return
		end
	end
	entry.zones[#entry.zones + 1] = { mapID = mapID, count = quantity, first = time, last = time }
end

local function addRow(byItem, row, isMine)
	if type(row) ~= "table" then
		return
	end
	local itemID = row[ns.Catches.ITEM]
	local mapID = row[ns.Catches.MAP]
	if type(itemID) ~= "number" or type(mapID) ~= "number" then
		return
	end
	local entry = entryFor(byItem, itemID)
	if isMine then
		addMine(entry, mapID, tonumber(row[ns.Catches.QTY]) or 1, tonumber(row[ns.Catches.TIME]) or 0)
	end
end

--- One entry for each item that any character caught. An item that the current character caught has its
--- totals and its zones. An item that only other characters caught has no data (shown as ???).
function Journal.Build(chars, currentKey)
	local byItem = {}
	for key, char in pairs(type(chars) == "table" and chars or {}) do
		if type(char) == "table" and type(char.catches) == "table" then
			for _, row in ipairs(char.catches) do
				addRow(byItem, row, key == currentKey)
			end
		end
	end
	local fish = {}
	for _, entry in pairs(byItem) do
		fish[#fish + 1] = entry
		if entry.zones then
			sortZones(entry.zones)
		end
	end
	sortFish(fish)
	return { fish = fish, byItem = byItem }
end
