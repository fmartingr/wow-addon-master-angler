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
	GEAR_SAVED = "Fishing set saved: %d items.",
	NO_GEAR_SAVED = "No fishing set saved. Wear your fishing gear and use /masterangler savegear.",
	SWAP_AFTER_COMBAT = "In combat. The gear swap runs when combat ends.",
	SWAP_CANCELLED = "The pending gear swap is cancelled.",
	MODE_ON = "Fishing mode on.",
	MODE_OFF = "Fishing mode off.",
	GEAR_MISSING = "Not in your bags: %s",
	BAGS_FULL = "Bags are full. %s stays equipped.",
	HELP_SAVEGEAR = "save the worn gear as the fishing set",
	HELP_MODE = "turn fishing mode on or off",
	SET_SOUND = "Sound profile in fishing mode",
	SET_SOUND_TIP = "Mutes music, ambience and dialog and raises effects while fishing mode is on. The old values return when it ends.",
	CVAR_FAILED = "The game did not accept the setting %s.",
	SET_DOUBLECLICK = "Double right-click casts",
	SET_DOUBLECLICK_TIP = "A double right-click on the game world applies a lure or casts Fishing. It works only with fishing mode on or a fishing pole in hand, and out of combat.",
	SET_AUTOLURE = "Auto-lure",
	SET_AUTOLURE_TIP = "Applies the strongest lure from your bags when the pole has none or less than 30 seconds left.",
}

locales.deDE = {
	TITLE = "Master Angler",
	HELP_HEADER = "Befehle:",
	HELP_HELP = "diese Liste anzeigen",
	HOOK_FAILED = "Eine Funktion konnte nicht starten. Einige Funktionen können fehlen.",
	COMMAND_FAILED = "Der Befehl ist fehlgeschlagen. Einige Funktionen können fehlen.",
	DB_NEWER = "Die gespeicherten Daten stammen von einer neueren Version. Master Angler speichert keine Änderungen.",
	SETTINGS_UNAVAILABLE = "Das Optionsfenster ist auf diesem Client nicht verfügbar.",
	GEAR_SAVED = "Angelset gespeichert: %d Gegenstände.",
	NO_GEAR_SAVED = "Kein Angelset gespeichert. Lege die Angelausrüstung an und nutze /masterangler savegear.",
	SWAP_AFTER_COMBAT = "Im Kampf. Der Ausrüstungswechsel erfolgt nach dem Kampf.",
	SWAP_CANCELLED = "Der ausstehende Ausrüstungswechsel ist abgebrochen.",
	MODE_ON = "Angelmodus an.",
	MODE_OFF = "Angelmodus aus.",
	GEAR_MISSING = "Nicht in deinen Taschen: %s",
	BAGS_FULL = "Taschen voll. %s bleibt angelegt.",
	HELP_SAVEGEAR = "getragene Ausrüstung als Angelset speichern",
	HELP_MODE = "Angelmodus ein- oder ausschalten",
	SET_SOUND = "Soundprofil im Angelmodus",
	SET_SOUND_TIP = "Schaltet Musik, Umgebung und Dialoge stumm und erhöht Effekte im Angelmodus. Die alten Werte kommen danach zurück.",
	CVAR_FAILED = "Das Spiel hat die Einstellung %s nicht akzeptiert.",
	SET_DOUBLECLICK = "Doppelter Rechtsklick wirft aus",
	SET_DOUBLECLICK_TIP = "Ein doppelter Rechtsklick auf die Spielwelt trägt einen Köder auf oder wirft Angeln aus. Nur mit Angelmodus oder Angel in der Hand und außerhalb des Kampfes.",
	SET_AUTOLURE = "Automatischer Köder",
	SET_AUTOLURE_TIP = "Trägt den stärksten Köder aus deinen Taschen auf, wenn die Angel keinen oder weniger als 30 Sekunden hat.",
}

