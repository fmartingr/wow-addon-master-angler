local _, ns = ...

ns.Sound = {}
local Sound = ns.Sound

Sound.GROUP = "sound"
Sound.PROFILE = {
	Sound_EnableAllSound = "1",
	Sound_EnableSFX = "1",
	Sound_SFXVolume = "1",
	Sound_MusicVolume = "0",
	Sound_AmbienceVolume = "0",
	Sound_DialogVolume = "0",
	Sound_EnableSoundWhenGameIsInBG = "1",
}

function Sound.Update()
	if ns.Mode.IsOn() and ns.Settings.Get("sound") then
		ns.CVars.Apply(Sound.GROUP, Sound.PROFILE)
	else
		ns.CVars.Restore(Sound.GROUP)
	end
end

ns.Settings.AddToggle("sound", "SET_SOUND", "SET_SOUND_TIP", true)
ns.Settings.OnChange("sound", Sound.Update)
ns.Mode.Subscribe(Sound.Update)
table.insert(ns.startup, Sound.Update)
