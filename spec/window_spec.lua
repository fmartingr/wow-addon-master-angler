local wow = require("spec.helpers.wow")

describe("Window", function()
	local ns
	before_each(function()
		ns = wow.boot()
		_G.MasterAnglerDB = nil
		ns.InitDB()
		wow.maps.best = 20
		wow.maps.info[20] = { mapType = 3, parentMapID = 10, name = "Zeta Zone" }
		wow.maps.info[30] = { mapType = 3, parentMapID = 10, name = "Alpha Zone" }
		_G.C_Item.GetItemIconByID = function(id)
			return 1000 + id
		end
		_G.C_Item.GetItemNameByID = function(id)
			return "Fish " .. id
		end
		MasterAnglerDB.chars["Tester-Realm"] = {
			catches = {
				{ 1, 20, 1, 1, 1700000000, 0, 2 },
				{ 1, 20, 1, 1, 1700003600, 0, 1 },
				{ 2, 30, 1, 1, 1700000000, 0, 1 },
			},
		}
		MasterAnglerDB.chars["Alt-Realm"] = { catches = { { 9, 20, 1, 1, 1, 0, 1 } } }
	end)
	after_each(function()
		wow.restore()
	end)

	local function frameOf()
		return _G.MasterAnglerJournal
	end

	local function question()
		return "Interface\\Icons\\INV_Misc_QuestionMark"
	end

	it("Toggle creates the window, shows and hides it", function()
		ns.Window.Toggle()
		assert.is_true(frameOf():IsShown())
		ns.Window.Toggle()
		assert.is_false(frameOf():IsShown())
	end)

	it("registers Escape through UISpecialFrames, once", function()
		ns.Window.Create()
		ns.Window.Create()
		local count = 0
		for _, name in ipairs(_G.UISpecialFrames) do
			if name == "MasterAnglerJournal" then
				count = count + 1
			end
		end
		assert.equals(1, count)
	end)

	it("falls back to the basic template when ButtonFrameTemplate fails", function()
		local templates = {}
		_G.CreateFrame = function(_, name, _, template)
			templates[#templates + 1] = template
			if template == "ButtonFrameTemplate" then
				error("no template")
			end
			return wow.newFrame(name)
		end
		ns.Window.Create()
		assert.equals("BasicFrameTemplateWithInset", templates[2])
	end)

	it("runs without the portrait helper", function()
		_G.ButtonFrameTemplate_HidePortrait = nil
		assert.has_no.errors(function()
			ns.Window.Create()
		end)
	end)

	it("sorts the zones by name and opens on the current zone", function()
		local model = ns.Window.BuildModel()
		assert.equals("Alpha Zone", model.zones[1].name)
		assert.equals("Zeta Zone", model.zones[2].name)
		assert.equals(20, model.selected)
	end)

	it("opens on the first zone when the current zone has no catches", function()
		wow.maps.best = 99
		local model = ns.Window.BuildModel()
		assert.equals(30, model.selected)
	end)

	it("names a zone without map info by its ID", function()
		wow.maps.info[30] = nil
		local model = ns.Window.BuildModel()
		local names = {}
		for _, zone in ipairs(model.zones) do
			names[#names + 1] = zone.name
		end
		assert.is_truthy(table.concat(names, "|"):find("Zone 30", 1, true))
	end)

	it("lists caught items with icon, name and count and ??? rows with the question icon", function()
		local model = ns.Window.BuildModel()
		assert.equals(2, #model.rows)
		assert.same(
			{ itemID = 1, mine = true, count = 3, first = 1700000000, last = 1700003600, name = "Fish 1", icon = 1001 },
			model.rows[1]
		)
		assert.equals("???", model.rows[2].name)
		assert.equals(question(), model.rows[2].icon)
		assert.is_false(model.rows[2].mine)
	end)

	it("falls back to the question icon when the client has no icon API", function()
		_G.C_Item.GetItemIconByID = nil
		assert.equals(question(), ns.Window.BuildModel().rows[1].icon)
	end)

	it("shows ... for an uncached item name, and requests it once", function()
		local requests = {}
		_G.C_Item.GetItemNameByID = function()
			return nil
		end
		_G.C_Item.RequestLoadItemDataByID = function(id)
			requests[#requests + 1] = id
		end
		assert.equals("...", ns.Window.BuildModel().rows[1].name)
		ns.Window.BuildModel()
		assert.same({ 1 }, requests)
	end)

	it("shows ... without the name API", function()
		_G.C_Item.GetItemNameByID = nil
		assert.equals("...", ns.Window.BuildModel().rows[1].name)
	end)

	it("Select changes the page and a reopen returns to the current zone", function()
		ns.Window.Toggle()
		ns.Window.Select(30)
		assert.equals(30, frameOf().model.selected)
		assert.equals(1, #frameOf().model.rows)
		ns.Window.Toggle()
		ns.Window.Toggle()
		assert.equals(20, frameOf().model.selected)
	end)

	it("Select on a hidden window does not render", function()
		ns.Window.Create()
		assert.is_false(ns.Window.Select(30))
		assert.is_nil(frameOf().model)
	end)

	describe("rendering", function()
		local created
		before_each(function()
			local base = _G.CreateFrame
			created = {}
			_G.CreateFrame = function(kind, name, parent, template)
				local created_frame = base(kind, name, parent, template)
				if kind == "Button" then
					created[#created + 1] = { frame = created_frame, parent = parent }
				end
				return created_frame
			end
		end)

		local function buttons(parent)
			local found = {}
			for _, entry in ipairs(created) do
				if entry.parent == parent then
					found[#found + 1] = entry.frame
				end
			end
			return found
		end

		local function lastCall(target, name)
			local result
			for _, call in ipairs(target.calls) do
				if call[1] == name then
					result = call
				end
			end
			return result
		end

		it("a caught row shows the icon, name and count, and the hover shows the item and the catch dates", function()
			ns.Window.Toggle()
			local row = buttons(frameOf().itemContent)[1]
			assert.equals(1001, lastCall(row.icon, "SetTexture")[2])
			assert.equals("Fish 1", lastCall(row.name, "SetText")[2])
			assert.equals(3, lastCall(row.count, "SetText")[2])
			row.scripts.OnEnter(row)
			assert.is_true(_G.GameTooltip.shown)
			assert.equals(1, _G.GameTooltip.itemID)
			assert.equals("Caught: 3", _G.GameTooltip.lines[1])
			assert.equals("First catch: " .. os.date("%Y-%m-%d %H:%M", 1700000000), _G.GameTooltip.lines[2])
			assert.equals("Last catch: " .. os.date("%Y-%m-%d %H:%M", 1700003600), _G.GameTooltip.lines[3])
			row.scripts.OnLeave(row)
			assert.is_false(_G.GameTooltip.shown)
		end)

		it("a ??? row shows the question icon, the text ??? and no tooltip", function()
			ns.Window.Toggle()
			local row = buttons(frameOf().itemContent)[2]
			assert.equals(question(), lastCall(row.icon, "SetTexture")[2])
			assert.equals("???", lastCall(row.name, "SetText")[2])
			local color = lastCall(row.name, "SetTextColor")
			assert.same({ 0.6, 0.6, 0.6 }, { color[2], color[3], color[4] })
			row.scripts.OnEnter(row)
			assert.is_false(_G.GameTooltip.shown)
		end)

		it("a zone button selects its page", function()
			ns.Window.Toggle()
			local zone = buttons(frameOf().zoneContent)[1]
			assert.equals(30, zone.mapID)
			zone.scripts.OnClick(zone)
			assert.equals(30, frameOf().model.selected)
		end)

		it("hides the spare rows when a page is shorter", function()
			ns.Window.Toggle()
			ns.Window.Select(30)
			local rows = buttons(frameOf().itemContent)
			assert.is_true(rows[1].shown)
			assert.is_false(rows[2].shown)
		end)

		it("an empty journal shows the empty text", function()
			MasterAnglerDB.chars = {}
			ns.Window.Toggle()
			assert.equals("No catches yet. Go fishing!", lastCall(frameOf().empty, "SetText")[2])
			assert.equals(0, #frameOf().model.zones)
		end)

		it("a catch event redraws only while the window is shown", function()
			ns.Window.Create()
			wow.loot.fishing = true
			wow.loot.slots = { { link = wow.itemLink(5), quantity = 1 } }
			ns.events.scripts.OnEvent(ns.events, "LOOT_OPENED")
			ns.events.scripts.OnEvent(ns.events, "LOOT_SLOT_CLEARED", 1)
			wow.runTimers()
			assert.is_nil(frameOf().model)
			ns.Window.Toggle()
			assert.equals(3, #frameOf().model.rows)
			wow.loot.slots = {
				{ link = wow.itemLink(6), quantity = 1 },
				{ link = wow.itemLink(7), quantity = 1 },
			}
			ns.events.scripts.OnEvent(ns.events, "LOOT_OPENED")
			wow.runTimers()
			local before = #wow.timers
			ns.events.scripts.OnEvent(ns.events, "LOOT_SLOT_CLEARED", 1)
			ns.events.scripts.OnEvent(ns.events, "LOOT_SLOT_CLEARED", 2)
			assert.equals(before + 1, #wow.timers)
			wow.runTimers()
			assert.equals(5, #frameOf().model.rows)
		end)

		it("a redraw refreshes the tooltip of the hovered row", function()
			ns.Window.Toggle()
			local row = buttons(frameOf().itemContent)[1]
			row.scripts.OnEnter(row)
			assert.equals(1, _G.GameTooltip.itemID)
			MasterAnglerDB.chars["Tester-Realm"].catches = { { 4, 20, 1, 1, 1700000000, 0, 9 } }
			ns.Window.Refresh()
			assert.equals(4, _G.GameTooltip.itemID)
			assert.equals("Caught: 9", _G.GameTooltip.lines[1])
		end)

		it("a redraw does not reopen a tooltip the row no longer shows", function()
			ns.Window.Toggle()
			local row = buttons(frameOf().itemContent)[1]
			row.scripts.OnEnter(row)
			row.scripts.OnLeave(row)
			ns.Window.Refresh()
			assert.is_false(_G.GameTooltip.shown)
		end)

		it("a failed build is retried instead of reused", function()
			local base = _G.CreateFrame
			_G.CreateFrame = function(kind, ...)
				if kind == "ScrollFrame" then
					error("no template")
				end
				return base(kind, ...)
			end
			assert.has.errors(function()
				ns.Window.Create()
			end)
			_G.CreateFrame = base
			ns.Window.Toggle()
			assert.is_truthy(frameOf().itemContent)
			assert.is_true(frameOf():IsShown())
		end)

		it("GET_ITEM_INFO_RECEIVED redraws a shown window for a requested item only", function()
			_G.C_Item.GetItemNameByID = function()
				return nil
			end
			_G.C_Item.RequestLoadItemDataByID = function() end
			ns.Window.Toggle()
			assert.equals("...", frameOf().model.rows[1].name)
			_G.C_Item.GetItemNameByID = function(id)
				return "Renamed " .. id
			end
			frameOf().scripts.OnEvent(frameOf(), "GET_ITEM_INFO_RECEIVED", 777, true)
			wow.runTimers()
			assert.equals("...", frameOf().model.rows[1].name)
			frameOf().scripts.OnEvent(frameOf(), "GET_ITEM_INFO_RECEIVED", 1, true)
			frameOf().scripts.OnEvent(frameOf(), "GET_ITEM_INFO_RECEIVED", 1, true)
			assert.equals(1, #wow.timers)
			wow.runTimers()
			assert.equals("Renamed 1", frameOf().model.rows[1].name)
			frameOf().scripts.OnEvent(frameOf(), "GET_ITEM_INFO_RECEIVED", 1, true)
			assert.equals(0, #wow.timers)
		end)

		it("GET_ITEM_INFO_RECEIVED redraws for an uncached name without the request API", function()
			_G.C_Item.GetItemNameByID = function()
				return nil
			end
			_G.C_Item.RequestLoadItemDataByID = nil
			ns.Window.Toggle()
			_G.C_Item.GetItemNameByID = function(id)
				return "Loaded " .. id
			end
			frameOf().scripts.OnEvent(frameOf(), "GET_ITEM_INFO_RECEIVED", 1, true)
			wow.runTimers()
			assert.equals("Loaded 1", frameOf().model.rows[1].name)
		end)

		it("a failed redraw from show, click or item load prints one message and does not raise", function()
			_G.C_Item.GetItemNameByID = function()
				return nil
			end
			_G.C_Item.RequestLoadItemDataByID = function() end
			ns.Window.Toggle()
			local zone = buttons(frameOf().zoneContent)[1]
			ns.Journal.Build = function()
				error("boom")
			end
			assert.has_no.errors(function()
				zone.scripts.OnClick(zone)
				frameOf():Hide()
				frameOf():Show()
				frameOf().scripts.OnEvent(frameOf(), "GET_ITEM_INFO_RECEIVED", 1, true)
				wow.runTimers()
			end)
			assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
		end)

		it("read-only mode shows no character data and the newer-data text", function()
			ns.readOnly = true
			ns.Window.Toggle()
			assert.equals(0, #frameOf().model.zones)
			assert.equals(ns.L.DB_NEWER, lastCall(frameOf().empty, "SetText")[2])
		end)

		it("a catch without a server time shows no dates", function()
			MasterAnglerDB.chars["Tester-Realm"].catches = { { 1, 20, 1, 1, 0, 0, 1 } }
			ns.Window.Toggle()
			local row = buttons(frameOf().itemContent)[1]
			row.scripts.OnEnter(row)
			assert.same({ "Caught: 1" }, _G.GameTooltip.lines)
		end)

		it("Reset forgets the frame", function()
			ns.Window.Toggle()
			ns.Window.Reset()
			assert.is_false(ns.Window.Refresh())
		end)
	end)
end)
