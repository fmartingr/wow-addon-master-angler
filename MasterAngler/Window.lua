local _, ns = ...

ns.Window = {}
local Window = ns.Window

local FRAME_NAME = "MasterAnglerJournal"
local ROW_HEIGHT = 24
local ZONE_HEIGHT = 22
local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local GREY = { 0.6, 0.6, 0.6 }
local WHITE = { 1, 1, 1 }
local GOLD = { 1, 0.82, 0 }
local TIME_FORMAT = "%Y-%m-%d %H:%M"

local frame
local zoneButtons, itemRows = {}, {}
local requested = {}
local selected
local refreshQueued = false

local function zoneName(mapID)
	local info = ns.Safe(C_Map.GetMapInfo, mapID)
	if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
		return info.name
	end
	return string.format(ns.L.ZONE_UNKNOWN, mapID)
end

function Window.ItemName(itemID)
	local name = ns.Safe(C_Item.GetItemNameByID, itemID)
	if not name then
		if not requested[itemID] then
			requested[itemID] = true
			ns.Safe(C_Item.RequestLoadItemDataByID, itemID)
		end
		return "..."
	end
	return name
end

local function currentZone()
	local best = ns.Safe(C_Map.GetBestMapForUnit, "player")
	return ns.Catches.ZoneMap(best)
end

local function pickZone(zones)
	for _, zone in ipairs(zones) do
		if zone.mapID == selected then
			return selected
		end
	end
	local current = currentZone()
	for _, zone in ipairs(zones) do
		if zone.mapID == current then
			return current
		end
	end
	return zones[1] and zones[1].mapID or nil
end

function Window.BuildModel()
	-- A newer schema can have any shape, so read-only mode reads no character data.
	local chars = not ns.readOnly and type(MasterAnglerDB) == "table" and MasterAnglerDB.chars or nil
	local index = ns.Journal.Build(chars, ns.CharKey())
	local zones = index.zones
	for _, zone in ipairs(zones) do
		zone.name = zoneName(zone.mapID)
	end
	table.sort(zones, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.mapID < b.mapID
	end)
	selected = pickZone(zones)
	-- Build returns a fresh index on each call, so its entries serve as the rows.
	local rows = selected and index.pages[selected] or {}
	for _, row in ipairs(rows) do
		if row.mine then
			row.name = Window.ItemName(row.itemID)
			row.icon = ns.Safe(C_Item.GetItemIconByID, row.itemID) or QUESTION_ICON
		else
			row.name = "???"
			row.icon = QUESTION_ICON
		end
	end
	return { zones = zones, selected = selected, rows = rows, noCatches = #zones == 0 }
end

local function showTooltip(row)
	local entry = row.entry
	if not entry or not entry.mine then
		return
	end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:SetItemByID(entry.itemID)
	GameTooltip:AddLine(string.format(ns.L.TIP_COUNT, entry.count), 1, 1, 1)
	if entry.first > 0 then
		GameTooltip:AddLine(string.format(ns.L.TIP_FIRST, date(TIME_FORMAT, entry.first)), 0.8, 0.8, 0.8)
		GameTooltip:AddLine(string.format(ns.L.TIP_LAST, date(TIME_FORMAT, entry.last)), 0.8, 0.8, 0.8)
	end
	GameTooltip:Show()
end

-- Frame scripts and timers run outside ns.On, so an error here would repeat in the game's error frame.
local function safeRefresh()
	if not pcall(Window.Refresh) then
		ns.ReportOnce("window-refresh", ns.L.HOOK_FAILED)
	end
end

local function getZoneButton(index)
	local button = zoneButtons[index]
	if button then
		return button
	end
	button = CreateFrame("Button", nil, frame.zoneContent)
	button:SetSize(150, ZONE_HEIGHT)
	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	button.text:SetPoint("LEFT", button, "LEFT", 4, 0)
	button.text:SetWidth(142)
	button.text:SetJustifyH("LEFT")
	button.text:SetWordWrap(false)
	button:SetScript("OnClick", function(self)
		selected = self.mapID
		safeRefresh()
	end)
	zoneButtons[index] = button
	return button
end

local function getItemRow(index)
	local row = itemRows[index]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, frame.itemContent)
	row:SetSize(280, ROW_HEIGHT)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(20, 20)
	row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.name:SetWidth(190)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.count:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.count:SetJustifyH("RIGHT")
	row:SetScript("OnEnter", showTooltip)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	itemRows[index] = row
	return row
end

local function color(fontString, rgb)
	fontString:SetTextColor(rgb[1], rgb[2], rgb[3])
end

