local _, ns = ...

ns.Interact = {}
local Interact = ns.Interact

local OWNER_NAME = "MasterAnglerInteractOwner"
local BINDING = "INTERACTTARGET"
local CAST_BUTTON = "MasterAnglerCastButton"
local QUIET_SECONDS = 1
local POLL_SECONDS = 0.2
local SOFT_GROUP = "soft"
local SOFT_VALUES = {
	SoftTargetInteract = "3",
	SoftTargetInteractRange = "30",
	SoftTargetInteractRangeIsHard = "0",
	SoftTargetInteractArc = "2",
}

Interact.BUSY_FRAMES = {
	"LootFrame",
	"MerchantFrame",
	"GossipFrame",
	"QuestFrame",
	"TaxiFrame",
	"BankFrame",
	"TradeFrame",
	"MailFrame",
	"ClassTrainerFrame",
	"AuctionFrame",
	"KeyBindingFrame",
	"SettingsPanel",
	"GameMenuFrame",
}

local owner = CreateFrame("Frame", OWNER_NAME)
Interact.owner = owner

local keys = {}
local overrideOn = false
local quietUntil = 0

local function readKeys()
	local found = {}
	local first, second = ns.Safe(GetBindingKey, BINDING)
	for _, key in ipairs({ first or false, second or false }) do
		if type(key) == "string" and key ~= "" then
			found[#found + 1] = key
		end
	end
	return found
end

Interact.Keys = readKeys

local function sameKeys(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function busyFrameShown()
	for _, name in ipairs(Interact.BUSY_FRAMES) do
		local frame = rawget(_G, name)
		if type(frame) == "table" and frame.IsShown and frame:IsShown() then
			return true
		end
	end
	return false
end

function Interact.Reason(now)
	if not ns.Settings.Get("interactKey") then
		return "off"
	end
	if InCombatLockdown() then
		return "combat"
	end
	if not ns.Fishing.PoleEquipped() then
		return "inactive"
	end
	if not ns.Fishing.SpellID() then
		return "no-spell"
	end
	if ns.Cast.lineOut then
		return "line-out"
	end
	if now < quietUntil then
		return "line-in"
	end
	if UnitExists("softinteract") then
		return "soft-target"
	end
	if busyFrameShown() then
		return "window"
	end
	return nil
end

function Interact.ClearOverride()
	if InCombatLockdown() then
		return false
	end
	if overrideOn then
		ClearOverrideBindings(owner)
		overrideOn = false
	end
	return true
end

function Interact.Update()
	if InCombatLockdown() then
		return
	end
	if Interact.Reason(GetTime()) then
		Interact.ClearOverride()
		return
	end
	if overrideOn or #keys == 0 then
		return
	end
	if not ns.Cast.Prepare() then
		return
	end
	-- The flag goes first, so a failed bind in the loop still leaves the bound keys for ClearOverride.
	overrideOn = true
	for _, key in ipairs(keys) do
		SetOverrideBindingClick(owner, false, key, CAST_BUTTON)
	end
end

-- Timers, frame hooks and the poll run outside ns.On, so an error here would repeat in the game's error frame.
local function safeUpdate()
	if not pcall(Interact.Update) then
		ns.ReportOnce("interact-update", ns.L.HOOK_FAILED)
	end
end

local function updateSoon()
	safeUpdate()
	C_Timer.After(0, safeUpdate)
end

-- Override changes also fire UPDATE_BINDINGS, so an unchanged key list keeps the override as it is.
-- The list kept is always read with no override on.
function Interact.RefreshKeys()
	if overrideOn and sameKeys(readKeys(), keys) then
		return
	end
	if overrideOn and not Interact.ClearOverride() then
		return
	end
	keys = readKeys()
	Interact.Update()
end

local function onLine(lineOut)
	if lineOut then
		ns.CVars.Apply(SOFT_GROUP, SOFT_VALUES)
	else
		ns.CVars.Restore(SOFT_GROUP)
		quietUntil = GetTime() + QUIET_SECONDS
		C_Timer.After(QUIET_SECONDS + 0.05, safeUpdate)
	end
	Interact.Update()
end

-- Menus such as the game menu or settings fire no interaction event, so their show and hide are hooked.
local hooked = {}
local function hookBusyFrames()
	for _, name in ipairs(Interact.BUSY_FRAMES) do
		local frame = rawget(_G, name)
		if type(frame) == "table" and type(frame.HookScript) == "function" then
			for _, script in ipairs({ "OnShow", "OnHide" }) do
				local id = name .. script
				if not hooked[id] then
					hooked[id] = pcall(frame.HookScript, frame, script, updateSoon)
				end
			end
		end
	end
end

local function startup()
	if not ns.Cast.lineOut then
		ns.CVars.Restore(SOFT_GROUP)
	end
	hookBusyFrames()
	Interact.RefreshKeys()
end

local elapsed = 0
local function onPoll(_, delta)
	elapsed = elapsed + delta
	if elapsed < POLL_SECONDS then
		return
	end
	elapsed = 0
	if ns.Fishing.PoleEquipped() then
		safeUpdate()
	end
end

local function watchSoftTarget()
	local ok = pcall(owner.RegisterEvent, owner, "PLAYER_SOFT_INTERACT_CHANGED")
	if ok then
		owner:SetScript("OnEvent", safeUpdate)
	else
		owner:SetScript("OnUpdate", onPoll)
	end
	return ok
end

ns.Cast.Subscribe(onLine)
ns.Settings.AddToggle("interactKey", "SET_INTERACT", "SET_INTERACT_TIP", true)
ns.Settings.OnChange("interactKey", Interact.Update)
ns.On("PLAYER_REGEN_DISABLED", Interact.ClearOverride)
ns.On("PLAYER_REGEN_ENABLED", Interact.RefreshKeys)
ns.On("ADDON_LOADED", hookBusyFrames)
ns.On("PLAYER_EQUIPMENT_CHANGED", Interact.Update)
ns.On("UPDATE_BINDINGS", Interact.RefreshKeys)
ns.On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", updateSoon)
ns.On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", updateSoon)
ns.On("LOOT_OPENED", updateSoon)
ns.On("LOOT_CLOSED", updateSoon)
Interact.watchSoftTarget = watchSoftTarget
table.insert(ns.startup, watchSoftTarget)
table.insert(ns.startup, startup)
