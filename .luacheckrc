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
	"C_Container",
	"C_Item",
	"C_PaperDollInfo",
	"C_SpellBook",
	"C_Timer",
	"ClearCursor",
	"ClearOverrideBindings",
	"CreateFrame",
	"CursorHasItem",
	"DEFAULT_CHAT_FRAME",
	"Enum",
	"GetBindingKey",
	"GetCVar",
	"GetGameTime",
	"GetInventoryItemID",
	"GetInventoryItemLink",
	"GetItemCount",
	"GetLocale",
	"GetMouseFoci",
	"GetNormalizedRealmName",
	"GetServerTime",
	"GetTime",
	"GetWeaponEnchantInfo",
	"InCombatLockdown",
	"IsMouselooking",
	"IsPlayerSpell",
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
	"issecretvalue",
}

files["MasterAngler/Locales.lua"] = { max_line_length = false }
