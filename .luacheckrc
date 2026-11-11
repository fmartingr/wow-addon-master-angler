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
	"C_Container",
	"C_Item",
	"C_Map",
	"C_PaperDollInfo",
	"C_SpellBook",
	"C_Timer",
	"ClearCursor",
	"ClearOverrideBindings",
	"CreateFrame",
	"CursorHasItem",
	"DEFAULT_CHAT_FRAME",
	"Enum",
	"GameTooltip",
	"GetBindingKey",
	"GetCVar",
	"GetGameTime",
	"GetInventoryItemID",
	"GetInventoryItemLink",
	"GetItemCount",
	"GetLocale",
	"GetLootSlotInfo",
	"GetLootSlotLink",
	"GetMouseFoci",
	"GetNormalizedRealmName",
	"GetNumLootItems",
	"GetServerTime",
	"GetTime",
	"GetWeaponEnchantInfo",
	"InCombatLockdown",
	"IsFishingLoot",
	"IsMouselooking",
	"IsPlayerSpell",
	"LibStub",
	"MouselookStop",
	"PickupInventoryItem",
	"PutItemInBackpack",
	"PutItemInBag",
	"SetCVar",
	"SetOverrideBindingClick",
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
