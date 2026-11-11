local wow = require("spec.helpers.wow")

local function listLuaFiles()
	local p = io.popen("ls MasterAngler/*.lua")
	local files = {}
	for line in p:lines() do
		files[#files + 1] = line:gsub("^MasterAngler/", "")
	end
	p:close()
	return files
end

local function exists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
	end
	return f ~= nil
end

describe("TOC", function()
	local toc
	setup(function()
		local f = assert(io.open("MasterAngler/MasterAngler.toc", "r"))
		toc = f:read("*a")
		f:close()
	end)

	it("targets Forever", function()
		assert.is_truthy(toc:find("## Interface: 16001", 1, true))
		assert.is_truthy(toc:find("## AllowLoadGameType: camelot", 1, true))
	end)

	it("declares the saved variable", function()
		assert.is_truthy(toc:find("## SavedVariables: MasterAnglerDB", 1, true))
	end)

	it("lists only files that exist", function()
		for _, name in ipairs(wow.readToc()) do
			assert.is_true(exists("MasterAngler/" .. name), name)
		end
	end)

	it("lists every addon Lua file", function()
		local listed = {}
		for _, name in ipairs(wow.readToc()) do
			listed[name] = true
		end
		for _, name in ipairs(listLuaFiles()) do
			assert.is_true(listed[name] == true, name)
		end
	end)

	it("lists every logic file in .luacov", function()
		local f = assert(io.open(".luacov", "r"))
		local luacov = f:read("*a")
		f:close()
		for _, name in ipairs(listLuaFiles()) do
			local module = name:gsub("%.lua$", "")
			assert.is_truthy(luacov:find("MasterAngler/" .. module .. "$", 1, true), name)
		end
	end)
end)

describe("Version", function()
	it("matches the top CHANGELOG heading", function()
		local f = assert(io.open("MasterAngler/MasterAngler.toc", "r"))
		local version = f:read("*a"):match("## Version: ([^\r\n]+)")
		f:close()
		local c = assert(io.open("CHANGELOG.md", "r"))
		local heading = c:read("*a"):match("## ([%d%.]+)")
		c:close()
		assert.equals(version, heading)
	end)
end)