locales.esES = {
	TITLE = "Master Angler",
	HELP_HEADER = "Comandos:",
	HELP_HELP = "mostrar esta lista",
	HOOK_FAILED = "Una función no pudo iniciarse. Pueden faltar algunas funciones.",
	COMMAND_FAILED = "El comando ha fallado. Pueden faltar algunas funciones.",
	DB_NEWER = "Los datos guardados son de una versión más nueva. Master Angler no guarda cambios.",
	SETTINGS_UNAVAILABLE = "El panel de opciones no está disponible en este cliente.",
	GEAR_SAVED = "Equipo de pesca guardado: %d objetos.",
	NO_GEAR_SAVED = "No hay equipo de pesca guardado. Equipa tu ropa de pesca y usa /masterangler savegear.",
	SWAP_AFTER_COMBAT = "En combate. El cambio de equipo se hará al terminar el combate.",
	SWAP_CANCELLED = "El cambio de equipo pendiente se ha cancelado.",
	MODE_ON = "Modo pesca activado.",
	MODE_OFF = "Modo pesca desactivado.",
	GEAR_MISSING = "No está en tus bolsas: %s",
	BAGS_FULL = "Bolsas llenas. %s sigue equipado.",
	HELP_SAVEGEAR = "guardar el equipo puesto como equipo de pesca",
	HELP_MODE = "activar o desactivar el modo pesca",
	SET_SOUND = "Perfil de sonido en modo pesca",
	SET_SOUND_TIP = "Silencia música, ambiente y diálogos y sube los efectos mientras el modo pesca está activo. Los valores anteriores vuelven al terminar.",
	CVAR_FAILED = "El juego no aceptó el ajuste %s.",
	SET_DOUBLECLICK = "Doble clic derecho lanza",
	SET_DOUBLECLICK_TIP = "Un doble clic derecho en el mundo aplica un cebo o lanza Pesca. Solo con el modo pesca activo o una caña en la mano, y fuera de combate.",
	SET_AUTOLURE = "Cebo automático",
	SET_AUTOLURE_TIP = "Aplica el mejor cebo de tus bolsas cuando la caña no tiene o le quedan menos de 30 segundos.",
}

locales.frFR = {
	TITLE = "Master Angler",
	HELP_HEADER = "Commandes :",
	HELP_HELP = "afficher cette liste",
	HOOK_FAILED = "Une fonction n'a pas pu démarrer. Certaines fonctions peuvent manquer.",
	COMMAND_FAILED = "La commande a échoué. Certaines fonctions peuvent manquer.",
	DB_NEWER = "Les données viennent d'une version plus récente. Master Angler n'enregistre pas les changements.",
	SETTINGS_UNAVAILABLE = "Le panneau d'options n'est pas disponible sur ce client.",
	GEAR_SAVED = "Équipement de pêche enregistré : %d objets.",
	NO_GEAR_SAVED = "Aucun équipement de pêche enregistré. Équipez-le et utilisez /masterangler savegear.",
	SWAP_AFTER_COMBAT = "En combat. Le changement d'équipement aura lieu après le combat.",
	SWAP_CANCELLED = "Le changement d'équipement en attente est annulé.",
	MODE_ON = "Mode pêche activé.",
	MODE_OFF = "Mode pêche désactivé.",
	GEAR_MISSING = "Pas dans vos sacs : %s",
	BAGS_FULL = "Sacs pleins. %s reste équipé.",
	HELP_SAVEGEAR = "enregistrer l'équipement porté comme équipement de pêche",
	HELP_MODE = "activer ou désactiver le mode pêche",
	SET_SOUND = "Profil sonore en mode pêche",
	SET_SOUND_TIP = "Coupe la musique, l'ambiance et les dialogues et monte les effets en mode pêche. Les anciennes valeurs reviennent ensuite.",
	CVAR_FAILED = "Le jeu a refusé le réglage %s.",
	SET_DOUBLECLICK = "Double clic droit pour lancer",
	SET_DOUBLECLICK_TIP = "Un double clic droit sur le monde applique un appât ou lance Pêche. Seulement en mode pêche ou avec une canne en main, hors combat.",
	SET_AUTOLURE = "Appât automatique",
	SET_AUTOLURE_TIP = "Applique le meilleur appât de vos sacs quand la canne n'en a pas ou qu'il reste moins de 30 secondes.",
}

