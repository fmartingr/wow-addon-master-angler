local wow = require("spec.helpers.wow")

local link = wow.itemLink

describe("Gear", function()
	local ns
	before_each(function()
		ns = wow.boot()
		_G.MasterAnglerDB = nil
		ns.InitDB()
	end)
	after_each(function()
		wow.restore()
	end)

	it("has no shirt and no tabard slot", function()
		for _, slot in ipairs(ns.Gear.SLOTS) do
			assert.is_true(slot ~= 4 and slot ~= 19)
		end
		assert.equals(17, #ns.Gear.SLOTS)
	end)

	describe("Snapshot and Save", function()
		it("returns a link or false for each slot", function()
			wow.worn[1] = link(100)
			local snapshot = ns.Gear.Snapshot()
			assert.equals(link(100), snapshot[1])
			assert.is_false(snapshot[2])
			assert.is_nil(snapshot[4])
		end)

		it("stores the snapshot in the character and prints the item count", function()
			wow.worn[1] = link(100)
			wow.worn[16] = link(200)
			ns.Gear.Save()
			assert.equals(link(100), ns.Char().gear[1])
			assert.is_truthy(_G.DEFAULT_CHAT_FRAME.lines[1]:find("2 items", 1, true))
		end)

		it("does nothing in read-only mode or without a character", function()
			ns.readOnly = true
			ns.Gear.Save()
			ns.readOnly = false
			wow.player.name = nil
			ns.Gear.Save()
			assert.equals(0, #_G.DEFAULT_CHAT_FRAME.lines)
		end)

		it("is the savegear command", function()
			wow.worn[1] = link(100)
			_G.SlashCmdList.MASTERANGLER("savegear")
			assert.equals(link(100), ns.Char().gear[1])
		end)
	end)

	describe("Plan", function()
		it("returns only changed slots and treats equal IDs with different links as equal", function()
			local target = { [1] = link(100), [16] = link(200) }
			local current = { [1] = "|Hitem:100::::::::1:::|h[x]|h", [16] = link(300) }
			local plan = ns.Gear.Plan(target, current)
			assert.equals(1, #plan)
			assert.equals(16, plan[1].slot)
			assert.equals(link(200), plan[1].link)
		end)

		it("handles false on both sides and a missing target slot", function()
			assert.same({}, ns.Gear.Plan({ [1] = false }, { [1] = false }))
			local plan = ns.Gear.Plan({}, { [17] = link(5) })
			assert.same({ { slot = 17, link = false } }, plan)
		end)

		it("plans two identical rings by slot", function()
			local plan = ns.Gear.Plan({ [11] = link(7), [12] = link(7) }, { [11] = link(7), [12] = false })
			assert.same({ { slot = 12, link = link(7) } }, plan)
		end)
	end)

	describe("Apply", function()
		it("calls EquipItemByName with link and slot", function()
			ns.Gear.Apply({ { slot = 16, link = link(200) } })
			assert.same({ { link(200), 16 } }, wow.equipCalls)
		end)

		it("skips a missing item and warns once", function()
			wow.itemCounts[200] = 0
			ns.Gear.Apply({ { slot = 16, link = link(200) }, { slot = 1, link = link(100) } })
			ns.Gear.Apply({ { slot = 16, link = link(200) } })
			assert.same({ { link(100), 1 } }, wow.equipCalls)
			assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
		end)

		it("empties a slot into the first free bag", function()
			wow.worn[17] = link(5)
			wow.freeSlots[0] = 0
			wow.freeSlots[1] = 0
			ns.Gear.Apply({ { slot = 17, link = false } })
			assert.is_nil(wow.worn[17])
			assert.same({ { bag = 2, invSlot = 21 } }, wow.puts)
		end)

		it("uses the backpack call for bag 0", function()
			wow.worn[17] = link(5)
			ns.Gear.Apply({ { slot = 17, link = false } })
			assert.same({ { bag = 0 } }, wow.puts)
		end)

		it("skips specialized bags", function()
			wow.worn[17] = link(5)
			wow.freeSlots[0] = 0
			wow.bagTypes[1] = 8
			ns.Gear.Apply({ { slot = 17, link = false } })
			assert.equals(2, wow.puts[1].bag)
		end)

		it("falls back to 19 + bag without ContainerIDToInventoryID", function()
			_G.C_Container.ContainerIDToInventoryID = nil
			wow.worn[17] = link(5)
			wow.freeSlots[0] = 0
			ns.Gear.Apply({ { slot = 17, link = false } })
			assert.equals(20, wow.puts[1].invSlot)
		end)

		it("with full bags warns once and clears the cursor", function()
			wow.worn[17] = link(5)
			for bag = 0, 4 do
				wow.freeSlots[bag] = 0
			end
			ns.Gear.Apply({ { slot = 17, link = false } })
			assert.equals(1, wow.cleared)
			assert.equals(0, #wow.puts)
			assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
			assert.is_truthy(_G.DEFAULT_CHAT_FRAME.lines[1]:find(link(5), 1, true))
			ns.Gear.Apply({ { slot = 17, link = false } })
			assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
		end)

		it("counts the slots it fills when it empties more than one slot", function()
			wow.worn[1] = link(5)
			wow.worn[17] = link(6)
			wow.freeSlots[0] = 1
			ns.Gear.Apply({ { slot = 1, link = false }, { slot = 17, link = false } })
			assert.same({ { bag = 0 }, { bag = 1, invSlot = 20 } }, wow.puts)
		end)

		it("warns once for each slot that stays equipped with full bags", function()
			wow.worn[1] = link(5)
			wow.worn[17] = link(6)
			for bag = 0, 4 do
				wow.freeSlots[bag] = 0
			end
			ns.Gear.Apply({ { slot = 1, link = false }, { slot = 17, link = false } })
			assert.equals(2, #_G.DEFAULT_CHAT_FRAME.lines)
		end)

		it("clears an item held on the cursor before it swaps", function()
			wow.cursor = link(9)
			ns.Gear.Apply({ { slot = 16, link = link(200) } })
			assert.equals(1, wow.cleared)
			assert.is_nil(wow.cursor)
		end)

		it("puts the item back when a put into a bag fails", function()
			wow.worn[17] = link(5)
			_G.PutItemInBackpack = function() end
			ns.Gear.Apply({ { slot = 17, link = false } })
			assert.equals(1, wow.cleared)
			assert.is_nil(wow.cursor)
		end)

		it("puts the item back before it empties the next slot when a put fails", function()
			wow.worn[1] = link(5)
			wow.worn[11] = link(6)
			wow.freeSlots[0] = 1
			_G.PutItemInBackpack = function() end
			local order = {}
			local pickup = _G.PickupInventoryItem
			_G.PickupInventoryItem = function(s)
				order[#order + 1] = "pickup " .. s .. " cleared " .. wow.cleared
				pickup(s)
			end
			ns.Gear.Apply({ { slot = 1, link = false }, { slot = 11, link = false } })
			assert.same({ "pickup 1 cleared 0", "pickup 11 cleared 1" }, order)
		end)

		it("does nothing for an already empty slot", function()
			ns.Gear.Apply({ { slot = 17, link = false } })
			assert.equals(0, #wow.puts)
			assert.equals(0, wow.cleared)
		end)

		it("equips before it empties, so a two-handed pole can free the offhand", function()
			local order = {}
			local equip = _G.C_Item.EquipItemByName
			_G.C_Item.EquipItemByName = function(l, s)
				order[#order + 1] = "equip"
				equip(l, s)
			end
			local pickup = _G.PickupInventoryItem
			_G.PickupInventoryItem = function(s)
				order[#order + 1] = "pickup"
				pickup(s)
			end
			wow.worn[17] = link(5)
			ns.Gear.Apply({ { slot = 17, link = false }, { slot = 16, link = link(200) } })
			assert.same({ "equip", "pickup" }, order)
		end)
	end)

	it("ItemID handles non-links", function()
		assert.is_nil(ns.Gear.ItemID(false))
		assert.is_nil(ns.Gear.ItemID(nil))
		assert.equals(12, ns.Gear.ItemID("item:12"))
	end)
end)
