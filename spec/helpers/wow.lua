local M = {}

local ADDON_NAME = "MasterAngler"
local ADDON_DIR = "MasterAngler/"

local function newFrame(name)
	local frame = { name = name, calls = {}, scripts = {}, events = {}, shown = false, children = {}, attrs = {} }
	local mt = {}
	mt.__index = function(_, key)
		if key == "GetName" then
			return function(self)
				return self.name
			end
		end
		local known = {
			Show = true,
			Hide = true,
			IsShown = true,
			GetWidth = true,
			GetHeight = true,
			GetAlpha = true,
			GetAttribute = true,
		}
		local prefixes = { "Set", "Register", "Unregister", "Create", "Enable", "Clear", "Add" }
		local isMethod = known[key]
		for _, prefix in ipairs(prefixes) do
			if type(key) == "string" and key:sub(1, #prefix) == prefix then
				isMethod = true
			end
		end
		if not isMethod then
			return nil
		end
		return function(self, ...)
			self.calls[#self.calls + 1] = { key, ... }
			if key == "SetScript" then
				local event, fn = ...
				self.scripts[event] = fn
			elseif key == "SetAttribute" then
				local attr, value = ...
				self.attrs[attr] = value
			elseif key == "GetAttribute" then
				return self.attrs[(...)]
			elseif key == "RegisterEvent" then
				self.events[(...)] = true
			elseif key == "UnregisterEvent" then
				self.events[(...)] = nil
			elseif key == "Show" then
				self.shown = true
			elseif key == "Hide" then
				self.shown = false
			elseif key == "IsShown" then
				return self.shown
			elseif key == "CreateTexture" or key == "CreateFontString" then
				local child = newFrame()
				self.children[#self.children + 1] = child
				return child
			elseif key == "GetAlpha" then
				return self.alpha or 1
			elseif key == "SetAlpha" then
				self.alpha = (...)
			elseif key == "GetWidth" or key == "GetHeight" then
				return 37
			end
			return nil
		end
	end
	return setmetatable(frame, mt)
end

M.newFrame = newFrame

function M.itemLink(id)
	return "|cffffffff|Hitem:" .. id .. "::::::::60:::::::|h[Item " .. id .. "]|h|r"
end

function M.readToc()
	local files = {}
	local file = assert(io.open(ADDON_DIR .. ADDON_NAME .. ".toc", "r"))
	for raw in file:lines() do
		local line = raw:gsub("\r", "")
		if line ~= "" and not line:match("^#") then
			files[#files + 1] = line
		end
	end
	file:close()
	return files
end

local saved

local function snapshot()
	saved = {}
	for k, v in pairs(_G) do
		saved[k] = v
	end
end

function M.restore()
	if not saved then
		return
	end
	for k in pairs(_G) do
		if saved[k] == nil then
			_G[k] = nil
		end
	end
	for k, v in pairs(saved) do
		_G[k] = v
	end
end

function M.reset()
	M.combat = false
	M.now = 100
	M.units = {}
	M.knownSpells = {}
	M.itemInfo = {}
	M.tempEnchant = nil
	M.overrides = {}
	M.clearedOverrides = 0
	M.mouseFocus = nil
	M.mouselooking = false
	M.worn = {}
	M.itemCounts = {}
	M.freeSlots = {}
	M.bagTypes = {}
	M.cursor = nil
	M.equipCalls = {}
	M.puts = {}
	M.cleared = 0
	M.secrets = {}
	M.cvars = {}
	M.cvarWrites = {}
	M.cvarFail = {}
	M.timers = {}
	M.player = { name = "Tester", realm = "Realm" }
	M.settingsLog = { settings = {}, checkboxes = {} }
end

function M.markSecret(value)
	M.secrets[value] = true
	return value
end

function M.runTimers()
	local timers = M.timers
	M.timers = {}
	for _, timer in ipairs(timers) do
		timer.fn()
	end
end

local function installSettingsStub()
	local log = M.settingsLog
	_G.Settings = {
		VarType = { Boolean = "boolean" },
		RegisterVerticalLayoutCategory = function(name)
			log.category = { name = name }
			return log.category
		end,
		RegisterAddOnSetting = function(category, variable, key, tbl, _, name, default)
			local setting =
				{ category = category, variable = variable, key = key, tbl = tbl, name = name, default = default }
			function setting:SetValueChangedCallback(fn)
				self.callback = fn
			end
			log.settings[#log.settings + 1] = setting
			return setting
		end,
		CreateCheckbox = function(category, setting, tooltip)
			log.checkboxes[#log.checkboxes + 1] = { category = category, setting = setting, tooltip = tooltip }
		end,
		RegisterAddOnCategory = function(category)
			log.registered = category
		end,
	}
end

function M.installStubs()
	M.reset()
	_G.CreateFrame = function(_, name)
		local frame = newFrame(name)
		if name then
			_G[name] = frame
		end
		return frame
	end
	_G.GetLocale = function()
		return M.locale or "enUS"
	end
	_G.hooksecurefunc = function() end
	_G.Enum = { TooltipDataType = { Item = 0 }, ItemWeaponSubclass = { Fishingpole = 20 } }
	_G.UIParent = newFrame("UIParent")
	_G.GetTime = function()
		return M.now
	end
	_G.IsMouselooking = function()
		return M.mouselooking
	end
	_G.MouselookStop = function()
		M.mouselooking = false
	end
	_G.UnitExists = function(unit)
		return M.units[unit] == true
	end
	_G.IsPlayerSpell = function(id)
		return M.knownSpells[id] == true
	end
	_G.GetInventoryItemID = function(_, slot)
		return tonumber((M.worn[slot] or ""):match("item:(%d+)"))
	end
	_G.C_PaperDollInfo = {
		GetTemporaryEnchantmentInfo = function()
			return M.tempEnchant
		end,
	}
	_G.SetOverrideBindingClick = function(owner, priority, key, name)
		M.overrides[#M.overrides + 1] = { owner = owner, priority = priority, key = key, name = name }
	end
	_G.ClearOverrideBindings = function()
		M.overrides = {}
		M.clearedOverrides = M.clearedOverrides + 1
	end
	_G.C_Item = {
		GetItemInfoInstant = function(id)
			local info = M.itemInfo[id]
			if not info then
				return id
			end
			return id, nil, nil, nil, nil, info[1], info[2]
		end,
		EquipItemByName = function(link, slot)
			M.equipCalls[#M.equipCalls + 1] = { link, slot }
			M.worn[slot] = link
		end,
	}
	_G.C_Container = {
		GetContainerNumFreeSlots = function(bag)
			local free = M.freeSlots[bag]
			if free == nil then
				free = 5
			end
			return free, M.bagTypes[bag] or 0
		end,
		ContainerIDToInventoryID = function(bag)
			return 19 + bag
		end,
	}
	_G.GetInventoryItemLink = function(_, slot)
		return M.worn[slot]
	end
	_G.GetItemCount = function(id)
		local count = M.itemCounts[id]
		if count == nil then
			return 1
		end
		return count
	end
	_G.PickupInventoryItem = function(slot)
		M.cursor = M.worn[slot]
		M.worn[slot] = nil
	end
	_G.CursorHasItem = function()
		return M.cursor ~= nil
	end
	_G.ClearCursor = function()
		M.cleared = M.cleared + 1
		M.cursor = nil
	end
	_G.PutItemInBackpack = function()
		M.puts[#M.puts + 1] = { bag = 0 }
		M.cursor = nil
	end
	_G.PutItemInBag = function(invSlot)
		M.puts[#M.puts + 1] = { bag = invSlot - 19, invSlot = invSlot }
		M.cursor = nil
	end
	_G.UISpecialFrames = {}
	_G.SlashCmdList = {}
	_G.DEFAULT_CHAT_FRAME = {
		lines = {},
		AddMessage = function(self, text)
			self.lines[#self.lines + 1] = text
		end,
	}
	_G.InCombatLockdown = function()
		return M.combat
	end
	_G.UnitName = function()
		return M.player.name
	end
	_G.GetNormalizedRealmName = function()
		return M.player.realm
	end
	_G.issecretvalue = function(value)
		return M.secrets[value] == true
	end
	_G.GetCVar = function(name)
		return M.cvars[name]
	end
	_G.SetCVar = function(name, value)
		if M.cvarFail[name] then
			error("SetCVar blocked: " .. name)
		end
		M.cvars[name] = value
		M.cvarWrites[#M.cvarWrites + 1] = { name, value }
	end
	_G.GetServerTime = function()
		return M.serverTime or 1700000000
	end
	_G.GetGameTime = function()
		return M.gameHour or 12, M.gameMinute or 0
	end
	_G.C_Timer = {
		After = function(seconds, fn)
			M.timers[#M.timers + 1] = { seconds = seconds, fn = fn }
		end,
	}
	_G.WorldFrame = newFrame("WorldFrame")
	_G.GetMouseFoci = function()
		return { M.mouseFocus or _G.WorldFrame }
	end
	installSettingsStub()
end

--- Builds a fresh ns, installs stubs, and loads the TOC Lua files.
--- opts.only: list of file names to load (default: every Lua file in the TOC).
--- opts.stubs: function called after the default stubs are set up.
function M.boot(opts)
	opts = opts or {}
	snapshot()
	M.installStubs()
	if opts.stubs then
		opts.stubs()
	end
	local ns = {}
	local wanted
	if opts.only then
		wanted = {}
		for _, name in ipairs(opts.only) do
			wanted[name] = true
		end
	end
	for _, name in ipairs(M.readToc()) do
		if name:match("%.lua$") and not name:match("^Libs/") and (not wanted or wanted[name]) then
			assert(loadfile(ADDON_DIR .. name))(ADDON_NAME, ns)
		end
	end
	return ns
end

function M.pin_locale(locale, before_each, after_each)
	before_each(function()
		M.locale = locale
	end)
	after_each(function()
		M.locale = nil
	end)
end

function M.fake_tooltip()
	local tt = { lines = {}, doubles = {} }
	function tt:AddLine(text, r, g, b)
		self.lines[#self.lines + 1] = { text = text, r = r, g = g, b = b }
	end
	function tt:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
		self.doubles[#self.doubles + 1] =
			{ left = left, right = right, lr = lr, lg = lg, lb = lb, rr = rr, rg = rg, rb = rb }
	end
	return tt
end

return M
