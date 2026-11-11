local wow = require("spec.helpers.wow")

describe("CVars", function()
	local ns
	before_each(function()
		ns = wow.boot()
		_G.MasterAnglerDB = nil
		ns.InitDB()
		wow.cvars.A = "1"
		wow.cvars.B = "5"
	end)
	after_each(function()
		wow.restore()
	end)

	it("Apply backs up once, also across two calls", function()
		ns.CVars.Apply("g", { A = "0", B = "9" })
		ns.CVars.Apply("g", { A = "0", B = "9" })
		assert.equals("0", wow.cvars.A)
		assert.equals("9", wow.cvars.B)
		assert.same({ A = "1", B = "5" }, MasterAnglerDB.cvarBackup.g)
		assert.is_true(ns.CVars.HasBackup("g"))
		assert.is_false(ns.CVars.HasBackup("other"))
	end)

	it("Restore sets the backed-up values and clears the group", function()
		ns.CVars.Apply("g", { A = "0", B = "9" })
		ns.CVars.Restore("g")
		assert.equals("1", wow.cvars.A)
		assert.equals("5", wow.cvars.B)
		assert.is_nil(MasterAnglerDB.cvarBackup)
		assert.is_false(ns.CVars.HasBackup("g"))
	end)

	it("Restore keeps the other groups", function()
		ns.CVars.Apply("g", { A = "0" })
		ns.CVars.Apply("h", { B = "9" })
		ns.CVars.Restore("g")
		assert.is_true(ns.CVars.HasBackup("h"))
		assert.is_false(ns.CVars.HasBackup("g"))
	end)

	it("Restore without a backup does nothing", function()
		ns.CVars.Restore("g")
		assert.equals(0, #wow.cvarWrites)
		assert.is_nil(MasterAnglerDB.cvarBackup)
	end)

	it("a nil GetCVar is skipped", function()
		ns.CVars.Apply("g", { Unknown = "1" })
		assert.equals(0, #wow.cvarWrites)
		assert.is_nil(MasterAnglerDB.cvarBackup)
	end)

	it("a failing SetCVar is reported once and leaves no backup for it", function()
		wow.cvarFail.A = true
		ns.CVars.Apply("g", { A = "0", B = "9" })
		ns.CVars.Apply("g", { A = "0" })
		assert.is_nil(MasterAnglerDB.cvarBackup.g.A)
		assert.equals("5", MasterAnglerDB.cvarBackup.g.B)
		assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
	end)

	it("a failing SetCVar on a later apply and on restore is reported once", function()
		ns.CVars.Apply("g", { A = "0" })
		wow.cvarFail.A = true
		wow.cvars.A = "7"
		ns.CVars.Apply("g", { A = "0" })
		ns.CVars.Restore("g")
		assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
	end)

	it("a failed restore keeps the backup, and the next restore retries it", function()
		ns.CVars.Apply("g", { A = "0", B = "9" })
		wow.cvarFail.A = true
		ns.CVars.Restore("g")
		assert.equals("5", wow.cvars.B)
		assert.same({ A = "1" }, MasterAnglerDB.cvarBackup.g)
		wow.cvarFail.A = nil
		ns.CVars.Restore("g")
		assert.equals("1", wow.cvars.A)
		assert.is_nil(MasterAnglerDB.cvarBackup)
	end)

	it("a SetCVar that returns false counts as a failure", function()
		_G.SetCVar = function()
			return false
		end
		ns.CVars.Apply("g", { A = "0" })
		assert.is_nil(MasterAnglerDB.cvarBackup)
		assert.equals(1, #_G.DEFAULT_CHAT_FRAME.lines)
	end)

	it("Apply writes only the values that differ", function()
		ns.CVars.Apply("g", { A = "1", B = "9" })
		ns.CVars.Apply("g", { A = "1", B = "9" })
		assert.same({ { "B", "9" } }, wow.cvarWrites)
		assert.same({ A = "1", B = "5" }, MasterAnglerDB.cvarBackup.g)
	end)

	it("Restore writes only the values that differ", function()
		ns.CVars.Apply("g", { A = "0", B = "9" })
		wow.cvars.B = "5"
		wow.cvarWrites = {}
		ns.CVars.Restore("g")
		assert.same({ { "A", "1" } }, wow.cvarWrites)
		assert.is_nil(MasterAnglerDB.cvarBackup)
	end)

	it("does nothing in read-only mode or without a DB", function()
		ns.readOnly = true
		ns.CVars.Apply("g", { A = "0" })
		ns.CVars.Restore("g")
		assert.equals(0, #wow.cvarWrites)
		ns.readOnly = false
		_G.MasterAnglerDB = nil
		ns.CVars.Apply("g", { A = "0" })
		ns.CVars.Restore("g")
		assert.is_false(ns.CVars.HasBackup("g"))
		assert.equals(0, #wow.cvarWrites)
	end)
end)
