local _, ns = ...

ns.Fishing = {}
local Fishing = ns.Fishing

local MAIN_HAND = 16
local WEAPON_CLASS = 2
local POLE_SUBCLASS = 20
local LURE_REFRESH_SECONDS = 30
local MS_THRESHOLD = 3600
local LURE_GRACE_SECONDS = 8

local lastLureUse

Fishing.SPELLS = { 18248, 7732, 7731, 7620 }
Fishing.LURES = { 6533, 6532, 7307, 6530, 6811, 6529 }
Fishing.MAIN_HAND = MAIN_HAND

local function isKnown(spellID)
	if IsPlayerSpell and ns.Safe(IsPlayerSpell, spellID) then
		return true
	end
	return C_SpellBook ~= nil and ns.Safe(C_SpellBook.IsSpellKnown, spellID) == true
end

function Fishing.SpellID()
	for _, spellID in ipairs(Fishing.SPELLS) do
		if isKnown(spellID) then
			return spellID
		end
	end
	return nil
end

function Fishing.SpellName(spellID)
	local name = C_Spell and ns.Safe(C_Spell.GetSpellName, spellID) or ns.Safe(GetSpellInfo, spellID)
	if type(name) == "string" and name ~= "" then
		return name
	end
	return nil
end

-- Every rank shares one name, so a channel with an ID that is not in the list still counts.
function Fishing.IsFishingSpell(spellID)
	for _, id in ipairs(Fishing.SPELLS) do
		if id == spellID then
			return true
		end
	end
	local name = Fishing.SpellName(spellID)
	return name ~= nil and name == Fishing.SpellName(Fishing.SPELLS[#Fishing.SPELLS])
end

function Fishing.BestLure()
	for _, itemID in ipairs(Fishing.LURES) do
		local count = C_Item and ns.Safe(C_Item.GetItemCount, itemID)
		-- Stronger lures need fishing skill: an unusable one would fail on every click and block the cast.
		local usable = C_Item and ns.Safe(C_Item.IsUsableItem, itemID)
		if type(count) == "number" and count > 0 and usable ~= false then
			return itemID
		end
	end
	return nil
end

function Fishing.PoleEquipped()
	local itemID = ns.Safe(GetInventoryItemID, "player", MAIN_HAND)
	if not itemID then
		return false
	end
	local classID, subclassID = select(6, ns.Safe(C_Item.GetItemInfoInstant, itemID))
	local poleSubclass = Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole or POLE_SUBCLASS
	return classID == WEAPON_CLASS and subclassID == poleSubclass
end

local function secondsFromApi()
	if type(C_PaperDollInfo) ~= "table" or type(C_PaperDollInfo.GetTemporaryEnchantmentInfo) ~= "function" then
		return nil
	end
	local ok, info = pcall(C_PaperDollInfo.GetTemporaryEnchantmentInfo, MAIN_HAND)
	if not ok or ns.IsSecret(info) then
		return nil
	end
	if type(info) ~= "table" then
		return 0
	end
	local ms = info.remainingTimeMs
	if ns.IsSecret(ms) then
		return nil
	end
	if type(ms) ~= "number" then
		return 0
	end
	return ms / 1000
end

local function secondsFromGlobal()
	if type(GetWeaponEnchantInfo) ~= "function" then
		return nil
	end
	local ok, hasEnchant, expiration = pcall(GetWeaponEnchantInfo)
	if not ok or ns.IsSecret(hasEnchant) or ns.IsSecret(expiration) then
		return nil
	end
	if not hasEnchant then
		return 0
	end
	if type(expiration) ~= "number" then
		return 0
	end
	if expiration > MS_THRESHOLD then
		return expiration / 1000
	end
	return expiration
end

function Fishing.LureSecondsLeft()
	local seconds = secondsFromApi()
	if seconds == nil then
		seconds = secondsFromGlobal()
	end
	return seconds
end

-- The pole shows a new lure a moment after the use, so a fresh use must not count as no lure.
function Fishing.NoteLureUse()
	lastLureUse = GetTime()
end

function Fishing.NeedsLure()
	if not ns.Settings.Get("autoLure") or not Fishing.PoleEquipped() or not Fishing.BestLure() then
		return false
	end
	if lastLureUse and GetTime() - lastLureUse < LURE_GRACE_SECONDS then
		return false
	end
	local seconds = Fishing.LureSecondsLeft()
	return seconds ~= nil and seconds < LURE_REFRESH_SECONDS
end

ns.Settings.AddToggle("autoLure", "SET_AUTOLURE", "SET_AUTOLURE_TIP", true)
