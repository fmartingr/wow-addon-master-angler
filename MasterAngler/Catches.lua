local _, ns = ...

ns.Catches = {}
local Catches = ns.Catches

Catches.ITEM = 1
Catches.MAP = 2
Catches.X = 3
Catches.Y = 4
Catches.TIME = 5
Catches.GAME_MINUTE = 6
Catches.QTY = 7

local MAX_MAP_STEPS = 10
local ZONE_TYPE_FALLBACK = 3

local subscribers = {}
local pending = {}
local context

local function zoneType()
	local mapTypes = Enum and Enum.UIMapType
	return mapTypes and mapTypes.Zone or ZONE_TYPE_FALLBACK
end

function Catches.ZoneMap(mapID)
	if type(mapID) ~= "number" then
		return nil
	end
	local zone = zoneType()
	local id = mapID
	for _ = 1, MAX_MAP_STEPS do
		local info = ns.Safe(C_Map.GetMapInfo, id)
		if type(info) ~= "table" then
			break
		end
		if info.mapType == zone then
			return id
		end
		local parent = info.parentMapID
		if type(parent) ~= "number" or parent == 0 then
			break
		end
		id = parent
	end
	return mapID
end

local function round(value)
	return math.floor(value * 1000 + 0.5)
end

function Catches.Where()
	local best = ns.Safe(C_Map.GetBestMapForUnit, "player")
	if type(best) ~= "number" then
		return nil
	end
	local zone = Catches.ZoneMap(best)
	local position = ns.Safe(C_Map.GetPlayerMapPosition, zone, "player")
	if type(position) ~= "table" then
		return zone, -1, -1
	end
	local x, y = ns.Safe(position.GetXY, position)
	if type(x) ~= "number" or type(y) ~= "number" or not (x >= 0 and x <= 1 and y >= 0 and y <= 1) then
		return zone, -1, -1
	end
	return zone, round(x), round(y)
end

function Catches.Subscribe(fn)
	subscribers[#subscribers + 1] = fn
end

local function notify()
	for _, fn in ipairs(subscribers) do
		if not pcall(fn) then
			ns.ReportOnce("catches-subscriber", ns.L.HOOK_FAILED)
		end
	end
end

local function gameMinute()
	local hour, minute = ns.Safe(GetGameTime)
	if type(hour) ~= "number" or type(minute) ~= "number" then
		return 0
	end
	return hour * 60 + minute
end

local function onLootOpened()
	pending = {}
	context = nil
	if not ns.Safe(IsFishingLoot) then
		return
	end
	local zone, x, y = Catches.Where()
	context = {
		map = zone or 0,
		x = x or -1,
		y = y or -1,
		time = ns.Safe(GetServerTime) or 0,
		minute = gameMinute(),
	}
	for slot = 1, ns.Safe(GetNumLootItems) or 0 do
		local link = ns.Safe(GetLootSlotLink, slot)
		if type(link) == "string" then
			local _, _, quantity, _, _, _, _, _, _, isCoin = ns.Safe(GetLootSlotInfo, slot)
			local itemID = ns.Gear.ItemID(link)
			if itemID and isCoin ~= true then
				local count = type(quantity) == "number" and quantity >= 1 and math.floor(quantity) or 1
				pending[slot] = { itemID = itemID, quantity = count }
			end
		end
	end
end

local function onSlotCleared(_, slot)
	local entry = pending[slot]
	if not entry then
		return
	end
	pending[slot] = nil
	local char = ns.Char()
	if not char then
		return
	end
	char.catches[#char.catches + 1] =
		{ entry.itemID, context.map, context.x, context.y, context.time, context.minute, entry.quantity }
	notify()
end

local function onLootClosed()
	pending = {}
	context = nil
end

function Catches.Stats()
	local char = ns.Char()
	local rows, distinct, seen = 0, 0, {}
	for _, row in ipairs(char and char.catches or {}) do
		rows = rows + 1
		local id = type(row) == "table" and row[Catches.ITEM]
		if id and not seen[id] then
			seen[id] = true
			distinct = distinct + 1
		end
	end
	return rows, distinct
end

function Catches.PrintStats()
	-- Read-only mode hides the character data, so a count of zero would be false.
	if ns.readOnly then
		ns.Print(ns.L.DB_NEWER)
		return
	end
	ns.Print(string.format(ns.L.STATS, Catches.Stats()))
end

ns.On("LOOT_OPENED", onLootOpened)
ns.On("LOOT_SLOT_CLEARED", onSlotCleared)
ns.On("LOOT_CLOSED", onLootClosed)
ns.Commands.Register("stats", Catches.PrintStats, "HELP_STATS")
