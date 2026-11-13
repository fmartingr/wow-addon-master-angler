local _, ns = ...

ns.Cast = {}
local Cast = ns.Cast

local BUTTON_NAME = "MasterAnglerCastButton"
local DOUBLE_CLICK_KEY = "BUTTON2"
local CLICK_MAX_SECONDS = 0.3
local WINDOW_SECONDS = 0.4
local SAFETY_SECONDS = 1

local subscribers = {}
local downAt
local windowOpen = false
local pressed = false
local windowGeneration = 0
local buttonReady = false

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

local function overWorld()
	local foci = ns.Safe(GetMouseFoci)
	return type(foci) == "table" and foci[1] == WorldFrame
end

local function eligible()
	return ns.Settings.Get("doubleClick")
		and not InCombatLockdown()
		and ns.Fishing.PoleEquipped()
		and overWorld()
		and not UnitExists("mouseover")
end

-- The binding is set after the first click, so the second press itself fires the action.
local function bindTarget()
	Cast.SyncLine()
	if Cast.lineOut then
		SetOverrideBinding(button, true, DOUBLE_CLICK_KEY, "INTERACTTARGET")
		return true
	end
	if not Cast.Prepare() then
		return false
	end
	local name = button:GetAttribute("type") == "spell" and ns.Fishing.SpellName(ns.Fishing.SpellID())
	if name then
		SetOverrideBindingSpell(button, true, DOUBLE_CLICK_KEY, name)
	else
		SetOverrideBindingClick(button, true, DOUBLE_CLICK_KEY, BUTTON_NAME)
	end
	return true
end

local function closeWindow()
	windowOpen, pressed = false, false
	Cast.ClearOverride()
end

local function openWindow()
	if not bindTarget() then
		return
	end
	windowOpen, pressed = true, false
	windowGeneration = windowGeneration + 1
	local generation = windowGeneration
	C_Timer.After(WINDOW_SECONDS, function()
		if generation == windowGeneration and not pressed then
			closeWindow()
		end
	end)
	C_Timer.After(WINDOW_SECONDS + SAFETY_SECONDS, function()
		if generation == windowGeneration then
			closeWindow()
		end
	end)
end

function Cast.WindowOpen()
	return windowOpen
end

function Cast.OnMouseDown(_, mouseButton)
	if mouseButton ~= "RightButton" then
		return
	end
	if windowOpen then
		pressed = true
		return
	end
	downAt = eligible() and GetTime() or nil
end

function Cast.OnMouseUp(_, mouseButton)
	if mouseButton ~= "RightButton" then
		return
	end
	if windowOpen then
		if pressed then
			closeWindow()
		end
		return
	end
	local started = downAt
	downAt = nil
	if started and GetTime() - started <= CLICK_MAX_SECONDS and eligible() then
		openWindow()
	end
end

local function setLine(out)
	if Cast.lineOut ~= out then
		Cast.lineOut = out
		notify()
	end
end

function Cast.OnChannel(event, unit, _, spellID)
	if ns.IsSecret(unit) or unit ~= "player" or ns.IsSecret(spellID) then
		return
	end
	if not ns.Fishing.IsFishingSpell(spellID) then
		return
	end
	setLine(event == "UNIT_SPELLCAST_CHANNEL_START")
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
	if button:GetAttribute("type") == "item" then
		ns.Fishing.NoteLureUse()
	end
	closeWindow()
	Cast.Prepare()
end)

local function prepare()
	Cast.Prepare()
end

-- A /reload during the channel fires no CHANNEL_START, and an event can carry an ID the list lacks,
-- so the line state also comes from the live channel, by spell name.
function Cast.SyncLine()
	if type(UnitChannelInfo) ~= "function" then
		return
	end
	local channel = ns.Safe(UnitChannelInfo, "player")
	local fishing = ns.Fishing.SpellName(ns.Fishing.SpellID() or ns.Fishing.SPELLS[#ns.Fishing.SPELLS])
	setLine(type(channel) == "string" and fishing ~= nil and channel == fishing)
end

ns.On("GLOBAL_MOUSE_DOWN", Cast.OnMouseDown)
ns.On("GLOBAL_MOUSE_UP", Cast.OnMouseUp)
ns.On("UNIT_SPELLCAST_CHANNEL_START", Cast.OnChannel)
ns.On("UNIT_SPELLCAST_CHANNEL_STOP", Cast.OnChannel)
ns.On("PLAYER_REGEN_DISABLED", closeWindow)
ns.On("PLAYER_REGEN_ENABLED", prepare)
ns.On("BAG_UPDATE_DELAYED", prepare)
ns.On("PLAYER_EQUIPMENT_CHANGED", prepare)
ns.On("UNIT_INVENTORY_CHANGED", function(_, unit)
	if unit == "player" then
		Cast.Prepare()
	end
end)
ns.Settings.AddToggle("doubleClick", "SET_DOUBLECLICK", "SET_DOUBLECLICK_TIP", true)
table.insert(ns.startup, Cast.SyncLine)
table.insert(ns.startup, prepare)
