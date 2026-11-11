local _, ns = ...

ns.Gear = {}
local Gear = ns.Gear

Gear.SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

local function itemID(link)
	if type(link) ~= "string" then
		return nil
	end
	return tonumber(link:match("item:(%d+)"))
end
Gear.ItemID = itemID

function Gear.Snapshot()
	local snapshot = {}
	for _, slot in ipairs(Gear.SLOTS) do
		snapshot[slot] = GetInventoryItemLink("player", slot) or false
	end
	return snapshot
end

function Gear.Count(set)
	local count = 0
	for _, link in pairs(set) do
		if link then
			count = count + 1
		end
	end
	return count
end

function Gear.Save()
	local char = ns.Char()
	if not char then
		return
	end
	local snapshot = Gear.Snapshot()
	char.gear = snapshot
	ns.Print(string.format(ns.L.GEAR_SAVED, Gear.Count(snapshot)))
end

function Gear.Plan(target, current)
	local plan = {}
	for _, slot in ipairs(Gear.SLOTS) do
		local want = target[slot] or false
		if itemID(want) ~= itemID(current[slot]) then
			plan[#plan + 1] = { slot = slot, link = want }
		end
	end
	return plan
end

local function bagInventorySlot(bag)
	local fromApi = C_Container.ContainerIDToInventoryID
	return fromApi and fromApi(bag) or (19 + bag)
end

local function freeSlotsByBag()
	local free = {}
	for bag = 0, 4 do
		local count, bagType = C_Container.GetContainerNumFreeSlots(bag)
		free[bag] = (count and (bagType == nil or bagType == 0)) and count or 0
	end
	return free
end

-- The client updates bag free counts only after the server confirms a move,
-- so slots taken in this pass are tracked locally.
local function takeFreeBag(free)
	for bag = 0, 4 do
		if free[bag] > 0 then
			free[bag] = free[bag] - 1
			return bag
		end
	end
	return nil
end

-- An item held on the cursor would be equipped, swapped or put into a slot by
-- the next call. A put can fail when a two-handed equip fills a bag slot that
-- the client still counts as free.
local function dropCursor()
	if CursorHasItem and CursorHasItem() then
		ClearCursor()
	end
end

local function unequip(slot, free)
	dropCursor()
	local worn = GetInventoryItemLink("player", slot)
	PickupInventoryItem(slot)
	if CursorHasItem and not CursorHasItem() then
		return
	end
	local bag = takeFreeBag(free)
	if not bag then
		ClearCursor()
		ns.ReportOnce("bags-full-" .. slot, string.format(ns.L.BAGS_FULL, worn or slot))
		return
	end
	if bag == 0 then
		PutItemInBackpack()
	else
		PutItemInBag(bagInventorySlot(bag))
	end
end

function Gear.Apply(plan)
	dropCursor()
	for _, entry in ipairs(plan) do
		if entry.link then
			local id = itemID(entry.link)
			if id and GetItemCount(id) == 0 then
				ns.ReportOnce("gear-missing-" .. id, string.format(ns.L.GEAR_MISSING, entry.link))
			else
				C_Item.EquipItemByName(entry.link, entry.slot)
			end
		end
	end
	local free
	for _, entry in ipairs(plan) do
		if not entry.link then
			free = free or freeSlotsByBag()
			unequip(entry.slot, free)
		end
	end
	if free then
		dropCursor()
	end
end

ns.Commands.Register("savegear", Gear.Save, "HELP_SAVEGEAR")