locales.itIT = {
	TITLE = "Master Angler",
	HELP_HEADER = "Comandi:",
	HELP_HELP = "mostra questo elenco",
	HOOK_FAILED = "Una funzione non è partita. Alcune funzioni possono mancare.",
	COMMAND_FAILED = "Il comando non è riuscito. Alcune funzioni possono mancare.",
	DB_NEWER = "I dati salvati vengono da una versione più recente. Master Angler non salva le modifiche.",
	SETTINGS_UNAVAILABLE = "Il pannello delle opzioni non è disponibile su questo client.",
	GEAR_SAVED = "Set da pesca salvato: %d oggetti.",
	NO_GEAR_SAVED = "Nessun set da pesca salvato. Indossa l'equipaggiamento e usa /masterangler savegear.",
	SWAP_AFTER_COMBAT = "In combattimento. Il cambio di equipaggiamento avverrà a fine combattimento.",
	SWAP_CANCELLED = "Il cambio di equipaggiamento in attesa è annullato.",
	MODE_ON = "Modalità pesca attivata.",
	MODE_OFF = "Modalità pesca disattivata.",
	GEAR_MISSING = "Non è nelle tue borse: %s",
	BAGS_FULL = "Borse piene. %s resta equipaggiato.",
	HELP_SAVEGEAR = "salva l'equipaggiamento indossato come set da pesca",
	HELP_MODE = "attiva o disattiva la modalità pesca",
	SET_SOUND = "Profilo audio in modalità pesca",
	SET_SOUND_TIP = "Silenzia musica, ambiente e dialoghi e alza gli effetti in modalità pesca. I vecchi valori tornano alla fine.",
	CVAR_FAILED = "Il gioco non ha accettato l'impostazione %s.",
	SET_DOUBLECLICK = "Doppio clic destro lancia",
	SET_DOUBLECLICK_TIP = "Un doppio clic destro sul mondo applica un'esca o lancia Pesca. Solo in modalità pesca o con una canna in mano, fuori combattimento.",
	SET_AUTOLURE = "Esca automatica",
	SET_AUTOLURE_TIP = "Applica l'esca migliore dalle tue borse quando la canna non ne ha o restano meno di 30 secondi.",
}

locales.ptBR = {
	TITLE = "Master Angler",
	HELP_HEADER = "Comandos:",
	HELP_HELP = "mostrar esta lista",
	HOOK_FAILED = "Um recurso não pôde iniciar. Algumas funções podem faltar.",
	COMMAND_FAILED = "O comando falhou. Algumas funções podem faltar.",
	DB_NEWER = "Os dados salvos vêm de uma versão mais nova. O Master Angler não salva alterações.",
	SETTINGS_UNAVAILABLE = "O painel de opções não está disponível neste cliente.",
	GEAR_SAVED = "Conjunto de pesca salvo: %d itens.",
	NO_GEAR_SAVED = "Nenhum conjunto de pesca salvo. Vista o equipamento e use /masterangler savegear.",
	SWAP_AFTER_COMBAT = "Em combate. A troca de equipamento ocorre quando o combate acabar.",
	SWAP_CANCELLED = "A troca de equipamento pendente foi cancelada.",
	MODE_ON = "Modo de pesca ligado.",
	MODE_OFF = "Modo de pesca desligado.",
	GEAR_MISSING = "Não está nas suas bolsas: %s",
	BAGS_FULL = "Bolsas cheias. %s continua equipado.",
	HELP_SAVEGEAR = "salvar o equipamento vestido como conjunto de pesca",
	HELP_MODE = "ligar ou desligar o modo de pesca",
	SET_SOUND = "Perfil de som no modo de pesca",
	SET_SOUND_TIP = "Silencia música, ambiente e diálogos e aumenta os efeitos no modo de pesca. Os valores antigos voltam ao terminar.",
	CVAR_FAILED = "O jogo não aceitou a configuração %s.",
	SET_DOUBLECLICK = "Clique direito duplo lança",
	SET_DOUBLECLICK_TIP = "Um clique direito duplo no mundo aplica uma isca ou lança Pesca. Só com o modo de pesca ligado ou uma vara na mão, fora de combate.",
	SET_AUTOLURE = "Isca automática",
	SET_AUTOLURE_TIP = "Aplica a melhor isca das suas bolsas quando a vara não tem ou restam menos de 30 segundos.",
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