local function render()
	local model = Window.BuildModel()
	for i, zone in ipairs(model.zones) do
		local button = getZoneButton(i)
		button.mapID = zone.mapID
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", frame.zoneContent, "TOPLEFT", 0, -(i - 1) * ZONE_HEIGHT)
		button.text:SetText(string.format("%s (%d)", zone.name, zone.mine + zone.alts))
		color(button.text, zone.mapID == model.selected and GOLD or WHITE)
		button:Show()
	end
	for i = #model.zones + 1, #zoneButtons do
		zoneButtons[i]:Hide()
	end
	frame.zoneContent:SetHeight(math.max(#model.zones * ZONE_HEIGHT, 1))
	for i, entry in ipairs(model.rows) do
		local row = getItemRow(i)
		row.entry = entry
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", frame.itemContent, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
		row.icon:SetTexture(entry.icon)
		row.name:SetText(entry.name)
		row.count:SetText(entry.mine and entry.count or "")
		color(row.name, entry.mine and WHITE or GREY)
		color(row.count, WHITE)
		row:Show()
		-- A redraw under the mouse can put another item on the hovered row.
		if GameTooltip:IsShown() and GameTooltip:IsOwned(row) then
			GameTooltip:Hide()
			showTooltip(row)
		end
	end
	for i = #model.rows + 1, #itemRows do
		itemRows[i]:Hide()
	end
	frame.itemContent:SetHeight(math.max(#model.rows * ROW_HEIGHT, 1))
	local emptyText = ns.readOnly and ns.L.DB_NEWER or ns.L.JOURNAL_EMPTY
	frame.empty:SetText(model.noCatches and emptyText or "")
	frame.model = model
	return model
end

local function createFrame()
	local ok, created = pcall(CreateFrame, "Frame", FRAME_NAME, UIParent, "ButtonFrameTemplate")
	if not ok or not created then
		created = CreateFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
	end
	return created
end

local function buildLayout(window)
	local zoneScroll = CreateFrame("ScrollFrame", FRAME_NAME .. "ZoneScroll", window, "UIPanelScrollFrameTemplate")
	zoneScroll:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -64)
	zoneScroll:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 12, 12)
	-- The template scroll bar sits 6 to 22 px right of the scroll frame and must end before the item list.
	zoneScroll:SetWidth(160)
	window.zoneContent = CreateFrame("Frame", nil, zoneScroll)
	window.zoneContent:SetSize(150, 1)
	zoneScroll:SetScrollChild(window.zoneContent)

	local itemScroll = CreateFrame("ScrollFrame", FRAME_NAME .. "ItemScroll", window, "UIPanelScrollFrameTemplate")
	itemScroll:SetPoint("TOPLEFT", window, "TOPLEFT", 196, -64)
	itemScroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -32, 12)
	window.itemContent = CreateFrame("Frame", nil, itemScroll)
	window.itemContent:SetSize(280, 1)
	itemScroll:SetScrollChild(window.itemContent)

	window.empty = window:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	window.empty:SetPoint("TOP", window, "TOP", 90, -90)
end

-- Loot and item-data events come in bursts, so the redraws of one frame run once.
local function queueRefresh()
	if refreshQueued or not frame or not frame:IsShown() then
		return
	end
	refreshQueued = true
	C_Timer.After(0, function()
		refreshQueued = false
		safeRefresh()
	end)
end

-- The module keeps the frame only once it is complete, so a failed build is retried instead of reused.
function Window.Create()
	if frame then
		return frame
	end
	local window = createFrame()
	window:Hide()
	window:SetSize(520, 440)
	window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", window.StopMovingOrSizing)
	if ButtonFrameTemplate_HidePortrait then
		pcall(ButtonFrameTemplate_HidePortrait, window)
	end
	if window.SetTitle then
		window:SetTitle(ns.L.TITLE)
	elseif window.TitleText then
		window.TitleText:SetText(ns.L.TITLE)
	end
	local found = false
	for _, name in ipairs(UISpecialFrames) do
		found = found or name == FRAME_NAME
	end
	if not found then
		table.insert(UISpecialFrames, FRAME_NAME)
	end
	buildLayout(window)
	pcall(window.RegisterEvent, window, "GET_ITEM_INFO_RECEIVED")
	-- The event fires for every item the client loads, so only a name this window asked for redraws it, once.
	-- The entry stays in the table so ItemName never asks for the same item again.
	window:SetScript("OnEvent", function(_, _, itemID)
		if requested[itemID] == true then
			requested[itemID] = "loaded"
			queueRefresh()
		end
	end)
	window:SetScript("OnShow", function()
		selected = nil
		safeRefresh()
	end)
	frame = window
	return frame
end

function Window.Refresh()
	if not frame or not frame:IsShown() then
		return false
	end
	render()
	return true
end

function Window.Select(mapID)
	selected = mapID
	return Window.Refresh()
end

function Window.Toggle()
	local window = Window.Create()
	if window:IsShown() then
		window:Hide()
	else
		window:Show()
	end
end

function Window.Reset()
	frame = nil
	zoneButtons, itemRows = {}, {}
	requested = {}
	selected = nil
	refreshQueued = false
end

ns.Catches.Subscribe(queueRefresh)
ns.Commands.Register("journal", Window.Toggle, "HELP_JOURNAL")
