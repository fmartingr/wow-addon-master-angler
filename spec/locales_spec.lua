local wow = require("spec.helpers.wow")

local LOCALES = { "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR" }

describe("Locales", function()
	after_each(function()
		wow.restore()
	end)

	it("has every enUS key in every locale", function()
		local ns = wow.boot()
		for _, locale in ipairs(LOCALES) do
			assert.is_table(ns.locales[locale], locale)
			for key in pairs(ns.locales.enUS) do
				assert.is_string(ns.locales[locale][key], locale .. "." .. key)
			end
		end
	end)

	it("has no extra keys in a locale", function()
		local ns = wow.boot()
		for _, locale in ipairs(LOCALES) do
			for key in pairs(ns.locales[locale]) do
				assert.is_string(ns.locales.enUS[key], locale .. "." .. key)
			end
		end
	end)

	it("keeps the format specifiers of enUS", function()
		local ns = wow.boot()
		local function specs(text)
			local found = {}
			for spec in text:gmatch("%%[%d%.]*[sdf]") do
				found[#found + 1] = spec
			end
			return table.concat(found, ",")
		end
		for _, locale in ipairs(LOCALES) do
			for key, text in pairs(ns.locales.enUS) do
				assert.equals(specs(text), specs(ns.locales[locale][key]), locale .. "." .. key)
			end
		end
	end)

	describe("with the deDE client", function()
		wow.pin_locale("deDE", before_each, after_each)

		it("uses the client locale", function()
			local ns = wow.boot()
			assert.equals(ns.locales.deDE.HELP_HEADER, ns.L.HELP_HEADER)
		end)
	end)

	describe("with an unknown client locale", function()
		wow.pin_locale("koKR", before_each, after_each)

		it("falls back to enUS", function()
			local ns = wow.boot()
			assert.equals("Commands:", ns.L.HELP_HEADER)
		end)
	end)

	it("falls back to the key for an unknown key and reports it in debug mode", function()
		local ns = wow.boot()
		assert.equals("NOPE", ns.L.NOPE)
		ns.debug = true
		assert.equals("NOPE", ns.L.NOPE)
		assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
	end)

	describe("with a missing key in the client locale", function()
		wow.pin_locale("frFR", before_each, after_each)

		it("falls back to enUS for that key", function()
			local ns = wow.boot()
			ns.locales.frFR.HELP_HELP = nil
			assert.equals(ns.locales.enUS.HELP_HELP, ns.L.HELP_HELP)
		end)
	end)
end)
