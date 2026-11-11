local _, ns = ...

ns.CVars = {}
local CVars = ns.CVars

local function backups()
	if type(MasterAnglerDB) ~= "table" then
		return nil
	end
	return MasterAnglerDB.cvarBackup
end

-- SetCVar returns false, without an error, when the client rejects a value.
local function setCVar(name, value)
	local ok, success = pcall(SetCVar, name, value)
	ok = ok and success ~= false
	if not ok then
		ns.ReportOnce("cvar-" .. name, string.format(ns.L.CVAR_FAILED, name))
	end
	return ok
end

local function hasEntries(tbl)
	return type(tbl) == "table" and next(tbl) ~= nil
end

local function prune(all, group)
	if not hasEntries(all[group]) then
		all[group] = nil
	end
	if next(all) == nil then
		MasterAnglerDB.cvarBackup = nil
	end
end

function CVars.HasBackup(group)
	local all = backups()
	return type(all) == "table" and hasEntries(all[group])
end

function CVars.Apply(group, values)
	if ns.readOnly or type(MasterAnglerDB) ~= "table" then
		return
	end
	if type(MasterAnglerDB.cvarBackup) ~= "table" then
		MasterAnglerDB.cvarBackup = {}
	end
	local all = MasterAnglerDB.cvarBackup
	if type(all[group]) ~= "table" then
		all[group] = {}
	end
	local saved = all[group]
	for name, value in pairs(values) do
		local current = ns.Safe(GetCVar, name)
		if saved[name] == nil then
			if current ~= nil then
				saved[name] = current
				if current ~= value and not setCVar(name, value) then
					saved[name] = nil
				end
			end
		elseif current ~= value then
			setCVar(name, value)
		end
	end
	prune(all, group)
end

-- A value the client rejects stays in the backup, so the next Restore retries it.
function CVars.Restore(group)
	local all = backups()
	if ns.readOnly or type(all) ~= "table" then
		return
	end
	local saved = all[group]
	if type(saved) == "table" then
		for name, value in pairs(saved) do
			if ns.Safe(GetCVar, name) == value or setCVar(name, value) then
				saved[name] = nil
			end
		end
	end
	prune(all, group)
end
