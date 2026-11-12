local wow = require("spec.helpers.wow")

describe("Cast", function()
	local ns, button
	before_each(function()
		ns = wow.boot()
		_G.MasterAnglerDB = nil
		ns.InitDB()
		button = ns.Cast.button
		wow.knownSpells[7620] = true
		wow.itemCounts = setmetatable({}, {
			__index = function()
				return 0
			end,
		})
		wow.worn[16] = wow.itemLink(6256)
		wow.itemInfo[6256] = { 2, 20 }
		wow.tempEnchant = { remainingTimeMs = 600000 }
	end)
	after_each(function()
		wow.restore()
	end)

	local function fire(event, ...)
		ns.events.scripts.OnEvent(ns.events, event, ...)
	end

	local function rightDown(at)
		wow.now = at
		fire("GLOBAL_MOUSE_DOWN", "RightButton")
	end

	local function rightUp(at)
		wow.now = at
		fire("GLOBAL_MOUSE_UP", "RightButton")
	end

	local function click(downAt, upAt)
		rightDown(downAt)
		rightUp(upAt)
	end

	local function needLure()
		wow.itemCounts[6533] = 2
		wow.tempEnchant = nil
	end

	it("creates the secure button and hides it", function()
		assert.equals("MasterAnglerCastButton", button:GetName())
		assert.is_false(button:IsShown())
		local registered
		for _, call in ipairs(button.calls) do
			if call[1] == "RegisterForClicks" then
				registered = call
			end
		end
		assert.same({ "RegisterForClicks", "AnyUp", "AnyDown" }, registered)
		assert.is_false(button:GetAttribute("useOnKeyDown"))
	end)

	it("waits for the end of combat to set up the button after a reload in combat", function()
		wow.restore()
		ns = wow.boot({
			stubs = function()
				wow.combat = true
			end,
		})
		_G.MasterAnglerDB = nil
		ns.InitDB()
		button = ns.Cast.button
		wow.knownSpells[7620] = true
		for _, call in ipairs(button.calls) do
			assert.is_not.equals("RegisterForClicks", call[1])
			assert.is_not.equals("SetAttribute", call[1])
		end
		wow.combat = false
		fire("PLAYER_REGEN_ENABLED")
		assert.is_false(button:GetAttribute("useOnKeyDown"))
		assert.equals("spell", button:GetAttribute("type"))
	end)

	describe("Prepare", function()
		it("sets spell attributes when no lure is needed", function()
			assert.is_true(ns.Cast.Prepare())
			assert.equals("spell", button:GetAttribute("type"))
			assert.equals(7620, button:GetAttribute("spell"))
			assert.is_nil(button:GetAttribute("item"))
		end)

		it("sets lure attributes when a lure is needed, then switches back", function()
			needLure()
			assert.is_true(ns.Cast.Prepare())
			assert.equals("item", button:GetAttribute("type"))
			assert.equals("item:6533", button:GetAttribute("item"))
			assert.equals(16, button:GetAttribute("target-slot"))
			assert.is_nil(button:GetAttribute("spell"))
			wow.tempEnchant = { remainingTimeMs = 600000 }
			ns.Cast.Prepare()
			assert.equals("spell", button:GetAttribute("type"))
			assert.is_nil(button:GetAttribute("target-slot"))
		end)

		it("clears the type and returns false with no known spell", function()
			ns.Cast.Prepare()
			wow.knownSpells[7620] = nil
			assert.is_false(ns.Cast.Prepare())
			assert.is_nil(button:GetAttribute("type"))
		end)

		it("does nothing in combat", function()
			wow.combat = true
			assert.is_false(ns.Cast.Prepare())
			assert.is_nil(button:GetAttribute("type"))
		end)

		it("runs on the refresh events, a mode change and at login", function()
			for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED" }) do
				button:SetAttribute("type", nil)
				fire(event)
				assert.equals("spell", button:GetAttribute("type"), event)
			end
			button:SetAttribute("type", nil)
			fire("UNIT_INVENTORY_CHANGED", "target")
			assert.is_nil(button:GetAttribute("type"))
			fire("UNIT_INVENTORY_CHANGED", "player")
			assert.equals("spell", button:GetAttribute("type"))
			button:SetAttribute("type", nil)
			fire("PLAYER_LOGIN")
			assert.equals("spell", button:GetAttribute("type"))
			button:SetAttribute("type", nil)
			ns.Char().gear = { [1] = wow.itemLink(5) }
			ns.Mode.Toggle()
			assert.equals("spell", button:GetAttribute("type"))
		end)
	end)

	describe("double click", function()
		it("arms the cast by spell name after a quick first click, before the second press", function()
			click(100, 100.1)
			assert.equals(1, #wow.overrides)
			local override = wow.overrides[1]
			assert.equals(button, override.owner)
			assert.is_true(override.priority)
			assert.equals("BUTTON2", override.key)
			assert.equals("spell", override.kind)
			assert.equals("Fishing", override.name)
			assert.is_true(ns.Cast.WindowOpen())
		end)

		it("falls back to a click on the button when the spell name is unknown", function()
			_G.C_Spell = nil
			_G.GetSpellInfo = function() end
			click(100, 100.1)
			assert.equals("click", wow.overrides[1].kind)
			assert.equals("MasterAnglerCastButton", wow.overrides[1].name)
		end)

		it("arms the lure click when a lure is needed", function()
			needLure()
			click(100, 100.1)
			assert.equals("item", button:GetAttribute("type"))
			assert.equals("click", wow.overrides[1].kind)
			assert.equals("MasterAnglerCastButton", wow.overrides[1].name)
		end)

		it("arms the reel (Interact action) while the line is out", function()
			fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 7620)
			click(100, 100.1)
			assert.equals("command", wow.overrides[1].kind)
			assert.equals("INTERACTTARGET", wow.overrides[1].name)
		end)

		it("does not arm after a long press (a camera turn)", function()
			click(100, 100.5)
			assert.equals(0, #wow.overrides)
		end)

		it("ignores other buttons", function()
			wow.now = 100
			fire("GLOBAL_MOUSE_DOWN", "LeftButton")
			wow.now = 100.1
			fire("GLOBAL_MOUSE_UP", "LeftButton")
			assert.equals(0, #wow.overrides)
		end)

		it("does not arm on UI, with a mouseover unit, or in combat", function()
			wow.mouseFocus = {}
			click(100, 100.1)
			assert.equals(0, #wow.overrides)
			wow.mouseFocus = nil

			wow.units.mouseover = true
			click(200, 200.1)
			assert.equals(0, #wow.overrides)
			wow.units.mouseover = nil

			wow.combat = true
			click(300, 300.1)
			assert.equals(0, #wow.overrides)
		end)

		it("does not arm when the mouse leaves the world during the click", function()
			rightDown(100)
			wow.mouseFocus = {}
			rightUp(100.1)
			assert.equals(0, #wow.overrides)
		end)

		it("does nothing with the setting off", function()
			ns.Settings.Set("doubleClick", false)
			click(100, 100.1)
			assert.equals(0, #wow.overrides)
		end)

		it("does nothing with no pole and the mode off, and works with the mode on", function()
			wow.worn[16] = nil
			click(100, 100.1)
			assert.equals(0, #wow.overrides)
			ns.Char().mode.on = true
			click(200, 200.1)
			assert.equals(1, #wow.overrides)
		end)

		it("does nothing when Fishing is not learned", function()
			wow.knownSpells[7620] = nil
			click(100, 100.1)
			assert.equals(0, #wow.overrides)
		end)

		it("an up without a matching down does nothing", function()
			rightUp(100)
			assert.equals(0, #wow.overrides)
		end)
	end)

	describe("closing the window", function()
		local function open()
			click(100, 100.1)
			assert.equals(1, #wow.overrides)
		end

		it("closes at the end of the second press", function()
			open()
			rightDown(100.3)
			assert.equals(1, #wow.overrides)
			rightUp(100.4)
			assert.equals(0, #wow.overrides)
			assert.is_false(ns.Cast.WindowOpen())
		end)

		it("closes by timer when no second press comes", function()
			open()
			wow.runTimers()
			assert.equals(0, #wow.overrides)
		end)

		it("keeps the binding while the second press is held past the window", function()
			open()
			rightDown(100.35)
			wow.timers[1].fn()
			assert.is_true(ns.Cast.WindowOpen())
		end)

		it("a stuck press is closed by the safety timer", function()
			open()
			rightDown(100.35)
			local first = wow.timers[1]
			local second = wow.timers[2]
			first.fn()
			assert.is_true(ns.Cast.WindowOpen())
			second.fn()
			assert.is_false(ns.Cast.WindowOpen())
			assert.equals(0, #wow.overrides)
		end)

		it("a timer of an old window does not close a newer one", function()
			open()
			local stale = wow.timers
			wow.timers = {}
			rightDown(100.3)
			rightUp(100.4)
			click(200, 200.1)
			for _, timer in ipairs(stale) do
				timer.fn()
			end
			assert.is_true(ns.Cast.WindowOpen())
		end)

		it("a third click after the second does not arm again", function()
			open()
			rightDown(100.3)
			rightUp(100.4)
			assert.equals(0, #wow.overrides)
			rightDown(100.5)
			assert.equals(0, #wow.overrides)
		end)

		it("PLAYER_REGEN_DISABLED closes it", function()
			open()
			fire("PLAYER_REGEN_DISABLED")
			assert.equals(0, #wow.overrides)
			assert.is_false(ns.Cast.WindowOpen())
		end)

		it("PostClick on the up closes it, notes a lure use and prepares the next action", function()
			needLure()
			click(100, 100.1)
			button.scripts.PostClick(button, "LeftButton", true)
			assert.equals(1, #wow.overrides)
			button.scripts.PostClick(button, "LeftButton", false)
			assert.equals(0, #wow.overrides)
			assert.equals("spell", button:GetAttribute("type"))
		end)

		it("does not touch the bindings in combat", function()
			open()
			wow.combat = true
			assert.is_false(ns.Cast.ClearOverride())
			assert.equals(1, #wow.overrides)
		end)
	end)

	describe("line state", function()
		it("sets and clears lineOut for the player's fishing spell and notifies once", function()
			local seen = {}
			ns.Cast.Subscribe(function(out)
				seen[#seen + 1] = out
			end)
			fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 7620)
			fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 7620)
			assert.is_true(ns.Cast.lineOut)
			fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "guid", 7620)
			assert.is_false(ns.Cast.lineOut)
			assert.same({ true, false }, seen)
		end)

		it("ignores other units and other spells", function()
			fire("UNIT_SPELLCAST_CHANNEL_START", "target", "guid", 7620)
			fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 1)
			assert.is_false(ns.Cast.lineOut)
		end)

		it("leaves the state unchanged for a secret spell ID or unit", function()
			fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 7620)
			fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "guid", wow.markSecret(7620))
			assert.is_true(ns.Cast.lineOut)
			fire("UNIT_SPELLCAST_CHANNEL_STOP", wow.markSecret("player"), "guid", 7620)
			assert.is_true(ns.Cast.lineOut)
		end)

		it("reads a fishing channel already running at login", function()
			_G.UnitChannelInfo = function()
				return "Fishing", "", 0, 0, 0, false, false, 7620
			end
			fire("PLAYER_LOGIN")
			assert.is_true(ns.Cast.lineOut)
			_G.UnitChannelInfo = function()
				return "Other", "", 0, 0, 0, false, false, 1
			end
			ns.Cast.SyncLine()
			assert.is_false(ns.Cast.lineOut)
			_G.UnitChannelInfo = function() end
			ns.Cast.SyncLine()
			assert.is_false(ns.Cast.lineOut)
		end)

		it("a failing subscriber is reported once", function()
			ns.Cast.Subscribe(function()
				error("boom")
			end)
			fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 7620)
			fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "guid", 7620)
			assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
		end)
	end)
end)
