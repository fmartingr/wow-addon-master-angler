local _, ns = ...

ns.Commands = {}
local Commands = ns.Commands

local entries = {}
local byName = {}

function Commands.Register(name, fn, helpKey)
	local lower = name:lower()
	local existing = byName[lower]
	if existing then
		existing.name, existing.fn, existing.helpKey = name, fn, helpKey
		return
	end
	local entry = { name = name, fn = fn, helpKey = helpKey }
	entries[#entries + 1] = entry
	byName[lower] = entry
end

function Commands.PrintHelp()
	local L = ns.L
	ns.Print(L.HELP_HEADER)
	for _, entry in ipairs(entries) do
		ns.Print(string.format("/masterangler %s - %s", entry.name, L[entry.helpKey]))
	end
end

function Commands.Dispatch(msg)
	local word, rest = tostring(msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	local entry = byName[word:lower()]
	if entry then
		if not pcall(entry.fn, rest) then
			ns.Print(ns.L.COMMAND_FAILED)
		end
	else
		Commands.PrintHelp()
	end
end

Commands.Register("help", Commands.PrintHelp, "HELP_HELP")

SLASH_MASTERANGLER1 = "/masterangler"
SlashCmdList["MASTERANGLER"] = Commands.Dispatch
