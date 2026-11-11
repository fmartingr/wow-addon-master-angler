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
	"C_Timer",
	"CreateFrame",
	"DEFAULT_CHAT_FRAME",
	"Enum",
	"GetCVar",
	"GetGameTime",
	"GetLocale",
	"GetMouseFoci",
	"GetNormalizedRealmName",
	"GetServerTime",
	"InCombatLockdown",
	"Settings",
	"SetCVar",
	"UnitName",
	"WorldFrame",
	"issecretvalue",
}
