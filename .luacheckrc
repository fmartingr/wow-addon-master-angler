std = "lua51"
max_line_length = 120
codes = true
exclude_files = { "MasterAngler/Libs/", ".lua/", ".luarocks/" }
ignore = { "212/self", "211/_.*", "212/_.*" }

globals = {
	"MasterAnglerDB",
	"SLASH_MASTERANGLER1",
	"SlashCmdList",
	"UISpecialFrames",
}

read_globals = {
	"ButtonFrameTemplate_HidePortrait",
	"C_Item",
	"C_Map",
	"C_PaperDollInfo",
	"C_Spell",
	"C_SpellBook",
	"C_Timer",
	"ClearOverrideBindings",
	"CreateFrame",
	"DEFAULT_CHAT_FRAME",
	"Enum",
	"GameTooltip",
	"GetBindingKey",
	"GetCVar",
	"GetGameTime",
	"GetInventoryItemID",
	"GetLocale",
	"GetLootSlotInfo",
	"GetLootSlotLink",
	"GetMouseFoci",
	"GetNormalizedRealmName",
	"GetNumLootItems",
	"GetServerTime",
	"GetSpellInfo",
	"GetTime",
	"GetWeaponEnchantInfo",
	"InCombatLockdown",
	"IsFishingLoot",
	"IsPlayerSpell",
	"LibStub",
	"SetCVar",
	"SetOverrideBinding",
	"SetOverrideBindingClick",
	"SetOverrideBindingSpell",
	"Settings",
	"UIParent",
	"UnitChannelInfo",
	"UnitExists",
	"UnitName",
	"WorldFrame",
	"date",
	"issecretvalue",
}

files["MasterAngler/Locales.lua"] = { max_line_length = false }
