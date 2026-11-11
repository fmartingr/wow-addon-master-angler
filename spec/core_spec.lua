local wow = require("spec.helpers.wow")

describe("Core", function()
	local ns
	before_each(function()
		ns = wow.boot()
	end)
	after_each(function()
		wow.restore()
	end)

	describe("InitDB", function()
		it("fills the defaults into nil, non-table and partial values", function()
			_G.MasterAnglerDB = nil
			ns.InitDB()
			assert.equals(1, _G.MasterAnglerDB.version)
			assert.is_false(_G.MasterAnglerDB.minimap.hide)
			assert.is_table(_G.MasterAnglerDB.settings)
			assert.is_table(_G.MasterAnglerDB.chars)

			_G.MasterAnglerDB = "broken"
			ns.InitDB()
			assert.is_table(_G.MasterAnglerDB)
			assert.is_false(_G.MasterAnglerDB.minimap.hide)

			_G.MasterAnglerDB = { minimap = { minimapPos = 10 }, chars = "bad" }
			ns.InitDB()
			assert.equals(10, _G.MasterAnglerDB.minimap.minimapPos)
			assert.is_false(_G.MasterAnglerDB.minimap.hide)
			assert.is_table(_G.MasterAnglerDB.chars)
		end)

		it("stamps the current version over a non-number version", function()
			_G.MasterAnglerDB = { version = "2" }
			ns.InitDB()
			assert.is_false(ns.readOnly)
			assert.equals(1, _G.MasterAnglerDB.version)
		end)

		it("keeps stored values", function()
			_G.MasterAnglerDB = { minimap = { hide = true } }
			ns.InitDB()
			assert.is_true(_G.MasterAnglerDB.minimap.hide)
		end)

		it("leaves a newer DB unchanged, sets read-only and warns once", function()
			_G.MasterAnglerDB = { version = 2 }
			ns.InitDB()
			ns.InitDB()
			assert.is_true(ns.readOnly)
			assert.is_nil(_G.MasterAnglerDB.minimap)
			assert.equals(2, _G.MasterAnglerDB.version)
			assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
		end)

		it("runs on ADDON_LOADED for this addon only", function()
			_G.MasterAnglerDB = nil
			ns.events.scripts.OnEvent(ns.events, "ADDON_LOADED", "Other")
			assert.is_nil(_G.MasterAnglerDB)
			ns.events.scripts.OnEvent(ns.events, "ADDON_LOADED", "MasterAngler")
			assert.is_table(_G.MasterAnglerDB)
		end)
	end)

	describe("CharKey", function()
		it("joins the name and the realm", function()
			assert.equals("Tester-Realm", ns.CharKey())
		end)

		it("returns nil for nil parts", function()
			wow.player.realm = nil
			assert.is_nil(ns.CharKey())
			wow.player.realm = "Realm"
			wow.player.name = nil
			assert.is_nil(ns.CharKey())
		end)

		it("returns nil for empty parts", function()
			wow.player.name = ""
			assert.is_nil(ns.CharKey())
		end)

		it("returns nil for secret parts", function()
			wow.markSecret("Hidden")
			wow.player.name = "Hidden"
			assert.is_nil(ns.CharKey())
		end)
	end)

	describe("Char", function()
		before_each(function()
			_G.MasterAnglerDB = nil
			ns.InitDB()
		end)

		it("creates the table with defaults and returns the same table again", function()
			local char = ns.Char()
			assert.is_table(char.gear)
			assert.is_false(char.mode.on)
			assert.is_table(char.mode.previous)
			assert.is_table(char.catches)
			assert.equals(char, ns.Char())
			assert.equals(char, _G.MasterAnglerDB.chars["Tester-Realm"])
		end)

		it("completes a partial character table", function()
			_G.MasterAnglerDB.chars["Tester-Realm"] = { catches = { { 1 } } }
			local char = ns.Char()
			assert.equals(1, #char.catches)
			assert.is_table(char.gear)
		end)

		it("returns nil without a key or without a DB", function()
			wow.player.realm = nil
			assert.is_nil(ns.Char())
			wow.player.realm = "Realm"
			_G.MasterAnglerDB = nil
			assert.is_nil(ns.Char())
		end)

		it("repairs a missing chars table", function()
			_G.MasterAnglerDB.chars = nil
			assert.is_table(ns.Char())
		end)

		it("returns nil and does not write in read-only mode", function()
			_G.MasterAnglerDB = { version = 2 }
			ns.InitDB()
			assert.is_nil(ns.Char())
			assert.is_nil(_G.MasterAnglerDB.chars)
			_G.MasterAnglerDB.chars = { ["Tester-Realm"] = { future = true } }
			assert.is_nil(ns.Char())
			assert.same({ future = true }, _G.MasterAnglerDB.chars["Tester-Realm"])
		end)
	end)

	describe("Safe", function()
		it("returns the results of a good call", function()
			local a, b = ns.Safe(function(x, y)
				return x, y
			end, 1, 2)
			assert.equals(1, a)
			assert.equals(2, b)
		end)

		it("returns nil on an error", function()
			assert.is_nil(ns.Safe(function()
				error("boom")
			end))
		end)

		it("returns nil on a secret result", function()
			local secret = wow.markSecret({})
			assert.is_nil(ns.Safe(function()
				return 1, secret
			end))
		end)

		it("returns nil for a missing function", function()
			assert.is_nil(ns.Safe(nil))
		end)

		it("works without issecretvalue", function()
			_G.issecretvalue = nil
			assert.equals(
				5,
				ns.Safe(function()
					return 5
				end)
			)
		end)
	end)

	describe("On", function()
		it("calls all handlers of an event with the event and its arguments", function()
			local seen = {}
			ns.On("TEST_EVENT", function(event, arg)
				seen[#seen + 1] = "a:" .. event .. ":" .. arg
			end)
			ns.On("TEST_EVENT", function(_, arg)
				seen[#seen + 1] = "b:" .. arg
			end)
			ns.events.scripts.OnEvent(ns.events, "TEST_EVENT", "x")
			assert.same({ "a:TEST_EVENT:x", "b:x" }, seen)
			assert.is_true(ns.events.events.TEST_EVENT)
		end)

		it("keeps later handlers running after one fails, and reports once", function()
			local ran = false
			ns.On("TEST_EVENT", function()
				error("boom")
			end)
			ns.On("TEST_EVENT", function()
				ran = true
			end)
			ns.events.scripts.OnEvent(ns.events, "TEST_EVENT")
			ns.events.scripts.OnEvent(ns.events, "TEST_EVENT")
			assert.is_true(ran)
			assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
		end)
	end)

	describe("startup", function()
		it("runs each function on PLAYER_LOGIN and survives an error", function()
			local ran = 0
			ns.startup[#ns.startup + 1] = function()
				error("boom")
			end
			ns.startup[#ns.startup + 1] = function()
				ran = ran + 1
			end
			ns.events.scripts.OnEvent(ns.events, "PLAYER_LOGIN")
			assert.equals(1, ran)
		end)
	end)

	describe("Print and ReportOnce", function()
		it("reports a key one time", function()
			assert.is_true(ns.ReportOnce("k", "msg"))
			assert.is_false(ns.ReportOnce("k", "msg"))
			assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
			assert.is_truthy(_G.DEFAULT_CHAT_FRAME.lines[1]:find("MasterAngler", 1, true))
		end)

		it("does not fail without a chat frame", function()
			_G.DEFAULT_CHAT_FRAME = nil
			assert.has_no.errors(function()
				ns.Print("x")
			end)
		end)
	end)
end)
