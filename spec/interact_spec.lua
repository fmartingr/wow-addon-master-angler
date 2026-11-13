local wow = require("spec.helpers.wow")

describe("Interact", function()
	local ns
	before_each(function()
		ns = wow.boot()
		_G.MasterAnglerDB = nil
		ns.InitDB()
		wow.knownSpells[7620] = true
		wow.worn[16] = wow.itemLink(6256)
		wow.itemInfo[6256] = { 2, 20 }
		wow.tempEnchant = { remainingTimeMs = 600000 }
		wow.bindings.INTERACTTARGET = { "F" }
		ns.Interact.RefreshKeys()
		ns.Interact.ClearOverride()
		wow.clearedOverrides = 0
		wow.clearedOwners = {}
	end)
	after_each(function()
		wow.restore()
	end)

	local function fire(event, ...)
		ns.events.scripts.OnEvent(ns.events, event, ...)
	end

	local function lineStart()
		fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid", 7620)
	end

	local function lineStop()
		fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "guid", 7620)
	end

	describe("Keys", function()
		it("returns up to two non-empty strings", function()
			wow.bindings.INTERACTTARGET = { "F", "BUTTON4" }
			assert.same({ "F", "BUTTON4" }, ns.Interact.Keys())
			wow.bindings.INTERACTTARGET = { "", "G" }
			assert.same({ "G" }, ns.Interact.Keys())
			wow.bindings.INTERACTTARGET = {}
			assert.same({}, ns.Interact.Keys())
		end)

		it("returns none when the API fails or gives a secret value", function()
			_G.GetBindingKey = function()
				error("boom")
			end
			assert.same({}, ns.Interact.Keys())
			local secret = wow.markSecret("F")
			_G.GetBindingKey = function()
				return secret
			end
			assert.same({}, ns.Interact.Keys())
		end)
	end)

	describe("Reason", function()
		local function reason()
			return ns.Interact.Reason(wow.now)
		end

		it("is nil when all conditions are clear", function()
			assert.is_nil(reason())
		end)

		it("returns each reason in the listed order", function()
			local frame = wow.newFrame("LootFrame")
			frame:Show()
			_G.LootFrame = frame
			assert.equals("window", reason())

			wow.units.softinteract = true
			assert.equals("soft-target", reason())

			lineStart()
			lineStop()
			assert.equals("line-in", reason())
			wow.now = wow.now + 1
			assert.equals("soft-target", reason())

			lineStart()
			assert.equals("line-out", reason())

			wow.knownSpells[7620] = nil
			assert.equals("no-spell", reason())

			wow.worn[16] = nil
			assert.equals("inactive", reason())

			wow.combat = true
			assert.equals("combat", reason())

			ns.Settings.Set("interactKey", false)
			assert.equals("off", reason())
		end)

		it("ignores a hidden busy frame", function()
			_G.LootFrame = wow.newFrame("LootFrame")
			assert.is_nil(reason())
		end)

		it("is clear again 1 second after the line comes in", function()
			lineStart()
			lineStop()
			wow.now = wow.now + 0.5
			assert.equals("line-in", reason())
			wow.now = wow.now + 0.5
			assert.is_nil(reason())
		end)

		it("is inactive with no pole in hand", function()
			wow.worn[16] = nil
			assert.equals("inactive", reason())
		end)
	end)

	describe("Update", function()
		it("sets an override for one key", function()
			ns.Interact.Update()
			assert.equals(1, #wow.overrides)
			local override = wow.overrides[1]
			assert.equals(ns.Interact.owner, override.owner)
			assert.is_false(override.priority)
			assert.equals("F", override.key)
			assert.equals("MasterAnglerCastButton", override.name)
		end)

		it("prepares the cast button before it sets the override", function()
			ns.Cast.button:SetAttribute("type", nil)
			ns.Interact.Update()
			assert.equals("spell", ns.Cast.button:GetAttribute("type"))
		end)

		it("sets no override when the cast button cannot be prepared", function()
			local prepare = ns.Cast.Prepare
			ns.Cast.Prepare = function()
				return false
			end
			ns.Interact.Update()
			ns.Cast.Prepare = prepare
			assert.equals(0, #wow.overrides)
		end)

		it("clears keys bound before a failed bind", function()
			wow.bindings.INTERACTTARGET = { "F", "BUTTON4" }
			local bind = _G.SetOverrideBindingClick
			_G.SetOverrideBindingClick = function(target, priority, key, name)
				if key == "BUTTON4" then
					error("bind failed")
				end
				bind(target, priority, key, name)
			end
			pcall(ns.Interact.RefreshKeys)
			_G.SetOverrideBindingClick = bind
			assert.equals(1, #wow.overrides)
			ns.Interact.ClearOverride()
			assert.equals(0, #wow.overrides)
		end)

		it("sets an override for two keys", function()
			wow.bindings.INTERACTTARGET = { "F", "BUTTON4" }
			ns.Interact.RefreshKeys()
			assert.equals(2, #wow.overrides)
		end)

		it("sets none with no key", function()
			wow.bindings.INTERACTTARGET = {}
			ns.Interact.RefreshKeys()
			assert.equals(0, #wow.overrides)
		end)

		it("does not set the override twice", function()
			ns.Interact.Update()
			ns.Interact.Update()
			assert.equals(1, #wow.overrides)
		end)

		it("does nothing in combat", function()
			wow.combat = true
			ns.Interact.Update()
			assert.equals(0, #wow.overrides)
			assert.equals(0, wow.clearedOverrides)
		end)

		it("clears the override when a reason appears", function()
			ns.Interact.Update()
			wow.units.softinteract = true
			ns.Interact.Update()
			assert.equals(0, #wow.overrides)
			wow.units.softinteract = nil
			ns.Interact.Update()
			assert.equals(1, #wow.overrides)
		end)

		it("does not clear when no override is on", function()
			wow.units.softinteract = true
			ns.Interact.Update()
			assert.equals(0, wow.clearedOverrides)
		end)

		it("clears the override when the setting goes off", function()
			ns.Interact.Update()
			ns.Settings.Set("interactKey", false)
			assert.equals(0, #wow.overrides)
		end)

		it("clears the override when the line goes out and sets it again after the quiet time", function()
			ns.Interact.Update()
			lineStart()
			assert.equals(0, #wow.overrides)
			lineStop()
			assert.equals(0, #wow.overrides)
			wow.now = wow.now + 1.1
			wow.runTimers()
			assert.equals(1, #wow.overrides)
		end)

		it("clears the override when the pole comes off", function()
			ns.Interact.Update()
			assert.equals(1, #wow.overrides)
			wow.worn[16] = nil
			fire("PLAYER_EQUIPMENT_CHANGED", 16)
			assert.equals(0, #wow.overrides)
		end)
	end)

	describe("events", function()
		it("PLAYER_REGEN_DISABLED clears the override", function()
			ns.Interact.Update()
			fire("PLAYER_REGEN_DISABLED")
			assert.equals(0, #wow.overrides)
		end)

		it("PLAYER_REGEN_DISABLED without an override does nothing", function()
			fire("PLAYER_REGEN_DISABLED")
			for _, cleared in ipairs(wow.clearedOwners) do
				assert.is_true(cleared ~= ns.Interact.owner)
			end
		end)

		it("PLAYER_REGEN_ENABLED sets the override again", function()
			ns.Interact.Update()
			fire("PLAYER_REGEN_DISABLED")
			assert.equals(0, #wow.overrides)
			wow.combat = false
			fire("PLAYER_REGEN_ENABLED")
			assert.equals(1, #wow.overrides)
		end)

		it("PLAYER_REGEN_ENABLED reads keys changed in combat", function()
			ns.Interact.Update()
			wow.combat = true
			wow.bindings.INTERACTTARGET = { "G" }
			fire("UPDATE_BINDINGS")
			wow.combat = false
			fire("PLAYER_REGEN_ENABLED")
			assert.equals(1, #wow.overrides)
			assert.equals("G", wow.overrides[1].key)
		end)

		it("keeps the override on UPDATE_BINDINGS with the same keys", function()
			ns.Interact.Update()
			wow.clearedOwners = {}
			fire("UPDATE_BINDINGS")
			assert.equals(1, #wow.overrides)
			for _, cleared in ipairs(wow.clearedOwners) do
				assert.is_true(cleared ~= ns.Interact.owner)
			end
		end)

		it("a hooked menu frame updates on show and hide", function()
			ns.Interact.Update()
			local menu = wow.newFrame("GameMenuFrame")
			_G.GameMenuFrame = menu
			fire("ADDON_LOADED", "Blizzard_Other")
			menu:Show()
			menu.hooks.OnShow(menu)
			assert.equals(0, #wow.overrides)
			menu:Hide()
			menu.hooks.OnHide(menu)
			assert.equals(1, #wow.overrides)
		end)

		it("reads the keys again after UPDATE_BINDINGS", function()
			ns.Interact.Update()
			wow.bindings.INTERACTTARGET = { "G" }
			fire("UPDATE_BINDINGS")
			assert.equals(1, #wow.overrides)
			assert.equals("G", wow.overrides[1].key)
		end)

		it("does not touch the override on UPDATE_BINDINGS in combat", function()
			ns.Interact.Update()
			wow.combat = true
			wow.bindings.INTERACTTARGET = { "G" }
			fire("UPDATE_BINDINGS")
			assert.equal("F", wow.overrides[1].key)
		end)

		it("a loot window clears the override and a closed one sets it again", function()
			ns.Interact.Update()
			_G.LootFrame = wow.newFrame("LootFrame")
			_G.LootFrame:Show()
			fire("LOOT_OPENED")
			assert.equals(0, #wow.overrides)
			_G.LootFrame:Hide()
			fire("LOOT_CLOSED")
			assert.equals(1, #wow.overrides)
		end)

		it("a frame that shows one tick later is caught by the timer", function()
			ns.Interact.Update()
			fire("LOOT_OPENED")
			_G.LootFrame = wow.newFrame("LootFrame")
			_G.LootFrame:Show()
			wow.runTimers()
			assert.equals(0, #wow.overrides)
		end)

		it("interaction manager and equipment events update", function()
			wow.worn[16] = nil
			fire("PLAYER_EQUIPMENT_CHANGED")
			assert.equals(0, #wow.overrides)
			wow.worn[16] = wow.itemLink(6256)
			fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
			assert.equals(1, #wow.overrides)
			_G.MerchantFrame = wow.newFrame("MerchantFrame")
			_G.MerchantFrame:Show()
			fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
			assert.equals(0, #wow.overrides)
		end)
	end)

	describe("soft target range", function()
		it("applies on line out and restores on line in", function()
			wow.cvars.SoftTargetInteractArc = "1"
			wow.cvars.SoftTargetInteractRange = "10"
			lineStart()
			assert.equals("2", wow.cvars.SoftTargetInteractArc)
			assert.equals("30", wow.cvars.SoftTargetInteractRange)
			lineStop()
			assert.equals("1", wow.cvars.SoftTargetInteractArc)
			assert.equals("10", wow.cvars.SoftTargetInteractRange)
			assert.is_nil(MasterAnglerDB.cvarBackup)
		end)

		it("applies the soft-interact CVars the reel needs", function()
			wow.cvars.SoftTargetInteract = "1"
			wow.cvars.SoftTargetInteractRangeIsHard = "1"
			wow.cvars.SoftTargetInteractRange = "5"
			wow.cvars.SoftTargetInteractArc = "0"
			lineStart()
			assert.equals("3", wow.cvars.SoftTargetInteract)
			assert.equals("0", wow.cvars.SoftTargetInteractRangeIsHard)
			assert.equals("30", wow.cvars.SoftTargetInteractRange)
			assert.equals("2", wow.cvars.SoftTargetInteractArc)
			lineStop()
			assert.equals("1", wow.cvars.SoftTargetInteract)
			assert.equals("1", wow.cvars.SoftTargetInteractRangeIsHard)
		end)

		it("restores at login after a crash with the line out", function()
			wow.cvars.SoftTargetInteractArc = "1"
			wow.cvars.SoftTargetInteractRange = "10"
			lineStart()
			ns.Cast.lineOut = false
			fire("PLAYER_LOGIN")
			assert.equals("1", wow.cvars.SoftTargetInteractArc)
			assert.is_nil(MasterAnglerDB.cvarBackup)
		end)

		it("keeps the soft-interact CVars at login while the live channel shows the line out", function()
			wow.cvars.SoftTargetInteractArc = "0"
			_G.UnitChannelInfo = function()
				return "Fishing"
			end
			fire("PLAYER_LOGIN")
			assert.is_true(ns.Cast.lineOut)
			assert.equals("2", wow.cvars.SoftTargetInteractArc)
			assert.is_not_nil(MasterAnglerDB.cvarBackup)
		end)

		it("sets the keys at login", function()
			ns.Interact.ClearOverride()
			fire("PLAYER_LOGIN")
			assert.equals(1, #wow.overrides)
		end)
	end)

	describe("soft target watch", function()
		it("uses the event when it exists", function()
			assert.is_true(ns.Interact.watchSoftTarget())
			assert.is_true(ns.Interact.owner.events.PLAYER_SOFT_INTERACT_CHANGED)
			ns.Interact.owner.scripts.OnEvent()
			assert.equals(1, #wow.overrides)
		end)

		it("falls back to a throttled OnUpdate when the event does not exist", function()
			local owner = ns.Interact.owner
			owner.RegisterEvent = function()
				error("unknown event")
			end
			assert.is_false(ns.Interact.watchSoftTarget())
			owner.scripts.OnUpdate(owner, 0.1)
			assert.equals(0, #wow.overrides)
			owner.scripts.OnUpdate(owner, 0.15)
			assert.equals(1, #wow.overrides)
		end)

		it("a failing update from the soft target event is reported once", function()
			ns.Interact.watchSoftTarget()
			_G.SetOverrideBindingClick = function()
				error("bind failed")
			end
			ns.Interact.owner.scripts.OnEvent()
			ns.Interact.ClearOverride()
			ns.Interact.owner.scripts.OnEvent()
			assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
		end)

		it("the OnUpdate fallback runs only while fishing is active", function()
			local owner = ns.Interact.owner
			owner.RegisterEvent = function()
				error("unknown event")
			end
			ns.Interact.watchSoftTarget()
			wow.worn[16] = nil
			owner.scripts.OnUpdate(owner, 1)
			assert.equals(0, #wow.overrides)
		end)
	end)
end)
