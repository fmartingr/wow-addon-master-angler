local wow = require("spec.helpers.wow")

describe("Commands", function()
	local ns
	before_each(function()
		ns = wow.boot()
	end)
	after_each(function()
		wow.restore()
	end)

	local function lines()
		return _G.DEFAULT_CHAT_FRAME.lines
	end

	it("registers the slash command", function()
		assert.equals("/masterangler", _G.SLASH_MASTERANGLER1)
		assert.equals(ns.Commands.Dispatch, _G.SlashCmdList.MASTERANGLER)
	end)

	it("dispatches case-insensitively and passes the rest to the handler", function()
		local got
		ns.Commands.Register("thing", function(rest)
			got = rest
		end, "HELP_HELP")
		_G.SlashCmdList.MASTERANGLER("  THING  one two ")
		assert.equals("one two", got)
	end)

	it("dispatches a command registered with upper-case letters", function()
		local ran = false
		ns.Commands.Register("Reset", function()
			ran = true
		end, "HELP_HELP")
		_G.SlashCmdList.MASTERANGLER("reset")
		assert.is_true(ran)
	end)

	it("replaces a command registered twice and lists it once", function()
		local got
		ns.Commands.Register("mode", function()
			got = "first"
		end, "HELP_HELP")
		ns.Commands.Register("Mode", function()
			got = "second"
		end, "HELP_HELP")
		_G.SlashCmdList.MASTERANGLER("mode")
		assert.equals("second", got)
		ns.Commands.PrintHelp()
		local _, count = table.concat(lines(), "\n"):lower():gsub("masterangler mode", "")
		assert.equals(1, count)
	end)

	it("prints help for no argument, help and an unknown word", function()
		_G.SlashCmdList.MASTERANGLER("")
		local first = #lines()
		assert.is_true(first >= 2)
		_G.SlashCmdList.MASTERANGLER("help")
		_G.SlashCmdList.MASTERANGLER("nonsense")
		assert.equals(first * 3, #lines())
		_G.SlashCmdList.MASTERANGLER(nil)
		assert.equals(first * 4, #lines())
	end)

	it("reports each failing command run without raising", function()
		ns.Commands.Register("boom", function()
			error("boom")
		end, "HELP_HELP")
		assert.has_no.errors(function()
			_G.SlashCmdList.MASTERANGLER("boom")
			_G.SlashCmdList.MASTERANGLER("BOOM")
		end)
		assert.equals(2, #lines())
		assert.is_truthy(lines()[1]:find(ns.L.COMMAND_FAILED, 1, true))
	end)

	it("lists the commands in registration order", function()
		ns.Commands.Register("zeta", function() end, "HELP_HELP")
		ns.Commands.Register("alpha", function() end, "HELP_HELP")
		ns.Commands.PrintHelp()
		local text = table.concat(lines(), "\n")
		local help = text:find("masterangler help", 1, true)
		local zeta = text:find("masterangler zeta", 1, true)
		local alpha = text:find("masterangler alpha", 1, true)
		assert.is_true(help < zeta and zeta < alpha)
		assert.is_truthy(lines()[1]:find("Commands:", 1, true))
	end)
end)
