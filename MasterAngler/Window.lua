local _, ns = ...

ns.Window = {}
local Window = ns.Window

local FRAME_NAME = "MasterAnglerJournal"
local COLUMNS = 4
local CELL_WIDTH = 146
local CELL_HEIGHT = 28
local ICON_SIZE = 22
local ZONE_ROW_HEIGHT = 20
local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local GREY = { 0.6, 0.6, 0.6 }
local WHITE = { 1, 1, 1 }
local TIME_FORMAT = "%Y-%m-%d %H:%M"
local UNCACHED_NAME = "..."

local frame
local cells, zoneRows = {}, {}
local requested = {}
local refreshQueued = false
local view = "list"
local detailItem
local search = ""

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
		return UNCACHED_NAME
	end
	return name
end

local function trim(text)
	return (tostring(text or ""):match("^%s*(.-)%s*$"))
end

local function sortKey(name)
	if name == UNCACHED_NAME then
		return "\255"
	end
	return name:lower()
end

local function rowFor(entry)
	local row =
		{ itemID = entry.itemID, mine = entry.mine, count = entry.count, first = entry.first, last = entry.last }
	if entry.mine then
		row.name = Window.ItemName(entry.itemID)
		row.icon = ns.Safe(C_Item.GetItemIconByID, entry.itemID) or QUESTION_ICON
	else
		row.name = "???"
		row.icon = QUESTION_ICON
	end
	return row
end

