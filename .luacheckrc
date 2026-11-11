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
	"C_Timer",
	"ClearCursor",
	"CreateFrame",
	"CursorHasItem",
	"DEFAULT_CHAT_FRAME",
	"Enum",
	"GetCVar",
	"GetGameTime",
	"GetInventoryItemLink",
	"GetItemCount",
	"GetLocale",
	"GetMouseFoci",
	"GetNormalizedRealmName",
	"GetServerTime",
	"InCombatLockdown",
	"PickupInventoryItem",
	"PutItemInBackpack",
	"PutItemInBag",
	"Settings",
	"SetCVar",
	"UnitName",
	"WorldFrame",
	"issecretvalue",
}
