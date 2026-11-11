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
		it("sets the override for two clicks in the window", function()
			rightDown(100)
			assert.equals(0, #wow.overrides)
			rightDown(100.2)
			assert.equals(1, #wow.overrides)
			local override = wow.overrides[1]
			assert.equals(button, override.owner)
			assert.is_true(override.priority)
			assert.equals("BUTTON2", override.key)
			assert.equals("MasterAnglerCastButton", override.name)
			assert.equals("spell", button:GetAttribute("type"))
		end)

		it("stops the camera turn that the second press started", function()
			rightDown(100)
			wow.mouselooking = true
			rightDown(100.2)
			assert.is_false(wow.mouselooking)
		end)

		it("prepares the lure when one is needed", function()
			needLure()
			rightDown(100)
			rightDown(100.2)
			assert.equals("item", button:GetAttribute("type"))
		end)

		it("ignores other buttons", function()
			wow.now = 100
			fire("GLOBAL_MOUSE_DOWN", "LeftButton")
			wow.now = 100.2
			fire("GLOBAL_MOUSE_DOWN", "LeftButton")
			assert.equals(0, #wow.overrides)
		end)

		it("does not set the override outside the window", function()
			rightDown(100)
			rightDown(100.01)
			assert.equals(0, #wow.overrides)
			rightDown(101)
			assert.equals(0, #wow.overrides)
		end)

		it("does not set the override on UI, with a mouseover unit, or in combat", function()
			wow.mouseFocus = {}
			rightDown(100)
			rightDown(100.2)
			assert.equals(0, #wow.overrides)
			wow.mouseFocus = nil

			wow.units.mouseover = true
			rightDown(200)
			rightDown(200.2)
			assert.equals(0, #wow.overrides)
			wow.units.mouseover = nil

			wow.combat = true
			rightDown(300)
			rightDown(300.2)
			assert.equals(0, #wow.overrides)
		end)

		it("does nothing with the setting off", function()
			ns.Settings.Set("doubleClick", false)
			rightDown(100)
			rightDown(100.2)
			assert.equals(0, #wow.overrides)
		end)

		it("does nothing with no pole and the mode off", function()
			wow.worn[16] = nil
			rightDown(100)
			rightDown(100.2)
			assert.equals(0, #wow.overrides)
		end)

		it("works with the mode on and no pole", function()
			wow.worn[16] = nil
			ns.Char().mode.on = true
			rightDown(100)
			rightDown(100.2)
			assert.equals(1, #wow.overrides)
		end)

		it("does nothing when Fishing is not learned", function()
			wow.knownSpells[7620] = nil
			rightDown(100)
			rightDown(100.2)
			assert.equals(0, #wow.overrides)
		end)

		it("does nothing while the line is out", function()
			ns.Cast.lineOut = true
			rightDown(100)
			rightDown(100.2)
			assert.equals(0, #wow.overrides)
			ns.Cast.lineOut = false
		end)

		it("does not fire again on a triple click", function()
			rightDown(100)
			rightDown(100.2)
			rightDown(100.4)
			assert.equals(1, #wow.overrides)
		end)

		it("does not pair the second press of a refused double click with a third", function()
			wow.mouseFocus = {}
			rightDown(100)
			rightDown(100.2)
			wow.mouseFocus = nil
			rightDown(100.35)
			assert.equals(0, #wow.overrides)
		end)

		it("works when GetMouseFoci fails", function()
			_G.GetMouseFoci = function()
				error("boom")
			end
			rightDown(100)
			rightDown(100.2)
			assert.equals(0, #wow.overrides)
		end)
	end)

	describe("clearing the override", function()
		local function setOverride()
			rightDown(100)
			rightDown(100.2)
			assert.equals(1, #wow.overrides)
		end

		it("PostClick clears it and prepares the next action", function()
			needLure()
			setOverride()
			wow.itemCounts[6533] = 0
			button.scripts.PostClick(button, "RightButton", true)
			assert.equals(1, #wow.overrides)
			button.scripts.PostClick(button, "RightButton", false)
			assert.equals(0, #wow.overrides)
			assert.equals("spell", button:GetAttribute("type"))
		end)

		it("PreClick on the up picks a lure that became needed after Prepare", function()
			assert.is_true(ns.Cast.Prepare())
			needLure()
			button.scripts.PreClick(button, "LeftButton", true)
			assert.equals("spell", button:GetAttribute("type"))
			button.scripts.PreClick(button, "LeftButton", false)
			assert.equals("item", button:GetAttribute("type"))
		end)

		it("PLAYER_REGEN_DISABLED clears it", function()
			setOverride()
			fire("PLAYER_REGEN_DISABLED")
			assert.equals(0, #wow.overrides)
		end)

		it("the 1 second timer clears it", function()
			setOverride()
			assert.equals(1, wow.timers[1].seconds)
			wow.runTimers()
			assert.equals(0, #wow.overrides)
		end)

		it("a timer from an earlier override leaves a newer one on", function()
			setOverride()
			button.scripts.PostClick(button, "RightButton", false)
			rightDown(100.6)
			rightDown(100.8)
			assert.equals(1, #wow.overrides)
			wow.timers[1].fn()
			assert.equals(1, #wow.overrides)
			wow.timers[2].fn()
			assert.equals(0, #wow.overrides)
		end)

		it("does not touch the bindings in combat", function()
			setOverride()
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
