local ADDON_NAME, ns = ...

ns.PRINT_HEX = "ff33aaff"
ns.DB_VERSION = 1
ns.readOnly = false

local DEFAULTS = {
	minimap = { hide = false },
	settings = {},
	chars = {},
}

local CHAR_DEFAULTS = {
	catches = {},
}

local reported = {}
local handlers = {}

local function fillDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			fillDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

function ns.Print(msg)
	local text = string.format("|c%s%s|r: %s", ns.PRINT_HEX, ADDON_NAME, tostring(msg))
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(text)
	end
end

function ns.ReportOnce(key, msg)
	if reported[key] then
		return false
	end
	reported[key] = true
	ns.Print(msg)
	return true
end

local function isSecret(value)
	return type(issecretvalue) == "function" and issecretvalue(value) == true
end
ns.IsSecret = isSecret

local function finishSafe(ok, ...)
	if not ok then
		return nil
	end
	for i = 1, select("#", ...) do
		if isSecret((select(i, ...))) then
			return nil
		end
	end
	return ...
end

function ns.Safe(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	return finishSafe(pcall(fn, ...))
end

function ns.InitDB()
	if type(MasterAnglerDB) ~= "table" then
		MasterAnglerDB = {}
	end
	if type(MasterAnglerDB.version) == "number" and MasterAnglerDB.version > ns.DB_VERSION then
		ns.readOnly = true
		ns.ReportOnce("db-newer", ns.L.DB_NEWER)
		return
	end
	ns.readOnly = false
	if type(MasterAnglerDB.version) ~= "number" then
		MasterAnglerDB.version = ns.DB_VERSION
	end
	fillDefaults(MasterAnglerDB, DEFAULTS)
	if ns.Settings then
		ns.Settings.ApplyDefaults()
	end
end

function ns.CharKey()
	local name = UnitName and UnitName("player")
	local realm = GetNormalizedRealmName and GetNormalizedRealmName()
	if type(name) ~= "string" or type(realm) ~= "string" or isSecret(name) or isSecret(realm) then
		return nil
	end
	if name == "" or realm == "" then
		return nil
	end
	return name .. "-" .. realm
end

function ns.Char()
	local key = ns.CharKey()
	-- A newer schema can have any shape, so read-only mode exposes no character data.
	if not key or ns.readOnly or type(MasterAnglerDB) ~= "table" then
		return nil
	end
	if type(MasterAnglerDB.chars) ~= "table" then
		MasterAnglerDB.chars = {}
	end
	local char = MasterAnglerDB.chars[key]
	if type(char) ~= "table" then
		char = {}
		MasterAnglerDB.chars[key] = char
	end
	fillDefaults(char, CHAR_DEFAULTS)
	return char
end

ns.events = CreateFrame("Frame")

function ns.On(event, handler)
	if not handlers[event] then
		handlers[event] = {}
		if not pcall(ns.events.RegisterEvent, ns.events, event) then
			ns.ReportOnce("event-" .. event, ns.L.HOOK_FAILED)
		end
	end
	table.insert(handlers[event], handler)
end

local function dispatch(event, ...)
	local list = handlers[event]
	if not list then
		return
	end
	for i = 1, #list do
		local ok = pcall(list[i], event, ...)
		if not ok then
			ns.ReportOnce("handler-" .. event, ns.L.HOOK_FAILED)
		end
	end
end

ns.startup = {}

function ns.OnLogin()
	for _, fn in ipairs(ns.startup) do
		local ok = pcall(fn)
		if not ok then
			ns.ReportOnce("startup", ns.L.HOOK_FAILED)
		end
	end
end

ns.events:RegisterEvent("ADDON_LOADED")
ns.events:RegisterEvent("PLAYER_LOGIN")
ns.events:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" and (...) == ADDON_NAME then
		ns.InitDB()
	elseif event == "PLAYER_LOGIN" then
		ns.OnLogin()
	end
	dispatch(event, ...)
end)
