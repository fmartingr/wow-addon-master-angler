local _, ns = ...

ns.Settings = {}
local Settings_ = ns.Settings

local toggles = {}
local toggleByKey = {}
local listeners = {}
local category

local function defaultFor(key)
	local toggle = toggleByKey[key]
	return toggle and toggle.default
end

local function store()
	if type(MasterAnglerDB) == "table" and type(MasterAnglerDB.settings) == "table" then
		return MasterAnglerDB.settings
	end
	return nil
end

local sessionStore

-- In read-only mode the panel binds to a session copy so the game never writes into a newer DB.
local function panelStore()
	local settings = store()
	if not ns.readOnly then
		return settings
	end
	if not sessionStore then
		sessionStore = {}
		for key, value in pairs(settings or {}) do
			sessionStore[key] = value
		end
	end
	return sessionStore
end

local function fillDefault(settings, toggle)
	if type(settings[toggle.key]) ~= "boolean" then
		settings[toggle.key] = toggle.default
	end
end

local function notify(key, value)
	for _, fn in ipairs(listeners[key] or {}) do
		if not pcall(fn, value) then
			ns.ReportOnce("listener-" .. key, ns.L.HOOK_FAILED)
		end
	end
end

local function createCheckbox(toggle)
	local settings = panelStore()
	if not category or not settings then
		return
	end
	if ns.readOnly then
		fillDefault(settings, toggle)
	end
	local L = ns.L
	local ok = pcall(function()
		local setting = Settings.RegisterAddOnSetting(
			category,
			"MasterAngler_" .. toggle.key,
			toggle.key,
			settings,
			Settings.VarType.Boolean,
			L[toggle.labelKey],
			toggle.default
		)
		if setting and setting.SetValueChangedCallback then
			setting:SetValueChangedCallback(function(_, value)
				notify(toggle.key, value)
			end)
		end
		Settings.CreateCheckbox(category, setting, L[toggle.tooltipKey])
	end)
	if not ok then
		ns.ReportOnce("settings-checkbox", ns.L.SETTINGS_UNAVAILABLE)
	end
end

function Settings_.AddToggle(key, labelKey, tooltipKey, default)
	local toggle = toggleByKey[key]
	local isNew = toggle == nil
	if isNew then
		toggle = { key = key }
		toggles[#toggles + 1] = toggle
		toggleByKey[key] = toggle
	end
	toggle.labelKey, toggle.tooltipKey, toggle.default = labelKey, tooltipKey, default
	local settings = store()
	if settings and not ns.readOnly then
		fillDefault(settings, toggle)
	end
	if isNew and category then
		createCheckbox(toggle)
	end
end

function Settings_.ApplyDefaults()
	local settings = store()
	if not settings then
		return
	end
	for _, toggle in ipairs(toggles) do
		fillDefault(settings, toggle)
	end
end

function Settings_.Get(key)
	local settings = panelStore()
	local value = settings and settings[key]
	if value == nil then
		value = defaultFor(key)
	end
	return value == true
end

function Settings_.Set(key, value)
	local settings = store()
	if not settings or ns.readOnly then
		return
	end
	settings[key] = value and true or false
	notify(key, settings[key])
end

function Settings_.OnChange(key, fn)
	listeners[key] = listeners[key] or {}
	table.insert(listeners[key], fn)
end

function Settings_.Init()
	if
		type(Settings) ~= "table"
		or not Settings.RegisterVerticalLayoutCategory
		or not Settings.RegisterAddOnCategory
	then
		ns.ReportOnce("settings-missing", ns.L.SETTINGS_UNAVAILABLE)
		return false
	end
	local ok = pcall(function()
		category = Settings.RegisterVerticalLayoutCategory(ns.L.TITLE)
	end)
	if not ok or not category then
		category = nil
		ns.ReportOnce("settings-missing", ns.L.SETTINGS_UNAVAILABLE)
		return false
	end
	for _, toggle in ipairs(toggles) do
		createCheckbox(toggle)
	end
	if not pcall(Settings.RegisterAddOnCategory, category) then
		category = nil
		ns.ReportOnce("settings-missing", ns.L.SETTINGS_UNAVAILABLE)
		return false
	end
	return true
end

function Settings_.Category()
	return category
end

table.insert(ns.startup, Settings_.Init)