local function listRows(index, query)
	local mine, others = {}, {}
	for _, entry in ipairs(index.fish) do
		local row = rowFor(entry)
		if entry.mine then
			if query == "" or row.name:lower():find(query, 1, true) then
				mine[#mine + 1] = row
			end
		elseif query == "" then
			others[#others + 1] = row
		end
	end
	table.sort(mine, function(a, b)
		local left, right = sortKey(a.name), sortKey(b.name)
		if left ~= right then
			return left < right
		end
		return a.itemID < b.itemID
	end)
	for _, row in ipairs(others) do
		mine[#mine + 1] = row
	end
	return mine
end

local function detailModel(entry)
	local detail = rowFor(entry)
	detail.zones = {}
	for _, zone in ipairs(entry.zones) do
		detail.zones[#detail.zones + 1] =
			{ mapID = zone.mapID, name = zoneName(zone.mapID), count = zone.count, last = zone.last }
	end
	table.sort(detail.zones, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.mapID < b.mapID
	end)
	return detail
end

function Window.BuildModel()
	-- A newer schema can have any shape, so read-only mode reads no character data.
	local chars = not ns.readOnly and type(MasterAnglerDB) == "table" and MasterAnglerDB.chars or nil
	local index = ns.Journal.Build(chars, ns.CharKey())
	local query = trim(search):lower()
	local entry = detailItem and index.byItem[detailItem]
	if view == "detail" and not (entry and entry.mine) then
		view, detailItem = "list", nil
	end
	local model = { view = view, query = query, noCatches = #index.fish == 0 }
	if view == "detail" then
		model.detail = detailModel(entry)
	else
		model.rows = listRows(index, query)
		model.noMatches = not model.noCatches and query ~= "" and #model.rows == 0
	end
	return model
end

local function showTooltip(cell)
	local entry = cell.entry
	if not entry or not entry.mine then
		return
	end
	GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
	GameTooltip:SetItemByID(entry.itemID)
	GameTooltip:Show()
end

-- Frame scripts and timers run outside ns.On, so an error here would repeat in the game's error frame.
local function safeRefresh()
	if not pcall(Window.Refresh) then
		ns.ReportOnce("window-refresh", ns.L.HOOK_FAILED)
	end
end

local function color(fontString, rgb)
	fontString:SetTextColor(rgb[1], rgb[2], rgb[3])
end

local function getCell(index)
	local cell = cells[index]
	if cell then
		return cell
	end
	cell = CreateFrame("Button", nil, frame.listContent)
	cell:SetSize(CELL_WIDTH, CELL_HEIGHT)
	cell.icon = cell:CreateTexture(nil, "ARTWORK")
	cell.icon:SetSize(ICON_SIZE, ICON_SIZE)
	cell.icon:SetPoint("LEFT", cell, "LEFT", 4, 0)
	cell.name = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	cell.name:SetPoint("LEFT", cell.icon, "RIGHT", 6, 0)
	cell.name:SetWidth(CELL_WIDTH - ICON_SIZE - 16)
	cell.name:SetJustifyH("LEFT")
	cell.name:SetWordWrap(false)
	cell:SetScript("OnEnter", showTooltip)
	cell:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	cell:SetScript("OnClick", function(self)
		if self.entry and self.entry.mine then
			Window.ShowDetail(self.entry.itemID)
		end
	end)
	cells[index] = cell
	return cell
end

local function getZoneRow(index)
	local row = zoneRows[index]
	if row then
		return row
	end
	row = CreateFrame("Frame", nil, frame.detail.zoneContent)
	row:SetSize(360, ZONE_ROW_HEIGHT)
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.name:SetPoint("LEFT", row, "LEFT", 4, 0)
	row.name:SetWidth(230)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.last = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.last:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.last:SetJustifyH("RIGHT")
	zoneRows[index] = row
	return row
end

local function renderList(model)
	for i, entry in ipairs(model.rows) do
		local cell = getCell(i)
		local column, line = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
		cell.entry = entry
		cell:ClearAllPoints()
		cell:SetPoint("TOPLEFT", frame.listContent, "TOPLEFT", column * CELL_WIDTH, -line * CELL_HEIGHT)
		cell.icon:SetTexture(entry.icon)
		cell.name:SetText(entry.name)
		color(cell.name, entry.mine and WHITE or GREY)
		cell:Show()
		-- A redraw under the mouse can put another item on the hovered cell.
		if GameTooltip:IsShown() and GameTooltip:IsOwned(cell) then
			GameTooltip:Hide()
			showTooltip(cell)
		end
	end
	for i = #model.rows + 1, #cells do
		cells[i]:Hide()
	end
	frame.listContent:SetHeight(math.max(math.ceil(#model.rows / COLUMNS) * CELL_HEIGHT, 1))
	if model.noCatches then
		frame.empty:SetText(ns.readOnly and ns.L.DB_NEWER or ns.L.JOURNAL_EMPTY)
	elseif model.noMatches then
		frame.empty:SetText(ns.L.NO_MATCHES)
	else
		frame.empty:SetText("")
	end
end

local function renderDetail(model)
	local detail, panel = model.detail, frame.detail
	panel.icon:SetTexture(detail.icon)
	panel.name:SetText(detail.name)
	panel.count:SetText(string.format(ns.L.TIP_COUNT, detail.count))
	local hasTimes = detail.first > 0
	panel.first:SetText(hasTimes and string.format(ns.L.TIP_FIRST, date(TIME_FORMAT, detail.first)) or "")
	panel.last:SetText(hasTimes and string.format(ns.L.TIP_LAST, date(TIME_FORMAT, detail.last)) or "")
	for i, zone in ipairs(detail.zones) do
		local row = getZoneRow(i)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", panel.zoneContent, "TOPLEFT", 0, -(i - 1) * ZONE_ROW_HEIGHT)
		row.name:SetText(string.format(ns.L.DETAIL_ZONE, zone.name, zone.count))
		row.last:SetText(zone.last > 0 and date(TIME_FORMAT, zone.last) or "")
		row:Show()
	end
	for i = #detail.zones + 1, #zoneRows do
		zoneRows[i]:Hide()
	end
	panel.zoneContent:SetHeight(math.max(#detail.zones * ZONE_ROW_HEIGHT, 1))
end

local function render()
	local model = Window.BuildModel()
	local listing = model.view == "list"
	frame.search:SetShown(listing)
	frame.listScroll:SetShown(listing)
	frame.detail:SetShown(not listing)
	if listing then
		renderList(model)
	else
		frame.empty:SetText("")
		renderDetail(model)
	end
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

local function createSearch(window)
	local ok, box = pcall(CreateFrame, "EditBox", FRAME_NAME .. "Search", window, "SearchBoxTemplate")
	if not ok or not box then
		box = CreateFrame("EditBox", FRAME_NAME .. "Search", window, "InputBoxTemplate")
	end
	box:SetSize(220, 20)
	box:SetPoint("TOPLEFT", window, "TOPLEFT", 22, -38)
	box:SetAutoFocus(false)
	if box.Instructions then
		box.Instructions:SetText(ns.L.SEARCH)
	end
	box:SetScript("OnTextChanged", function(self)
		Window.SetSearch(self:GetText())
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	return box
end

local function createDetail(window)
	local panel = CreateFrame("Frame", nil, window)
	panel:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -34)
	panel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -12, 12)
	local back = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	back:SetSize(90, 22)
	back:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -2)
	back:SetText(ns.L.BACK)
	back:SetScript("OnClick", Window.Back)
	panel.back = back
	panel.icon = panel:CreateTexture(nil, "ARTWORK")
	panel.icon:SetSize(40, 40)
	panel.icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -36)
	panel.name = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	panel.name:SetPoint("LEFT", panel.icon, "RIGHT", 10, 0)
	panel.count = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	panel.count:SetPoint("TOPLEFT", panel.icon, "BOTTOMLEFT", 0, -10)
	panel.first = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	panel.first:SetPoint("TOPLEFT", panel.count, "BOTTOMLEFT", 0, -4)
	panel.last = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	panel.last:SetPoint("TOPLEFT", panel.first, "BOTTOMLEFT", 0, -4)
	local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header:SetPoint("TOPLEFT", panel.last, "BOTTOMLEFT", 0, -14)
	header:SetText(ns.L.DETAIL_SEEN_IN)
	local scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "ZoneScroll", panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
	scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 4)
	panel.zoneContent = CreateFrame("Frame", nil, scroll)
	panel.zoneContent:SetSize(360, 1)
	scroll:SetScrollChild(panel.zoneContent)
	panel:Hide()
	return panel
end

local function buildLayout(window)
	window.search = createSearch(window)
	window.listScroll = CreateFrame("ScrollFrame", FRAME_NAME .. "ListScroll", window, "UIPanelScrollFrameTemplate")
	window.listScroll:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -68)
	window.listScroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -32, 12)
	window.listContent = CreateFrame("Frame", nil, window.listScroll)
	window.listContent:SetSize(COLUMNS * CELL_WIDTH, 1)
	window.listScroll:SetScrollChild(window.listContent)
	window.empty = window:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	window.empty:SetPoint("TOP", window, "TOP", 0, -110)
	window.detail = createDetail(window)
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
	window:SetSize(640, 480)
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
		view, detailItem, search = "list", nil, ""
		window.search:SetText("")
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

function Window.SetSearch(text)
	local value = tostring(text or "")
	if value == search then
		return false
	end
	search = value
	if frame and frame.search:GetText() ~= value then
		frame.search:SetText(value)
	end
	return Window.Refresh()
end

function Window.ShowDetail(itemID)
	view, detailItem = "detail", itemID
	return Window.Refresh()
end

function Window.Back()
	view, detailItem = "list", nil
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
	cells, zoneRows = {}, {}
	requested = {}
	refreshQueued = false
	view, detailItem, search = "list", nil, ""
end

ns.Catches.Subscribe(queueRefresh)
ns.Commands.Register("journal", Window.Toggle, "HELP_JOURNAL")
