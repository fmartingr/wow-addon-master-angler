local wow = require("spec.helpers.wow")

describe("Sound", function()
	local ns
	local ORIGINAL = {
		Sound_EnableAllSound = "0",
		Sound_EnableSFX = "0",
		Sound_SFXVolume = "0.4",
		Sound_MusicVolume = "0.7",
		Sound_AmbienceVolume = "0.6",
		Sound_DialogVolume = "0.8",
		Sound_EnableSoundWhenGameIsInBG = "0",
	}

	local function login()
		ns.events.scripts.OnEvent(ns.events, "PLAYER_LOGIN")
	end

	before_each(function()
		ns = wow.boot()
		_G.MasterAnglerDB = nil
		ns.InitDB()
		for name, value in pairs(ORIGINAL) do
			wow.cvars[name] = value
		end
		ns.Char().gear = { [16] = wow.itemLink(1) }
	end)
	after_each(function()
		wow.restore()
	end)

	local function cvarsMatch(expected)
		for name, value in pairs(expected) do
			if wow.cvars[name] ~= value then
				return false
			end
		end
		return true
	end

	it("has the seven profile values of the spec", function()
		assert.same({
			Sound_EnableAllSound = "1",
			Sound_EnableSFX = "1",
			Sound_SFXVolume = "1",
			Sound_MusicVolume = "0",
			Sound_AmbienceVolume = "0",
			Sound_DialogVolume = "0",
			Sound_EnableSoundWhenGameIsInBG = "1",
		}, ns.Sound.PROFILE)
	end)

	it("mode on applies the profile and mode off restores", function()
		ns.Mode.Toggle()
		assert.is_true(cvarsMatch(ns.Sound.PROFILE))
		ns.Mode.Toggle()
		assert.is_true(cvarsMatch(ORIGINAL))
		assert.is_nil(MasterAnglerDB.cvarBackup)
	end)

	it("a login with a backup and mode off restores (crash recovery)", function()
		ns.Mode.Toggle()
		ns.Char().mode.on = false
		login()
		assert.is_true(cvarsMatch(ORIGINAL))
		assert.is_nil(MasterAnglerDB.cvarBackup)
	end)

	it("a login with mode on keeps the profile and the backup", function()
		ns.Mode.Toggle()
		local backup = MasterAnglerDB.cvarBackup.sound.Sound_MusicVolume
		login()
		assert.is_true(cvarsMatch(ns.Sound.PROFILE))
		assert.equals(backup, MasterAnglerDB.cvarBackup.sound.Sound_MusicVolume)
		assert.equals("0.7", backup)
	end)

	it("a login with mode on and no profile applies it (kill during the session)", function()
		ns.Mode.Toggle()
		for name, value in pairs(ORIGINAL) do
			wow.cvars[name] = value
		end
		MasterAnglerDB.cvarBackup = nil
		login()
		assert.is_true(cvarsMatch(ns.Sound.PROFILE))
	end)

	it("the setting off restores while the mode is on, and on applies again", function()
		ns.Mode.Toggle()
		ns.Settings.Set("sound", false)
		assert.is_true(cvarsMatch(ORIGINAL))
		ns.Settings.Set("sound", true)
		assert.is_true(cvarsMatch(ns.Sound.PROFILE))
	end)

	it("the setting off keeps the sound untouched on mode on", function()
		ns.Settings.Set("sound", false)
		ns.Mode.Toggle()
		assert.is_true(cvarsMatch(ORIGINAL))
		assert.equals(0, #wow.cvarWrites)
	end)

	it("the game checkbox callback runs Update", function()
		ns.Settings.Init()
		ns.Mode.Toggle()
		MasterAnglerDB.settings.sound = false
		for _, setting in ipairs(wow.settingsLog.settings) do
			if setting.key == "sound" then
				setting.callback(setting, false)
			end
		end
		assert.is_true(cvarsMatch(ORIGINAL))
	end)

	it("skips a CVar the client does not know", function()
		wow.cvars.Sound_DialogVolume = nil
		ns.Mode.Toggle()
		assert.is_nil(wow.cvars.Sound_DialogVolume)
		assert.equals("0", wow.cvars.Sound_MusicVolume)
	end)
end)
