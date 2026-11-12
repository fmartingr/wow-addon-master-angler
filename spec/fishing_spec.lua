local wow = require("spec.helpers.wow")

describe("Fishing", function()
	local ns
	before_each(function()
		ns = wow.boot()
		_G.MasterAnglerDB = nil
		ns.InitDB()
	end)
	after_each(function()
		wow.restore()
	end)

	describe("SpellID", function()
		it("picks the highest known rank", function()
			wow.knownSpells[7620] = true
			assert.equals(7620, ns.Fishing.SpellID())
			wow.knownSpells[7732] = true
			assert.equals(7732, ns.Fishing.SpellID())
			wow.knownSpells[18248] = true
			assert.equals(18248, ns.Fishing.SpellID())
		end)

		it("returns nil when Fishing is not learned", function()
			assert.is_nil(ns.Fishing.SpellID())
		end)

		it("falls back to C_SpellBook.IsSpellKnown", function()
			_G.IsPlayerSpell = nil
			_G.C_SpellBook = {
				IsSpellKnown = function(id)
					return id == 7731
				end,
			}
			assert.equals(7731, ns.Fishing.SpellID())
		end)

		it("returns nil without any spell API", function()
			_G.IsPlayerSpell = nil
			_G.C_SpellBook = nil
			assert.is_nil(ns.Fishing.SpellID())
		end)

		it("knows the fishing spell IDs and any spell with the fishing name", function()
			assert.is_true(ns.Fishing.IsFishingSpell(7620))
			assert.is_false(ns.Fishing.IsFishingSpell(1))
			wow.spellNames[555] = "Fishing"
			assert.is_true(ns.Fishing.IsFishingSpell(555))
		end)

		it("SpellName works with GetSpellInfo and without any name API", function()
			_G.C_Spell = nil
			_G.GetSpellInfo = function()
				return "Pesca"
			end
			assert.equals("Pesca", ns.Fishing.SpellName(7620))
			_G.GetSpellInfo = nil
			assert.is_nil(ns.Fishing.SpellName(7620))
			assert.is_false(ns.Fishing.IsFishingSpell(555))
		end)
	end)

	describe("BestLure", function()
		it("returns the strongest lure in the bags", function()
			wow.itemCounts = setmetatable({ [6529] = 3, [6530] = 1, [6533] = 0 }, {
				__index = function()
					return 0
				end,
			})
			assert.equals(6530, ns.Fishing.BestLure())
			wow.itemCounts[6533] = 1
			assert.equals(6533, ns.Fishing.BestLure())
		end)

		it("skips a lure the player cannot use yet", function()
			wow.itemCounts = setmetatable({ [6533] = 1, [6530] = 1 }, {
				__index = function()
					return 0
				end,
			})
			_G.C_Item.IsUsableItem = function(id)
				return id ~= 6533
			end
			assert.equals(6530, ns.Fishing.BestLure())
		end)

		it("returns nil with no lure", function()
			wow.itemCounts = setmetatable({}, {
				__index = function()
					return 0
				end,
			})
			assert.is_nil(ns.Fishing.BestLure())
		end)
	end)

	describe("PoleEquipped", function()
		it("is true for a fishing pole in the main hand", function()
			wow.worn[16] = wow.itemLink(6256)
			wow.itemInfo[6256] = { 2, 20 }
			assert.is_true(ns.Fishing.PoleEquipped())
		end)

		it("is false for another weapon, another class and an empty hand", function()
			assert.is_false(ns.Fishing.PoleEquipped())
			wow.worn[16] = wow.itemLink(1)
			wow.itemInfo[1] = { 2, 7 }
			assert.is_false(ns.Fishing.PoleEquipped())
			wow.itemInfo[1] = { 4, 20 }
			assert.is_false(ns.Fishing.PoleEquipped())
		end)

		it("is false when the item data is not loaded", function()
			wow.worn[16] = wow.itemLink(2)
			assert.is_false(ns.Fishing.PoleEquipped())
		end)

		it("uses 20 when the enum is missing", function()
			_G.Enum = {}
			wow.worn[16] = wow.itemLink(6256)
			wow.itemInfo[6256] = { 2, 20 }
			assert.is_true(ns.Fishing.PoleEquipped())
		end)
	end)

	describe("LureSecondsLeft", function()
		it("uses the C_ API", function()
			wow.tempEnchant = { enchantID = 1, remainingTimeMs = 45000, hasExpirationTime = true }
			assert.equals(45, ns.Fishing.LureSecondsLeft())
		end)

		it("returns 0 when there is no enchant", function()
			wow.tempEnchant = nil
			assert.equals(0, ns.Fishing.LureSecondsLeft())
			wow.tempEnchant = { enchantID = 1 }
			assert.equals(0, ns.Fishing.LureSecondsLeft())
		end)

		describe("with the global fallback", function()
			before_each(function()
				_G.C_PaperDollInfo = nil
			end)

			it("reads milliseconds above 3600", function()
				_G.GetWeaponEnchantInfo = function()
					return true, 120000, 0, 1
				end
				assert.equals(120, ns.Fishing.LureSecondsLeft())
			end)

			it("reads seconds at or below 3600", function()
				_G.GetWeaponEnchantInfo = function()
					return true, 90, 0, 1
				end
				assert.equals(90, ns.Fishing.LureSecondsLeft())
			end)

			it("returns 0 without a main-hand enchant", function()
				_G.GetWeaponEnchantInfo = function()
					return false
				end
				assert.equals(0, ns.Fishing.LureSecondsLeft())
				_G.GetWeaponEnchantInfo = function()
					return true, nil
				end
				assert.equals(0, ns.Fishing.LureSecondsLeft())
			end)

			it("returns nil with no API", function()
				_G.GetWeaponEnchantInfo = nil
				assert.is_nil(ns.Fishing.LureSecondsLeft())
			end)

			it("returns nil when the global fails or returns a secret value", function()
				_G.GetWeaponEnchantInfo = function()
					error("boom")
				end
				assert.is_nil(ns.Fishing.LureSecondsLeft())
				local secret = wow.markSecret(120000)
				_G.GetWeaponEnchantInfo = function()
					return true, secret
				end
				assert.is_nil(ns.Fishing.LureSecondsLeft())
			end)
		end)

		it("falls back when the C_ API fails or returns a secret value", function()
			_G.GetWeaponEnchantInfo = function()
				return true, 50, 0, 1
			end
			_G.C_PaperDollInfo.GetTemporaryEnchantmentInfo = function()
				error("boom")
			end
			assert.equals(50, ns.Fishing.LureSecondsLeft())
			local secret = wow.markSecret({})
			_G.C_PaperDollInfo.GetTemporaryEnchantmentInfo = function()
				return secret
			end
			assert.equals(50, ns.Fishing.LureSecondsLeft())
			local secretMs = wow.markSecret(777)
			_G.C_PaperDollInfo.GetTemporaryEnchantmentInfo = function()
				return { remainingTimeMs = secretMs }
			end
			assert.equals(50, ns.Fishing.LureSecondsLeft())
		end)

		it("falls back when the C_ function is missing", function()
			_G.C_PaperDollInfo = {}
			_G.GetWeaponEnchantInfo = function()
				return true, 70, 0, 1
			end
			assert.equals(70, ns.Fishing.LureSecondsLeft())
		end)
	end)

	describe("NeedsLure", function()
		local function setup(opts)
			wow.itemCounts = setmetatable({ [6533] = opts.lure and 1 or 0 }, {
				__index = function()
					return 0
				end,
			})
			wow.tempEnchant = opts.seconds and { remainingTimeMs = opts.seconds * 1000 } or nil
			ns.Settings.Set("autoLure", opts.setting ~= false)
			wow.worn[16] = opts.pole ~= false and wow.itemLink(6256) or nil
			wow.itemInfo[6256] = { 2, 20 }
		end

		it("is true with the setting on, a lure and less than 30 seconds left", function()
			setup({ lure = true, seconds = 29 })
			assert.is_true(ns.Fishing.NeedsLure())
			setup({ lure = true })
			assert.is_true(ns.Fishing.NeedsLure())
		end)

		it("is false with 30 seconds or more left", function()
			setup({ lure = true, seconds = 30 })
			assert.is_false(ns.Fishing.NeedsLure())
		end)

		it("is false with no lure in the bags", function()
			setup({ lure = false, seconds = 0 })
			assert.is_false(ns.Fishing.NeedsLure())
		end)

		it("is false with the setting off", function()
			setup({ lure = true, setting = false })
			assert.is_false(ns.Fishing.NeedsLure())
		end)

		it("is false with no pole in the main hand", function()
			setup({ lure = true, pole = false })
			assert.is_false(ns.Fishing.NeedsLure())
		end)

		it("is false for 8 seconds after a lure use, even when the pole shows no lure yet", function()
			setup({ lure = true })
			assert.is_true(ns.Fishing.NeedsLure())
			ns.Fishing.NoteLureUse()
			assert.is_false(ns.Fishing.NeedsLure())
			wow.now = wow.now + 7.9
			assert.is_false(ns.Fishing.NeedsLure())
			wow.now = wow.now + 0.2
			assert.is_true(ns.Fishing.NeedsLure())
		end)

		it("is false when the time left is unknown", function()
			setup({ lure = true })
			_G.C_PaperDollInfo = nil
			_G.GetWeaponEnchantInfo = nil
			assert.is_false(ns.Fishing.NeedsLure())
		end)
	end)

	describe("Active", function()
		it("is true with the mode on or a pole in hand", function()
			assert.is_false(ns.Fishing.Active())
			wow.worn[16] = wow.itemLink(6256)
			wow.itemInfo[6256] = { 2, 20 }
			assert.is_true(ns.Fishing.Active())
			wow.worn[16] = nil
			ns.Char().mode.on = true
			assert.is_true(ns.Fishing.Active())
		end)
	end)
end)
