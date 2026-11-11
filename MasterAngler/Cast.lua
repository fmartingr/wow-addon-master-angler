local _, ns = ...

ns.Cast = {}
local Cast = ns.Cast

local BUTTON_NAME = "MasterAnglerCastButton"
local MIN_GAP = 0.05
local MAX_GAP = 0.4
local SAFETY_SECONDS = 1

local subscribers = {}
local lastRightDown
local buttonReady = false
local overrideGeneration = 0

Cast.lineOut = false

local button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
Cast.button = button

-- Click registration and attributes of a secure button are locked in combat, so after a
-- /reload in combat the setup waits for the end of the fight.
-- The override only catches the up of the second click, so the action must fire on the up
-- whatever ActionButtonUseKeyDown says.
local function setupButton()
	if InCombatLockdown() then
		return false
	end
	if not buttonReady then
		button:RegisterForClicks("AnyUp", "AnyDown")
		button:SetAttribute("useOnKeyDown", false)
		button:Hide()
		buttonReady = true
	end
	return true
end
setupButton()

function Cast.Subscribe(fn)
	subscribers[#subscribers + 1] = fn
end

local function notify()
	for _, fn in ipairs(subscribers) do
		if not pcall(fn, Cast.lineOut) then
			ns.ReportOnce("cast-subscriber", ns.L.HOOK_FAILED)
		end
	end
end

function Cast.Prepare()
	if not setupButton() then
		return false
	end
	if ns.Fishing.NeedsLure() then
		button:SetAttribute("type", "item")
		button:SetAttribute("item", "item:" .. ns.Fishing.BestLure())
		button:SetAttribute("target-slot", ns.Fishing.MAIN_HAND)
		button:SetAttribute("spell", nil)
		return true
	end
	local spellID = ns.Fishing.SpellID()
	if not spellID then
		button:SetAttribute("type", nil)
		return false
	end
	button:SetAttribute("type", "spell")
	button:SetAttribute("spell", spellID)
	button:SetAttribute("item", nil)
	button:SetAttribute("target-slot", nil)
	return true
end

function Cast.ClearOverride()
	if InCombatLockdown() then
		return false
	end
	ClearOverrideBindings(button)
	return true
end

local function isDoubleClick(now)
	local previous = lastRightDown
	lastRightDown = now
	if not previous then
		return false
	end
	local gap = now - previous
	-- A pair is spent even when the cast is refused, so its second press never starts a new pair.
	if gap >= MIN_GAP and gap <= MAX_GAP then
		lastRightDown = nil
		return true
	end
	return false
end

local function overWorld()
	local foci = ns.Safe(GetMouseFoci)
	return type(foci) == "table" and foci[1] == WorldFrame
end

function Cast.OnMouseDown(_, mouseButton)
	if mouseButton ~= "RightButton" then
		return
	end
	local double = isDoubleClick(GetTime())
	if not double then
		return
	end
	if
		not ns.Settings.Get("doubleClick")
		or InCombatLockdown()
		or Cast.lineOut
		or not ns.Fishing.Active()
		or not overWorld()
		or UnitExists("mouseover")
	then
		return
	end
	if not Cast.Prepare() then
		return
	end
	-- The second press started a camera turn whose release the override takes, so it would never end.
	if ns.Safe(IsMouselooking) then
		ns.Safe(MouselookStop)
	end
	SetOverrideBindingClick(button, true, "BUTTON2", BUTTON_NAME)
	overrideGeneration = overrideGeneration + 1
	local generation = overrideGeneration
	-- A timer left from an earlier override must not drop a newer one before its click.
	C_Timer.After(SAFETY_SECONDS, function()
		if generation == overrideGeneration then
			Cast.ClearOverride()
		end
	end)
end

function Cast.OnChannel(event, unit, _, spellID)
	if ns.IsSecret(unit) or unit ~= "player" or ns.IsSecret(spellID) then
		return
	end
	if not ns.Fishing.IsFishingSpell(spellID) then
		return
	end
	local out = event == "UNIT_SPELLCAST_CHANNEL_START"
	if Cast.lineOut ~= out then
		Cast.lineOut = out
		notify()
	end
end

-- A key override can sit on for minutes, and the lure crossing its refresh time fires no event.
button:SetScript("PreClick", function(_, _, down)
	if not down then
		Cast.Prepare()
	end
end)

-- Clearing on the down would leave the up, which fires the action, with no binding.
button:SetScript("PostClick", function(_, _, down)
	if down then
		return
	end
	Cast.ClearOverride()
	Cast.Prepare()
end)

local function prepare()
	Cast.Prepare()
end

-- A /reload during the channel fires no CHANNEL_START, so the line state comes from the live channel.
local function syncLine()
	local spellID = select(8, ns.Safe(UnitChannelInfo, "player"))
	Cast.lineOut = spellID ~= nil and ns.Fishing.IsFishingSpell(spellID)
end
Cast.SyncLine = syncLine

ns.On("GLOBAL_MOUSE_DOWN", Cast.OnMouseDown)
ns.On("UNIT_SPELLCAST_CHANNEL_START", Cast.OnChannel)
ns.On("UNIT_SPELLCAST_CHANNEL_STOP", Cast.OnChannel)
ns.On("PLAYER_REGEN_DISABLED", Cast.ClearOverride)
ns.On("PLAYER_REGEN_ENABLED", prepare)
ns.On("BAG_UPDATE_DELAYED", prepare)
ns.On("PLAYER_EQUIPMENT_CHANGED", prepare)
ns.On("UNIT_INVENTORY_CHANGED", function(_, unit)
	if unit == "player" then
		Cast.Prepare()
	end
end)
ns.Mode.Subscribe(prepare)
ns.Settings.AddToggle("doubleClick", "SET_DOUBLECLICK", "SET_DOUBLECLICK_TIP", true)
table.insert(ns.startup, syncLine)
table.insert(ns.startup, prepare)
