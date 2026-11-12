local wow = require("spec.helpers.wow")

local T0 = 1700000000

describe("Window", function()
	local ns, created
	local NAMES

	before_each(function()
		NAMES = { [1] = "Bass", [2] = "Carp", [3] = "Angelfish" }
		ns = wow.boot()
		_G.MasterAnglerDB = nil
		ns.InitDB()
		wow.maps.info[20] = { mapType = 3, name = "Zeta Zone" }
		wow.maps.info[30] = { mapType = 3, name = "Alpha Zone" }
		_G.C_Item.GetItemIconByID = function(id)
			return 1000 + id
		end
		_G.C_Item.GetItemNameByID = function(id)
			return NAMES[id]
		end
		MasterAnglerDB.chars["Tester-Realm"] = {
			catches = {
				{ 1, 20, 1, 1, T0, 0, 2 },
				{ 1, 20, 1, 1, T0 + 3600, 0, 1 },
				{ 1, 30, 1, 1, T0 + 60, 0, 1 },
				{ 2, 30, 1, 1, T0, 0, 1 },
				{ 3, 20, 1, 1, T0, 0, 1 },
			},
		}
		MasterAnglerDB.chars["Alt-Realm"] = { catches = { { 9, 20, 1, 1, 1, 0, 1 } } }
		local base = _G.CreateFrame
		created = {}
		_G.CreateFrame = function(kind, name, parent, template)
			local made = base(kind, name, parent, template)
			created[#created + 1] = { frame = made, kind = kind, parent = parent, template = template }
			return made
		end
	end)
	after_each(function()
		wow.restore()
	end)

	local function window()
		return _G.MasterAnglerJournal
	end

	local function question()
		return "Interface\\Icons\\INV_Misc_QuestionMark"
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

	local function cellFrames()
		local found = {}
		for _, entry in ipairs(created) do
			if entry.parent == window().listContent and entry.kind == "Button" then
				found[#found + 1] = entry.frame
			end
		end
		return found
	end

	local function backButton()
		for _, entry in ipairs(created) do
			if entry.template == "UIPanelButtonTemplate" then
				return entry.frame
			end
		end
	end

	local function names(rows)
		local list = {}
		for _, row in ipairs(rows) do
			list[#list + 1] = row.name
		end
		return list
	end

	it("Toggle creates the window, shows and hides it", function()
		ns.Window.Toggle()
		assert.is_true(window():IsShown())
		ns.Window.Toggle()
		assert.is_false(window():IsShown())
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

	it("falls back to the basic templates when the new ones fail", function()
		local base = _G.CreateFrame
		_G.CreateFrame = function(kind, name, parent, template)
			if template == "ButtonFrameTemplate" or template == "SearchBoxTemplate" then
				error("no template")
			end
			return base(kind, name, parent, template)
		end
		assert.has_no.errors(function()
			ns.Window.Toggle()
		end)
		assert.is_true(window():IsShown())
	end)

	it("runs without the portrait helper", function()
		_G.ButtonFrameTemplate_HidePortrait = nil
		assert.has_no.errors(function()
			ns.Window.Create()
		end)
	end)

	it("retries the build after a failure instead of reusing a half-built window", function()
		local base = _G.CreateFrame
		_G.CreateFrame = function(kind, name, parent, template)
			if template == "UIPanelButtonTemplate" then
				error("boom")
			end
			return base(kind, name, parent, template)
		end
		assert.has_error(function()
			ns.Window.Create()
		end)
		_G.CreateFrame = base
		assert.has_no.errors(function()
			ns.Window.Toggle()
		end)
		assert.is_true(window():IsShown())
	end)

	describe("model", function()
		it("lists the fish by name, then the alt-only fish as ???", function()
			local model = ns.Window.BuildModel()
			assert.equals("list", model.view)
			assert.same({ "Angelfish", "Bass", "Carp", "???" }, names(model.rows))
			assert.equals(1001, model.rows[2].icon)
			assert.equals(question(), model.rows[4].icon)
			assert.is_false(model.rows[4].mine)
		end)

		it("sorts names without regard to case", function()
			NAMES[2] = "carp"
			NAMES[1] = "Bass"
			assert.same({ "Angelfish", "Bass", "carp", "???" }, names(ns.Window.BuildModel().rows))
		end)

		it("filters by a case-insensitive part of the name and hides the ??? entries", function()
			ns.Window.SetSearch("  AN ")
			assert.same({ "Angelfish" }, names(ns.Window.BuildModel().rows))
			ns.Window.SetSearch("s")
			assert.same({ "Angelfish", "Bass" }, names(ns.Window.BuildModel().rows))
		end)

		it("treats pattern characters in the search as plain text", function()
			ns.Window.SetSearch(".*")
			local model = ns.Window.BuildModel()
			assert.equals(0, #model.rows)
			assert.is_true(model.noMatches)
		end)

		it("reports no matches only when there are catches", function()
			ns.Window.SetSearch("zzz")
			assert.is_true(ns.Window.BuildModel().noMatches)
			MasterAnglerDB.chars = {}
			local model = ns.Window.BuildModel()
			assert.is_true(model.noCatches)
			assert.is_false(model.noMatches)
		end)

		it("shows ... for an uncached name, sorts it last among mine and requests it once", function()
			local requests = {}
			NAMES[2] = nil
			_G.C_Item.RequestLoadItemDataByID = function(id)
				requests[#requests + 1] = id
			end
			assert.same({ "Angelfish", "Bass", "...", "???" }, names(ns.Window.BuildModel().rows))
			ns.Window.BuildModel()
			assert.same({ 2 }, requests)
		end)

		it("works without the name and icon APIs", function()
			_G.C_Item.GetItemNameByID = nil
			_G.C_Item.GetItemIconByID = nil
			local model = ns.Window.BuildModel()
			assert.equals("...", model.rows[1].name)
			assert.equals(question(), model.rows[1].icon)
		end)

		it("reads no character data in read-only mode", function()
			ns.readOnly = true
			local model = ns.Window.BuildModel()
			assert.is_true(model.noCatches)
			assert.equals(0, #model.rows)
		end)

		it("builds the detail of a fish: totals and the zones it was seen in, most caught first", function()
			ns.Window.ShowDetail(1)
			local model = ns.Window.BuildModel()
			assert.equals("detail", model.view)
			local detail = model.detail
			assert.equals("Bass", detail.name)
			assert.equals(1001, detail.icon)
			assert.equals(4, detail.count)
			assert.equals(T0, detail.first)
			assert.equals(T0 + 3600, detail.last)
			assert.equals(2, #detail.zones)
			assert.same({ mapID = 20, name = "Zeta Zone", count = 3, last = T0 + 3600 }, detail.zones[1])
			assert.same({ mapID = 30, name = "Alpha Zone", count = 1, last = T0 + 60 }, detail.zones[2])
		end)

		it("names a zone without map info by its ID", function()
			wow.maps.info[20] = nil
			ns.Window.ShowDetail(1)
			assert.equals("Zone 20", ns.Window.BuildModel().detail.zones[1].name)
		end)

		it("falls back to the list for an unknown fish or an alt-only fish", function()
			ns.Window.ShowDetail(9)
			assert.equals("list", ns.Window.BuildModel().view)
			ns.Window.ShowDetail(12345)
			assert.equals("list", ns.Window.BuildModel().view)
		end)

		it("going back from a detail keeps the filtered results", function()
			ns.Window.SetSearch("an")
			ns.Window.ShowDetail(3)
			assert.equals("detail", ns.Window.BuildModel().view)
			ns.Window.Back()
			local model = ns.Window.BuildModel()
			assert.equals("list", model.view)
			assert.equals("an", model.query)
			assert.same({ "Angelfish" }, names(model.rows))
		end)
	end)

	describe("rendering", function()
		it("lays the fish out in four columns with icon and name", function()
			MasterAnglerDB.chars["Tester-Realm"].catches[#MasterAnglerDB.chars["Tester-Realm"].catches + 1] =
				{ 4, 20, 1, 1, T0, 0, 1 }
			NAMES[4] = "Dace"
			ns.Window.Toggle()
			local cells = cellFrames()
			assert.equals(5, #cells)
			local expected = { { 0, 0 }, { 146, 0 }, { 292, 0 }, { 438, 0 }, { 0, -28 } }
			for i, cell in ipairs(cells) do
				local point = lastCall(cell, "SetPoint")
				assert.same(expected[i], { point[5], point[6] }, "cell " .. i)
			end
			assert.equals("Angelfish", lastCall(cells[1].name, "SetText")[2])
			assert.equals(1003, lastCall(cells[1].icon, "SetTexture")[2])
		end)

		it("a ??? cell shows the question icon, grey text, no tooltip and no detail", function()
			ns.Window.Toggle()
			local cell = cellFrames()[4]
			assert.equals(question(), lastCall(cell.icon, "SetTexture")[2])
			assert.equals("???", lastCall(cell.name, "SetText")[2])
			local color = lastCall(cell.name, "SetTextColor")
			assert.same({ 0.6, 0.6, 0.6 }, { color[2], color[3], color[4] })
			cell.scripts.OnEnter(cell)
			assert.is_false(_G.GameTooltip.shown)
			cell.scripts.OnClick(cell)
			assert.equals("list", window().model.view)
		end)

		it("the hover on a caught fish shows its item tooltip", function()
			ns.Window.Toggle()
			local cell = cellFrames()[2]
			cell.scripts.OnEnter(cell)
			assert.is_true(_G.GameTooltip.shown)
			assert.equals(1, _G.GameTooltip.itemID)
			cell.scripts.OnLeave(cell)
			assert.is_false(_G.GameTooltip.shown)
		end)

		it("a redraw re-shows the tooltip of the hovered cell with its new item", function()
			ns.Window.Toggle()
			local cell = cellFrames()[1]
			cell.scripts.OnEnter(cell)
			ns.Window.SetSearch("carp")
			assert.equals(2, _G.GameTooltip.itemID)
			assert.is_true(_G.GameTooltip.shown)
		end)

		it("clicking a fish opens its detail in the same window and hides the list and the search", function()
			ns.Window.Toggle()
			local cell = cellFrames()[2]
			cell.scripts.OnClick(cell)
			assert.equals("detail", window().model.view)
			assert.is_true(window().detail:IsShown())
			assert.is_false(window().listScroll:IsShown())
			assert.is_false(window().search:IsShown())
			local panel = window().detail
			assert.equals("Bass", lastCall(panel.name, "SetText")[2])
			assert.equals("Caught: 4", lastCall(panel.count, "SetText")[2])
			assert.equals("First catch: " .. os.date("%Y-%m-%d %H:%M", T0), lastCall(panel.first, "SetText")[2])
			assert.equals("Last catch: " .. os.date("%Y-%m-%d %H:%M", T0 + 3600), lastCall(panel.last, "SetText")[2])
		end)

		it("lists the zones of the fish in the detail", function()
			ns.Window.Toggle()
			ns.Window.ShowDetail(1)
			local rows = {}
			for _, entry in ipairs(created) do
				if entry.parent == window().detail.zoneContent then
					rows[#rows + 1] = entry.frame
				end
			end
			assert.equals(2, #rows)
			assert.equals("Zeta Zone (3)", lastCall(rows[1].name, "SetText")[2])
			assert.equals("Alpha Zone (1)", lastCall(rows[2].name, "SetText")[2])
			assert.equals(os.date("%Y-%m-%d %H:%M", T0 + 3600), lastCall(rows[1].last, "SetText")[2])
		end)

		it("hides the spare zone rows when the next fish was seen in fewer zones", function()
			ns.Window.Toggle()
			ns.Window.ShowDetail(1)
			ns.Window.ShowDetail(3)
			local rows = {}
			for _, entry in ipairs(created) do
				if entry.parent == window().detail.zoneContent then
					rows[#rows + 1] = entry.frame
				end
			end
			assert.is_true(rows[1].shown)
			assert.is_false(rows[2].shown)
		end)

		it("the Go back button returns to the list with the filter kept", function()
			ns.Window.Toggle()
			window().search:SetText("an")
			window().search.scripts.OnTextChanged(window().search)
			local cell = cellFrames()[1]
			cell.scripts.OnClick(cell)
			assert.equals("detail", window().model.view)
			backButton().scripts.OnClick(backButton())
			assert.equals("list", window().model.view)
			assert.is_true(window().search:IsShown())
			assert.is_true(window().listScroll:IsShown())
			assert.equals("an", window().search:GetText())
			assert.same({ "Angelfish" }, names(window().model.rows))
			assert.is_false(cellFrames()[2].shown)
		end)

		it("typing in the search box filters the list", function()
			ns.Window.Toggle()
			window().search:SetText("carp")
			window().search.scripts.OnTextChanged(window().search)
			assert.same({ "Carp" }, names(window().model.rows))
			assert.is_false(cellFrames()[2].shown)
		end)

		it("Escape in the search box only drops its focus", function()
			ns.Window.Create()
			local box = window().search
			box.scripts.OnEscapePressed(box)
			assert.is_truthy(lastCall(box, "ClearFocus"))
			assert.is_false(window():IsShown())
		end)

		it("SetSearch writes the text into the box and ignores an unchanged text", function()
			ns.Window.Toggle()
			assert.is_true(ns.Window.SetSearch("bass"))
			assert.equals("bass", window().search:GetText())
			assert.is_false(ns.Window.SetSearch("bass"))
			assert.is_true(ns.Window.SetSearch(nil))
			assert.equals("", window().search:GetText())
		end)

		it("SetSearch before the window exists stores the text without drawing", function()
			assert.is_false(ns.Window.SetSearch("bass"))
			assert.equals("bass", ns.Window.BuildModel().query)
		end)

		it("a reopen starts on the list with an empty search", function()
			ns.Window.Toggle()
			ns.Window.SetSearch("an")
			ns.Window.ShowDetail(3)
			ns.Window.Toggle()
			ns.Window.Toggle()
			assert.equals("list", window().model.view)
			assert.equals("", window().search:GetText())
			assert.equals(4, #window().model.rows)
		end)

		it("shows the empty text for an empty journal, the no-match text and the read-only text", function()
			MasterAnglerDB.chars = {}
			ns.Window.Toggle()
			assert.equals("No catches yet. Go fishing!", lastCall(window().empty, "SetText")[2])
			ns.readOnly = true
			ns.Window.Refresh()
			assert.is_truthy(lastCall(window().empty, "SetText")[2]:find("newer version", 1, true))
			ns.readOnly = false
			MasterAnglerDB.chars["Tester-Realm"] = { catches = { { 1, 20, 1, 1, T0, 0, 1 } } }
			ns.Window.SetSearch("zzz")
			assert.equals("No fish match your search.", lastCall(window().empty, "SetText")[2])
			ns.Window.SetSearch("")
			assert.equals("", lastCall(window().empty, "SetText")[2])
		end)

		it("hides the spare cells when the list gets shorter", function()
			ns.Window.Toggle()
			ns.Window.SetSearch("carp")
			local cells = cellFrames()
			assert.is_true(cells[1].shown)
			assert.is_false(cells[2].shown)
		end)
	end)

	describe("redraw events", function()
		local function fire(event, ...)
			ns.events.scripts.OnEvent(ns.events, event, ...)
		end

		it("a catch redraws only while the window is shown", function()
			ns.Window.Create()
			wow.loot.fishing = true
			wow.loot.slots = { { link = wow.itemLink(5), quantity = 1 } }
			fire("LOOT_OPENED")
			fire("LOOT_SLOT_CLEARED", 1)
			wow.runTimers()
			assert.is_nil(window().model)
			ns.Window.Toggle()
			assert.equals(5, #window().model.rows)
			wow.loot.slots = { { link = wow.itemLink(6), quantity = 1 } }
			fire("LOOT_OPENED")
			fire("LOOT_SLOT_CLEARED", 1)
			wow.runTimers()
			assert.equals(6, #window().model.rows)
		end)

		it("a burst of catches redraws once per frame", function()
			ns.Window.Toggle()
			wow.loot.fishing = true
			wow.loot.slots = { { link = wow.itemLink(5), quantity = 1 }, { link = wow.itemLink(6), quantity = 1 } }
			fire("LOOT_OPENED")
			local before = #wow.timers
			fire("LOOT_SLOT_CLEARED", 1)
			fire("LOOT_SLOT_CLEARED", 2)
			assert.equals(before + 1, #wow.timers)
		end)

		it("GET_ITEM_INFO_RECEIVED redraws only for a name the window asked for, once", function()
			NAMES[2] = nil
			ns.Window.Toggle()
			NAMES[2] = "Carp"
			local before = #wow.timers
			window().scripts.OnEvent(window(), "GET_ITEM_INFO_RECEIVED", 777, true)
			assert.equals(before, #wow.timers)
			window().scripts.OnEvent(window(), "GET_ITEM_INFO_RECEIVED", 2, true)
			assert.equals(before + 1, #wow.timers)
			wow.runTimers()
			assert.same({ "Angelfish", "Bass", "Carp", "???" }, names(window().model.rows))
			window().scripts.OnEvent(window(), "GET_ITEM_INFO_RECEIVED", 2, true)
			assert.equals(0, #wow.timers)
		end)

		it("a failing redraw is reported once and does not raise", function()
			ns.Window.Toggle()
			_G.C_Map.GetMapInfo = nil
			ns.Window.ShowDetail(1)
			_G.GameTooltip = nil
			local cell = cellFrames()[1]
			assert.has_no.errors(function()
				window().scripts.OnShow(window())
			end)
			assert.has_no.errors(function()
				cell.scripts.OnClick(cell)
			end)
			assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
		end)

		it("Reset forgets the frame and the state", function()
			ns.Window.Toggle()
			ns.Window.SetSearch("an")
			ns.Window.Reset()
			assert.is_false(ns.Window.Refresh())
			assert.equals("", ns.Window.BuildModel().query)
		end)
	end)
end)
