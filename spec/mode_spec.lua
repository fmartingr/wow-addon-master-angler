local wow = require("spec.helpers.wow")

local link = wow.itemLink

describe("Mode", function()
	local ns
	before_each(function()
		ns = wow.boot()
		_G.MasterAnglerDB = nil
		ns.InitDB()
		wow.worn[1] = link(100)
		wow.worn[16] = link(300)
		wow.worn[17] = link(400)
		ns.Gear.Save()
		_G.DEFAULT_CHAT_FRAME.lines = {}
		wow.worn = { [1] = link(101), [17] = link(400), [10] = link(900) }
		wow.equipCalls = {}
		ns.Char().gear[17] = false
	end)
	after_each(function()
		wow.restore()
	end)

	local function fireRegen()
		ns.events.scripts.OnEvent(ns.events, "PLAYER_REGEN_ENABLED")
	end

	it("toggle on stores previous and equips the set", function()
		ns.Mode.Toggle()
		local mode = ns.Char().mode
		assert.is_true(mode.on)
		assert.is_true(ns.Mode.IsOn())
		assert.equals(link(101), mode.previous[1])
		assert.is_false(mode.previous[16])
		assert.equals(link(100), wow.worn[1])
		assert.equals(link(300), wow.worn[16])
		assert.is_nil(wow.worn[17])
		assert.is_nil(wow.worn[10])
	end)

	it("toggle off restores the previous gear and clears previous", function()
		ns.Mode.Toggle()
		ns.Mode.Toggle()
		assert.is_false(ns.Mode.IsOn())
		assert.same({}, ns.Char().mode.previous)
		assert.equals(link(101), wow.worn[1])
		assert.is_nil(wow.worn[16])
		assert.equals(link(400), wow.worn[17])
		assert.equals(link(900), wow.worn[10])
	end)

	it("keeps the record of the old gear when the swap fails halfway", function()
		_G.C_Item.EquipItemByName = function()
			error("boom")
		end
		assert.has_error(function()
			ns.Mode.Toggle()
		end)
		assert.is_true(ns.Char().mode.on)
		assert.equals(link(101), ns.Char().mode.previous[1])
	end)

	it("keeps the mode on and the old gear record when the swap back fails", function()
		ns.Mode.Toggle()
		local seen = {}
		ns.Mode.Subscribe(function(isOn)
			seen[#seen + 1] = isOn
		end)
		_G.C_Item.EquipItemByName = function()
			error("boom")
		end
		assert.has_error(function()
			ns.Mode.Toggle()
		end)
		assert.is_true(ns.Mode.IsOn())
		assert.equals(link(101), ns.Char().mode.previous[1])
		assert.same({ true }, seen)
	end)

	it("notifies subscribers when the swap on fails halfway", function()
		local seen = {}
		ns.Mode.Subscribe(function(isOn)
			seen[#seen + 1] = isOn
		end)
		_G.C_Item.EquipItemByName = function()
			error("boom")
		end
		assert.has_error(function()
			ns.Mode.Toggle()
		end)
		assert.same({ true }, seen)
	end)

	it("treats a saved set with no items as no set", function()
		local empty = {}
		for _, slot in ipairs(ns.Gear.SLOTS) do
			empty[slot] = false
		end
		ns.Char().gear = empty
		ns.Mode.Toggle()
		assert.is_false(ns.Mode.IsOn())
		assert.is_truthy(_G.DEFAULT_CHAT_FRAME.lines[1]:find("No fishing set", 1, true))
		assert.is_nil(wow.puts[1])
	end)

	it("empties a slot that was empty before", function()
		wow.worn[16] = nil
		ns.Mode.Toggle()
		assert.equals(link(300), wow.worn[16])
		ns.Mode.Toggle()
		assert.is_nil(wow.worn[16])
	end)

	it("toggle with no set prints the message and stays off", function()
		ns.Char().gear = {}
		ns.Mode.Toggle()
		assert.is_false(ns.Mode.IsOn())
		assert.is_truthy(_G.DEFAULT_CHAT_FRAME.lines[1]:find("No fishing set", 1, true))
		assert.equals(0, #wow.equipCalls)
	end)

	it("toggle off works even when the saved set is empty", function()
		ns.Mode.Toggle()
		ns.Char().gear = {}
		ns.Mode.Toggle()
		assert.is_false(ns.Mode.IsOn())
	end)

	it("toggle in combat waits for PLAYER_REGEN_ENABLED and then runs once", function()
		wow.combat = true
		ns.Mode.Toggle()
		assert.is_false(ns.Mode.IsOn())
		assert.is_true(ns.Mode.IsPending())
		assert.equals(0, #wow.equipCalls)
		wow.combat = false
		fireRegen()
		assert.is_true(ns.Mode.IsOn())
		assert.is_false(ns.Mode.IsPending())
		local calls = #wow.equipCalls
		fireRegen()
		assert.equals(calls, #wow.equipCalls)
		assert.is_true(ns.Mode.IsOn())
	end)

	it("a second toggle in combat cancels the pending swap", function()
		wow.combat = true
		ns.Mode.Toggle()
		ns.Mode.Toggle()
		assert.is_false(ns.Mode.IsPending())
		wow.combat = false
		fireRegen()
		assert.is_false(ns.Mode.IsOn())
		assert.equals(0, #wow.equipCalls)
	end)

	it("regen without a pending swap does nothing", function()
		fireRegen()
		assert.is_false(ns.Mode.IsOn())
	end)

	it("subscribers get the new state, and a failing one is reported once", function()
		local seen = {}
		ns.Mode.Subscribe(function()
			error("boom")
		end)
		ns.Mode.Subscribe(function(isOn)
			seen[#seen + 1] = isOn
		end)
		ns.Mode.Toggle()
		ns.Mode.Toggle()
		assert.same({ true, false }, seen)
		local errors = 0
		for _, line in ipairs(_G.DEFAULT_CHAT_FRAME.lines) do
			if line:find("could not start", 1, true) then
				errors = errors + 1
			end
		end
		assert.equals(1, errors)
	end)

	it("persists the state in the character table", function()
		ns.Mode.Toggle()
		assert.is_true(_G.MasterAnglerDB.chars["Tester-Realm"].mode.on)
		assert.is_true(ns.Mode.IsOn())
	end)

	it("does nothing without a character or in read-only mode", function()
		ns.readOnly = true
		ns.Mode.Toggle()
		assert.equals(0, #wow.equipCalls)
		ns.readOnly = false
		wow.player.name = nil
		ns.Mode.Toggle()
		assert.is_false(ns.Mode.IsOn())
		assert.equals(0, #wow.equipCalls)
	end)

	it("is the mode command", function()
		_G.SlashCmdList.MASTERANGLER("mode")
		assert.is_true(ns.Mode.IsOn())
	end)

	it("toggle off with a lost record turns the mode off and keeps the worn gear", function()
		ns.Mode.Toggle()
		ns.Char().mode.previous = {}
		wow.puts = {}
		local worn = wow.worn[1]
		ns.Mode.Toggle()
		assert.is_false(ns.Mode.IsOn())
		assert.equals(worn, wow.worn[1])
		assert.equals(0, #wow.puts)
	end)

	it("a failing swap after combat prints the command failure", function()
		wow.combat = true
		ns.Mode.Toggle()
		wow.combat = false
		_G.C_Item.EquipItemByName = function()
			error("boom")
		end
		_G.DEFAULT_CHAT_FRAME.lines = {}
		fireRegen()
		assert.is_truthy(_G.DEFAULT_CHAT_FRAME.lines[1]:find("command failed", 1, true))
	end)

	it("saving while the mode is on keeps the previous gear", function()
		ns.Mode.Toggle()
		ns.Gear.Save()
		assert.equals(link(101), ns.Char().mode.previous[1])
	end)
end)
