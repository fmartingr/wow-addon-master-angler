local wow = require("spec.helpers.wow")

describe("Settings", function()
	local ns
	before_each(function()
		ns = wow.boot()
		_G.MasterAnglerDB = nil
		ns.InitDB()
	end)
	after_each(function()
		wow.restore()
	end)

	it("AddToggle writes the default once and keeps a stored false", function()
		ns.Settings.AddToggle("sound", "HELP_HELP", "HELP_HELP", true)
		assert.is_true(_G.MasterAnglerDB.settings.sound)
		_G.MasterAnglerDB.settings.sound = false
		ns.Settings.AddToggle("sound", "HELP_HELP", "HELP_HELP", true)
		assert.is_false(_G.MasterAnglerDB.settings.sound)
		assert.is_false(ns.Settings.Get("sound"))
	end)

	it("replaces a non-boolean stored value with the default", function()
		_G.MasterAnglerDB.settings.sound = "yes"
		ns.Settings.AddToggle("sound", "HELP_HELP", "HELP_HELP", true)
		assert.is_true(_G.MasterAnglerDB.settings.sound)
		assert.is_true(ns.Settings.Get("sound"))
	end)

	it("ApplyDefaults fills a toggle that was added before the DB existed", function()
		_G.MasterAnglerDB = nil
		ns.Settings.AddToggle("early", "HELP_HELP", "HELP_HELP", true)
		ns.InitDB()
		assert.is_true(_G.MasterAnglerDB.settings.early)
	end)

	it("Get returns the default before the DB exists and false for an unknown key", function()
		_G.MasterAnglerDB = nil
		ns.Settings.AddToggle("early", "HELP_HELP", "HELP_HELP", true)
		assert.is_true(ns.Settings.Get("early"))
		assert.is_false(ns.Settings.Get("unknown"))
	end)

	it("Init registers the category and one checkbox for each toggle", function()
		ns.Settings.AddToggle("a", "HELP_HELP", "HELP_HEADER", true)
		ns.Settings.AddToggle("b", "HELP_HELP", "HELP_HEADER", false)
		assert.is_true(ns.Settings.Init())
		local log = wow.settingsLog
		assert.equals("Master Angler", log.category.name)
		assert.equals(2, #log.checkboxes)
		assert.equals("MasterAngler_a", log.settings[1].variable)
		assert.equals(_G.MasterAnglerDB.settings, log.settings[1].tbl)
		assert.equals(log.category, log.registered)
	end)

	it("registers one checkbox for a key added twice and keeps the last default", function()
		ns.Settings.AddToggle("a", "HELP_HELP", "HELP_HEADER", true)
		ns.Settings.Init()
		ns.Settings.AddToggle("a", "HELP_HELP", "HELP_HEADER", false)
		assert.equals(1, #wow.settingsLog.checkboxes)
		_G.MasterAnglerDB = nil
		assert.is_false(ns.Settings.Get("a"))
	end)

	it("reports once when the category registration fails", function()
		_G.Settings.RegisterAddOnCategory = function()
			error("boom")
		end
		assert.is_false(ns.Settings.Init())
		assert.is_nil(ns.Settings.Category())
		assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
	end)

	it("creates the checkbox at once for a toggle added after Init", function()
		ns.Settings.Init()
		ns.Settings.AddToggle("late", "HELP_HELP", "HELP_HEADER", true)
		assert.equals(1, #wow.settingsLog.checkboxes)
	end)

	it("calls OnChange listeners when the game changes the setting", function()
		local seen = {}
		ns.Settings.AddToggle("a", "HELP_HELP", "HELP_HEADER", true)
		ns.Settings.OnChange("a", function(value)
			seen[#seen + 1] = value
		end)
		ns.Settings.Init()
		wow.settingsLog.settings[1].callback(nil, false)
		assert.same({ false }, seen)
	end)

	it("Set stores the value and calls listeners, but not in read-only mode", function()
		local seen = {}
		ns.Settings.AddToggle("a", "HELP_HELP", "HELP_HEADER", true)
		ns.Settings.OnChange("a", function(value)
			seen[#seen + 1] = value
		end)
		ns.Settings.Set("a", false)
		assert.is_false(ns.Settings.Get("a"))
		assert.same({ false }, seen)
		ns.readOnly = true
		ns.Settings.Set("a", true)
		assert.is_false(ns.Settings.Get("a"))
	end)

	it("does not write a newer DB from AddToggle or the panel in read-only mode", function()
		_G.MasterAnglerDB = { version = 2, settings = { kept = true } }
		ns.InitDB()
		ns.Settings.AddToggle("a", "HELP_HELP", "HELP_HEADER", true)
		assert.is_nil(_G.MasterAnglerDB.settings.a)
		ns.Settings.Init()
		local tbl = wow.settingsLog.settings[1].tbl
		assert.are_not.equal(_G.MasterAnglerDB.settings, tbl)
		assert.is_true(tbl.kept)
		assert.is_true(tbl.a)
		tbl.kept = false
		assert.is_true(_G.MasterAnglerDB.settings.kept)
		assert.is_false(ns.Settings.Get("kept"))
	end)

	it("Set does nothing without a DB", function()
		_G.MasterAnglerDB = nil
		assert.has_no.errors(function()
			ns.Settings.Set("a", true)
		end)
	end)

	it("a failing listener does not break the others", function()
		local ran = false
		ns.Settings.AddToggle("a", "HELP_HELP", "HELP_HEADER", true)
		ns.Settings.OnChange("a", function()
			error("boom")
		end)
		ns.Settings.OnChange("a", function()
			ran = true
		end)
		ns.Settings.Set("a", false)
		ns.Settings.Set("a", true)
		assert.is_true(ran)
		assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
	end)

	describe("without the Settings global", function()
		before_each(function()
			_G.Settings = nil
		end)

		it("keeps the defaults and reports once", function()
			assert.has_no.errors(function()
				ns.Settings.AddToggle("a", "HELP_HELP", "HELP_HEADER", true)
			end)
			assert.is_false(ns.Settings.Init())
			assert.is_false(ns.Settings.Init())
			assert.is_true(ns.Settings.Get("a"))
			assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
		end)
	end)

	it("reports once when the category call fails", function()
		_G.Settings.RegisterVerticalLayoutCategory = function()
			error("boom")
		end
		assert.is_false(ns.Settings.Init())
		assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
	end)

	it("reports once when a checkbox call fails", function()
		_G.Settings.CreateCheckbox = function()
			error("boom")
		end
		ns.Settings.AddToggle("a", "HELP_HELP", "HELP_HEADER", true)
		ns.Settings.AddToggle("b", "HELP_HELP", "HELP_HEADER", true)
		assert.is_true(ns.Settings.Init())
		assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
	end)

	it("runs Init from the startup list", function()
		ns.events.scripts.OnEvent(ns.events, "PLAYER_LOGIN")
		assert.is_table(ns.Settings.Category())
	end)
end)
