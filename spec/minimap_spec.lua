local wow = require("spec.helpers.wow")

describe("Minimap", function()
	local ns, registered, icon
	before_each(function()
		ns = wow.boot()
		registered = { shown = {}, hidden = {} }
		icon = {
			Register = function(_, name, object, db)
				registered.icon = { name = name, object = object, db = db }
			end,
			Show = function(_, name)
				registered.shown[#registered.shown + 1] = name
			end,
			Hide = function(_, name)
				registered.hidden[#registered.hidden + 1] = name
			end,
		}
		local ldb = {
			NewDataObject = function(_, name, object)
				registered.object = { name = name, object = object }
				return object
			end,
		}
		_G.LibStub = function(name)
			return name == "LibDataBroker-1.1" and ldb or icon
		end
		_G.MasterAnglerDB = nil
		ns.InitDB()
	end)
	after_each(function()
		wow.restore()
	end)

	it("registers one data object and the icon with the saved settings", function()
		assert.is_true(ns.Minimap.Register())
		assert.equals("MasterAngler", registered.object.name)
		assert.equals("launcher", registered.object.object.type)
		assert.equals(_G.MasterAnglerDB.minimap, registered.icon.db)
		assert.equals("Interface\\Icons\\INV_Misc_QuestionMark", registered.object.object.icon)
	end)

	it("uses the Aquadynamic Fish Attractor icon when the client has it", function()
		_G.C_Item.GetItemIconByID = function(id)
			return id == 6533 and 12345 or nil
		end
		ns.Minimap.Register()
		assert.equals(12345, registered.object.object.icon)
	end)

	it("Register returns false without LibStub or without the libraries", function()
		_G.LibStub = nil
		assert.is_false(ns.Minimap.Register())
		_G.LibStub = function()
			return nil
		end
		assert.is_false(ns.Minimap.Register())
	end)

	it("only left-click toggles the window", function()
		local window = 0
		ns.Window.Toggle = function()
			window = window + 1
		end
		ns.Minimap.OnClick(nil, "LeftButton")
		assert.equals(1, window)
		ns.Minimap.OnClick(nil, "RightButton")
		ns.Minimap.OnClick(nil, "MiddleButton")
		assert.equals(1, window)
	end)

	it("the tooltip shows the title, the count and the hints", function()
		local tt = wow.fake_tooltip()
		ns.Minimap.OnTooltipShow(tt)
		assert.equals(4, #tt.lines)
		assert.equals("Master Angler", tt.lines[1].text)
		assert.is_truthy(tt.lines[2].text:find("0 catches", 1, true))
		assert.equals(ns.L.HINT_LEFT, tt.lines[3].text)
		assert.equals(ns.L.HINT_DRAG, tt.lines[4].text)
	end)

	describe("minimap command and setting", function()
		it("the command toggles the hide flag, the setting and the icon", function()
			ns.Minimap.Register()
			_G.SlashCmdList.MASTERANGLER("minimap")
			assert.is_true(MasterAnglerDB.minimap.hide)
			assert.is_false(ns.Settings.Get("minimap"))
			assert.same({ "MasterAngler" }, registered.hidden)
			_G.SlashCmdList.MASTERANGLER("minimap")
			assert.is_false(MasterAnglerDB.minimap.hide)
			assert.is_true(ns.Settings.Get("minimap"))
			assert.same({ "MasterAngler" }, registered.shown)
		end)

		it("works without a registered icon and prints the new state", function()
			assert.has_no.errors(function()
				ns.Minimap.Toggle()
			end)
			assert.is_true(MasterAnglerDB.minimap.hide)
			assert.is_truthy(_G.DEFAULT_CHAT_FRAME.lines[1]:find("hidden", 1, true))
		end)

		it("the game setting changes the hide flag", function()
			ns.Minimap.Register()
			ns.Settings.Set("minimap", false)
			assert.is_true(MasterAnglerDB.minimap.hide)
			assert.same({ "MasterAngler" }, registered.hidden)
		end)

		it("the setting follows the saved hide flag at load", function()
			_G.MasterAnglerDB = { minimap = { hide = true } }
			ns.events.scripts.OnEvent(ns.events, "ADDON_LOADED", "MasterAngler")
			assert.is_false(ns.Settings.Get("minimap"))
		end)

		it("another addon load does not touch the setting", function()
			MasterAnglerDB.settings.minimap = true
			MasterAnglerDB.minimap.hide = true
			ns.events.scripts.OnEvent(ns.events, "ADDON_LOADED", "Other")
			assert.is_true(MasterAnglerDB.settings.minimap)
		end)

		it("does not change the saved flag in read-only mode", function()
			ns.readOnly = true
			ns.Minimap.Apply(false)
			assert.is_false(MasterAnglerDB.minimap.hide)
			ns.readOnly = false
			_G.MasterAnglerDB = nil
			assert.has_no.errors(function()
				ns.Minimap.Apply(false)
			end)
		end)
	end)

	describe("read-only mode", function()
		before_each(function()
			MasterAnglerDB.minimap.minimapPos = 42
			ns.readOnly = true
		end)

		it("hands LibDBIcon a session copy of the saved table", function()
			ns.Minimap.Register()
			assert.are_not.equal(MasterAnglerDB.minimap, registered.icon.db)
			assert.same({ hide = false, minimapPos = 42 }, registered.icon.db)
		end)

		it("the setting hides the button for the session and keeps the saved flag", function()
			ns.Minimap.Register()
			ns.Minimap.Apply(false)
			assert.is_false(MasterAnglerDB.minimap.hide)
			assert.same({ "MasterAngler" }, registered.hidden)
		end)

		it("the command changes nothing and says why", function()
			ns.Minimap.Toggle()
			assert.is_false(MasterAnglerDB.minimap.hide)
			assert.is_truthy(_G.DEFAULT_CHAT_FRAME.lines[1]:find("newer version", 1, true))
		end)

		it("the tooltip shows the newer-data text and no count", function()
			local tt = wow.fake_tooltip()
			ns.Minimap.OnTooltipShow(tt)
			assert.equals(ns.L.DB_NEWER, tt.lines[2].text)
		end)
	end)

	it("left-click reports a failed journal toggle", function()
		ns.Window.Toggle = function()
			error("boom")
		end
		assert.has_no.errors(function()
			ns.Minimap.OnClick(nil, "LeftButton")
		end)
		assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
	end)

	it("registers the icon at login", function()
		ns.events.scripts.OnEvent(ns.events, "PLAYER_LOGIN")
		assert.is_table(registered.icon)
	end)
end)
