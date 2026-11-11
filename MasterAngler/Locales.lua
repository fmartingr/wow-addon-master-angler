local _, ns = ...

ns.locales = {}
local locales = ns.locales

locales.enUS = {
	TITLE = "Master Angler",
	HELP_HEADER = "Commands:",
	HELP_HELP = "show this list",
	HOOK_FAILED = "A feature could not start. Some functions can be missing.",
	COMMAND_FAILED = "The command failed. Some functions can be missing.",
	DB_NEWER = "The saved data comes from a newer version. Master Angler does not save changes.",
	SETTINGS_UNAVAILABLE = "The settings panel is not available on this client.",
}

locales.deDE = {
	TITLE = "Master Angler",
	HELP_HEADER = "Befehle:",
	HELP_HELP = "diese Liste anzeigen",
	HOOK_FAILED = "Eine Funktion konnte nicht starten. Einige Funktionen können fehlen.",
	COMMAND_FAILED = "Der Befehl ist fehlgeschlagen. Einige Funktionen können fehlen.",
	DB_NEWER = "Die gespeicherten Daten stammen von einer neueren Version. Master Angler speichert keine Änderungen.",
	SETTINGS_UNAVAILABLE = "Das Optionsfenster ist auf diesem Client nicht verfügbar.",
}

locales.esES = {
	TITLE = "Master Angler",
	HELP_HEADER = "Comandos:",
	HELP_HELP = "mostrar esta lista",
	HOOK_FAILED = "Una función no pudo iniciarse. Pueden faltar algunas funciones.",
	COMMAND_FAILED = "El comando ha fallado. Pueden faltar algunas funciones.",
	DB_NEWER = "Los datos guardados son de una versión más nueva. Master Angler no guarda cambios.",
	SETTINGS_UNAVAILABLE = "El panel de opciones no está disponible en este cliente.",
}

locales.frFR = {
	TITLE = "Master Angler",
	HELP_HEADER = "Commandes :",
	HELP_HELP = "afficher cette liste",
	HOOK_FAILED = "Une fonction n'a pas pu démarrer. Certaines fonctions peuvent manquer.",
	COMMAND_FAILED = "La commande a échoué. Certaines fonctions peuvent manquer.",
	DB_NEWER = "Les données viennent d'une version plus récente. Master Angler n'enregistre pas les changements.",
	SETTINGS_UNAVAILABLE = "Le panneau d'options n'est pas disponible sur ce client.",
}

locales.itIT = {
	TITLE = "Master Angler",
	HELP_HEADER = "Comandi:",
	HELP_HELP = "mostra questo elenco",
	HOOK_FAILED = "Una funzione non è partita. Alcune funzioni possono mancare.",
	COMMAND_FAILED = "Il comando non è riuscito. Alcune funzioni possono mancare.",
	DB_NEWER = "I dati salvati vengono da una versione più recente. Master Angler non salva le modifiche.",
	SETTINGS_UNAVAILABLE = "Il pannello delle opzioni non è disponibile su questo client.",
}

locales.ptBR = {
	TITLE = "Master Angler",
	HELP_HEADER = "Comandos:",
	HELP_HELP = "mostrar esta lista",
	HOOK_FAILED = "Um recurso não pôde iniciar. Algumas funções podem faltar.",
	COMMAND_FAILED = "O comando falhou. Algumas funções podem faltar.",
	DB_NEWER = "Os dados salvos vêm de uma versão mais nova. O Master Angler não salva alterações.",
	SETTINGS_UNAVAILABLE = "O painel de opções não está disponível neste cliente.",
}

locales.enGB = locales.enUS
locales.esMX = locales.esES

local active = locales[GetLocale()] or locales.enUS
local fallback = locales.enUS

ns.L = setmetatable({}, {
	__index = function(_, key)
		local text = active[key] or fallback[key]
		if text then
			return text
		end
		if ns.debug and ns.ReportOnce then
			ns.ReportOnce("missing-" .. tostring(key), "Missing text key: " .. tostring(key))
		end
		return tostring(key)
	end,
})
