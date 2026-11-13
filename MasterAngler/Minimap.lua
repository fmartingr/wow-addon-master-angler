local _, ns = ...

ns.Minimap = {}
local Minimap = ns.Minimap

local OBJECT_NAME = "MasterAngler"
local ICON_ITEM_ID = 6533
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

function Minimap.OnTooltipShow(tooltip)
	local L = ns.L
	tooltip:AddLine(L.TITLE)
	-- Read-only mode hides the character data, so a count of zero would be false.
	tooltip:AddLine(ns.readOnly and L.DB_NEWER or string.format(L.STATS, ns.Catches.Stats()), 1, 1, 1)
	tooltip:AddLine(L.HINT_LEFT, 0.8, 0.8, 0.8)
	tooltip:AddLine(L.HINT_DRAG, 0.8, 0.8, 0.8)
end

function Minimap.OnClick(_, button)
	if button == "LeftButton" and not pcall(ns.Window.Toggle) then
		ns.Print(ns.L.COMMAND_FAILED)
	end
end

-- LibDBIcon writes the position and lock into its table, so read-only mode hands it a session copy.
function Minimap.IconDB()
	local saved = type(MasterAnglerDB) == "table" and MasterAnglerDB.minimap
	if not ns.readOnly then
		return saved
	end
	local copy = {}
	if type(saved) == "table" then
		copy.hide = saved.hide == true
		copy.minimapPos = type(saved.minimapPos) == "number" and saved.minimapPos or nil
	end
	return copy
end

function Minimap.Register()
	if type(LibStub) ~= "function" and type(LibStub) ~= "table" then
		return false
	end
	local ldb = LibStub("LibDataBroker-1.1", true)
	local icon = LibStub("LibDBIcon-1.0", true)
	if not ldb or not icon then
		return false
	end
	local texture = C_Item and ns.Safe(C_Item.GetItemIconByID, ICON_ITEM_ID)
	local object = ldb:NewDataObject(OBJECT_NAME, {
		type = "launcher",
		icon = texture or FALLBACK_ICON,
		OnClick = Minimap.OnClick,
		OnTooltipShow = Minimap.OnTooltipShow,
	})
	Minimap.icon = icon
	icon:Register(OBJECT_NAME, object, Minimap.IconDB())
	return true
end

-- Read-only mode keeps the saved flag and only shows or hides the button for the session.
function Minimap.Apply(shown)
	if type(MasterAnglerDB) == "table" and not ns.readOnly then
		MasterAnglerDB.minimap.hide = not shown
	end
	if Minimap.icon then
		if shown then
			Minimap.icon:Show(OBJECT_NAME)
		else
			Minimap.icon:Hide(OBJECT_NAME)
		end
	end
end

function Minimap.Toggle()
	if ns.readOnly then
		ns.Print(ns.L.DB_NEWER)
		return
	end
	local shown = MasterAnglerDB.minimap.hide == true
	ns.Settings.Set("minimap", shown)
	ns.Print(shown and ns.L.MINIMAP_SHOWN or ns.L.MINIMAP_HIDDEN)
end

ns.On("ADDON_LOADED", function(_, name)
	if name == "MasterAngler" and not ns.readOnly then
		MasterAnglerDB.settings.minimap = not MasterAnglerDB.minimap.hide
	end
end)
ns.Settings.AddToggle("minimap", "SET_MINIMAP", "SET_MINIMAP_TIP", true)
ns.Settings.OnChange("minimap", Minimap.Apply)
ns.Commands.Register("minimap", Minimap.Toggle, "HELP_MINIMAP")
table.insert(ns.startup, Minimap.Register)
