--!strict
-- The on-screen HUD: lobby panel, player list, status + action buttons, event log, and drawn cards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local CardQueue = require(script.Parent.CardQueue)
local HudModel = require(script.Parent.HudModel)

local LOG_LINES = 8
local FONT = Font.fromEnum(Enum.Font.GothamBold)
local PANEL_COLOR = Color3.fromRGB(25, 27, 32)
local BUTTON_COLOR = Color3.fromRGB(46, 160, 67)
local TEXT_COLOR = Color3.new(1, 1, 1)
local CARD_SECONDS = 5
local CARD_COLORS = {
	Chance = Color3.fromRGB(247, 148, 29),
	CommunityChest = Color3.fromRGB(125, 190, 230),
}
local CARD_TEXT_COLOR = Color3.fromRGB(20, 20, 20)
local TOGGLE_COLOR = Color3.fromRGB(70, 90, 140)
local OTHER_SWATCH = Color3.fromRGB(150, 150, 150)
local DANGER_COLOR = Color3.fromRGB(200, 60, 60)
local DEBT_TEXT_COLOR = Color3.fromRGB(255, 120, 120)

export type Callbacks = {
	onAction: (action: { [string]: any }) -> (),
	onStart: (seats: number) -> (),
	onReturnToLobby: () -> (),
}

local HudView = {}
HudView.__index = HudView

export type HudView = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		callbacks: Callbacks,
		lobby: Frame,
		seatsLabel: TextLabel,
		seats: number,
		playerList: Frame,
		status: TextLabel,
		buttonRow: Frame,
		logLabel: TextLabel,
		logLines: { string },
		card: Frame,
		cardTitle: TextLabel,
		cardText: TextLabel,
		cards: CardQueue.Queue,
		propertiesOpen: boolean,
		propertiesPanel: ScrollingFrame,
		snapshot: Protocol.Snapshot?,
		localId: string,
		wasDebtor: boolean,
		results: Frame,
		resultsTitle: TextLabel,
		resultsRows: Frame,
	},
	HudView
))

local function corner(parent: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = parent
end

local function panel(name: string, size: UDim2, position: UDim2, anchor: Vector2, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor
	frame.BackgroundColor3 = PANEL_COLOR
	frame.BackgroundTransparency = 0.15
	frame.Parent = parent
	corner(frame)
	return frame
end

local function text(name: string, parent: Instance, size: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextSize = textSize
	label.TextColor3 = TEXT_COLOR
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function button(label: string, parent: Instance, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = label
	b.Size = UDim2.fromOffset(150, 44)
	b.BackgroundColor3 = BUTTON_COLOR
	b.FontFace = FONT
	b.TextSize = 18
	b.TextColor3 = TEXT_COLOR
	b.Text = label
	b.Parent = parent
	corner(b)
	b.Activated:Connect(onClick)
	return b
end

local function list(parent: Instance, direction: Enum.FillDirection, padding: number)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, padding)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
end

local function updateCard(self: HudView)
	local card = CardQueue.current(self.cards, os.clock())
	self.card.Visible = card ~= nil
	if card then
		self.card.BackgroundColor3 = CARD_COLORS[card.deck] or PANEL_COLOR
		self.cardTitle.Text = Cards.DECK_TITLES[card.deck] or card.deck
		self.cardText.Text = card.text
	end
end

local function renderProperties(self: HudView, snapshot: Protocol.Snapshot, localId: string)
	local panel = self.propertiesPanel
	panel.Visible = self.propertiesOpen
	for _, child in panel:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if not self.propertiesOpen then
		return
	end

	local rows = HudModel.propertyRows(snapshot, localId)
	if #rows == 0 then
		local empty = text("Empty", panel, UDim2.new(1, -16, 0, 30), 16)
		empty.Text = "You don't own any property yet"
		return
	end
	for order, entry in rows do
		local row = Instance.new("Frame")
		row.Name = entry.name
		row.Size = UDim2.new(1, -16, 0, 34)
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.Parent = panel
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		rowLayout.Padding = UDim.new(0, 6)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = row

		local swatch = Instance.new("Frame")
		swatch.Name = "Swatch"
		swatch.Size = UDim2.fromOffset(10, 26)
		swatch.BorderSizePixel = 0
		local group = ColorGroups[entry.group]
		swatch.BackgroundColor3 = if group then group.color else OTHER_SWATCH
		swatch.Parent = row

		local label = text("Name", row, UDim2.fromOffset(190, 26), 15)
		label.LayoutOrder = 1
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = false
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = `{entry.name}  {HudModel.buildingText(entry)}`

		for i, entryButton in entry.buttons do
			local b = button(entryButton.label, row, function()
				self.callbacks.onAction(entryButton.action)
			end)
			b.Size = UDim2.fromOffset(92, 28)
			b.TextSize = 13
			b.LayoutOrder = 1 + i
		end
	end
end

function HudView.new(playerGui: Instance, callbacks: Callbacks): HudView
	local gui = Instance.new("ScreenGui")
	gui.Name = "MonopolyHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = playerGui

	-- Lobby: pick seats, start.
	local lobby = panel("Lobby", UDim2.fromOffset(320, 150), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), gui)
	list(lobby, Enum.FillDirection.Vertical, 10)
	local seatsLabel = text("Seats", lobby, UDim2.new(1, 0, 0, 30), 22)
	local seatRow = Instance.new("Frame")
	seatRow.Size = UDim2.new(1, 0, 0, 44)
	seatRow.BackgroundTransparency = 1
	seatRow.Parent = lobby
	list(seatRow, Enum.FillDirection.Horizontal, 10)

	local self = setmetatable({
		gui = gui,
		callbacks = callbacks,
		lobby = lobby,
		seatsLabel = seatsLabel,
		seats = 4,
		playerList = panel("Players", UDim2.fromOffset(300, 0), UDim2.fromOffset(12, 12), Vector2.zero, gui),
		status = nil :: any,
		buttonRow = nil :: any,
		logLabel = nil :: any,
		logLines = {},
		card = nil :: any,
		cardTitle = nil :: any,
		cardText = nil :: any,
		cards = CardQueue.new(CARD_SECONDS),
		propertiesOpen = false,
		propertiesPanel = nil :: any,
		snapshot = nil,
		localId = "",
		wasDebtor = false,
		results = nil :: any,
		resultsTitle = nil :: any,
		resultsRows = nil :: any,
	}, HudView)

	local function changeSeats(delta: number)
		self.seats = math.clamp(self.seats + delta, 2, 6)
		self.seatsLabel.Text = `Players: {self.seats} (bots fill empty seats)`
	end
	local minus = button("-", seatRow, function()
		changeSeats(-1)
	end)
	minus.Size = UDim2.fromOffset(44, 44)
	button("Start game", seatRow, function()
		callbacks.onStart(self.seats)
	end)
	local plus = button("+", seatRow, function()
		changeSeats(1)
	end)
	plus.Size = UDim2.fromOffset(44, 44)
	changeSeats(0)

	self.playerList.AutomaticSize = Enum.AutomaticSize.Y
	list(self.playerList, Enum.FillDirection.Vertical, 4)

	-- Bottom bar: status line over action buttons.
	local bar = panel("ActionBar", UDim2.fromOffset(660, 100), UDim2.new(0.5, 0, 1, -12), Vector2.new(0.5, 1), gui)
	list(bar, Enum.FillDirection.Vertical, 6)
	self.status = text("Status", bar, UDim2.new(1, -16, 0, 28), 20)
	local buttonRow = Instance.new("Frame")
	buttonRow.Name = "Buttons"
	buttonRow.Size = UDim2.new(1, 0, 0, 44)
	buttonRow.BackgroundTransparency = 1
	buttonRow.Parent = bar
	list(buttonRow, Enum.FillDirection.Horizontal, 8)
	self.buttonRow = buttonRow

	-- Event log, top right.
	local logPanel = panel("Log", UDim2.fromOffset(300, 200), UDim2.new(1, -12, 0, 12), Vector2.new(1, 0), gui)
	self.logLabel = text("Lines", logPanel, UDim2.new(1, -16, 1, -12), 15)
	self.logLabel.Position = UDim2.fromOffset(8, 6)
	self.logLabel.Text = ""
	self.logLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.logLabel.TextYAlignment = Enum.TextYAlignment.Bottom

	-- Your properties, right side under the log; opened from the action bar.
	local properties = Instance.new("ScrollingFrame")
	properties.Name = "Properties"
	properties.Size = UDim2.fromOffset(420, 360)
	properties.Position = UDim2.new(1, -12, 0, 224)
	properties.AnchorPoint = Vector2.new(1, 0)
	properties.BackgroundColor3 = PANEL_COLOR
	properties.BackgroundTransparency = 0.15
	properties.BorderSizePixel = 0
	properties.ScrollBarThickness = 6
	properties.CanvasSize = UDim2.new()
	properties.AutomaticCanvasSize = Enum.AutomaticSize.Y
	properties.Visible = false
	properties.Parent = gui
	corner(properties)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.Parent = properties
	local propertiesLayout = Instance.new("UIListLayout")
	propertiesLayout.Padding = UDim.new(0, 4)
	propertiesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	propertiesLayout.Parent = properties
	self.propertiesPanel = properties

	-- Drawn card popup, under the top edge.
	local card = panel("Card", UDim2.fromOffset(360, 130), UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0), gui)
	card.BackgroundTransparency = 0
	card.Visible = false
	self.cardTitle = text("Title", card, UDim2.new(1, -16, 0, 30), 22)
	self.cardTitle.Position = UDim2.fromOffset(8, 8)
	self.cardTitle.TextColor3 = CARD_TEXT_COLOR
	self.cardText = text("Text", card, UDim2.new(1, -16, 1, -48), 17)
	self.cardText.Position = UDim2.fromOffset(8, 40)
	self.cardText.TextColor3 = CARD_TEXT_COLOR
	self.card = card
	RunService.Heartbeat:Connect(function()
		updateCard(self)
	end)

	-- Results, centre screen once the game is over.
	local results = panel("Results", UDim2.fromOffset(360, 0), UDim2.fromScale(0.5, 0.45), Vector2.new(0.5, 0.5), gui)
	results.AutomaticSize = Enum.AutomaticSize.Y
	results.Visible = false
	list(results, Enum.FillDirection.Vertical, 8)
	local resultsPadding = Instance.new("UIPadding")
	resultsPadding.PaddingTop = UDim.new(0, 12)
	resultsPadding.PaddingBottom = UDim.new(0, 12)
	resultsPadding.Parent = results
	self.resultsTitle = text("Title", results, UDim2.new(1, -16, 0, 36), 28)
	self.resultsTitle.LayoutOrder = 1
	local resultsRows = Instance.new("Frame")
	resultsRows.Name = "Standings"
	resultsRows.Size = UDim2.new(1, -16, 0, 0)
	resultsRows.AutomaticSize = Enum.AutomaticSize.Y
	resultsRows.BackgroundTransparency = 1
	resultsRows.LayoutOrder = 2
	resultsRows.Parent = results
	list(resultsRows, Enum.FillDirection.Vertical, 4)
	self.resultsRows = resultsRows
	local back = button("Back to lobby", results, function()
		callbacks.onReturnToLobby()
	end)
	back.LayoutOrder = 3
	self.results = results

	return self
end

-- Queues a drawn card; it appears at `notBefore` (os.clock time) or after the cards ahead of it.
function HudView.showCard(self: HudView, deck: string, body: string, notBefore: number)
	CardQueue.push(self.cards, deck, body, notBefore)
end

function HudView.log(self: HudView, lines: { string })
	for _, line in lines do
		table.insert(self.logLines, line)
	end
	while #self.logLines > LOG_LINES do
		table.remove(self.logLines, 1)
	end
	self.logLabel.Text = table.concat(self.logLines, "\n")
end

function HudView.render(self: HudView, snapshot: Protocol.Snapshot?, localId: string)
	self.snapshot = snapshot
	self.localId = localId
	self.lobby.Visible = snapshot == nil
	self.playerList.Visible = snapshot ~= nil
	self.buttonRow.Parent.Visible = snapshot ~= nil
	if not snapshot then
		table.clear(self.cards.items) -- back in the lobby: drop cards still waiting
		self.propertiesOpen = false
		self.propertiesPanel.Visible = false
		table.clear(self.logLines) -- the next game starts with a fresh log
		self.logLabel.Text = ""
		self.wasDebtor = false
		self.results.Visible = false
	end

	for _, child in self.playerList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for _, child in self.buttonRow:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	if not snapshot then
		return
	end

	for _, player in snapshot.players do
		local row = text(player.id, self.playerList, UDim2.new(1, -12, 0, 26), 17)
		row.LayoutOrder = player.seat
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextWrapped = false
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.TextColor3 = TokenLayout.SEAT_COLORS[player.seat]
		local marker = if player.id == snapshot.currentPlayer then "▶ " else "   "
		local you = if player.id == localId then " (you)" else ""
		local jail = if player.inJail then " 🔒" else ""
		local balance = if player.bankrupt then "Bankrupt" else `${player.money}`
		row.Text = `{marker}{player.name}{you}{jail}   {balance}`
	end

	local roll = snapshot.lastRoll
	local dice = if roll then `   🎲 {roll[1]} + {roll[2]}` else ""
	self.status.Text = HudModel.status(snapshot, localId) .. dice
	local debtor = HudModel.isDebtor(snapshot, localId)
	self.status.TextColor3 = if debtor then DEBT_TEXT_COLOR else TEXT_COLOR

	if debtor and not self.wasDebtor then
		self.propertiesOpen = true -- raising cash happens in the panel
	end
	self.wasDebtor = debtor
	if snapshot.phase == "GameOver" then
		self.propertiesOpen = false
	end

	for order, entry in HudModel.buttons(snapshot, localId) do
		local b: TextButton
		b = button(entry.label, self.buttonRow, function()
			local confirm = entry.confirm
			if confirm and b.Text ~= confirm then
				b.Text = confirm -- first click only arms it; any re-render disarms it
				return
			end
			self.callbacks.onAction(entry.action)
		end)
		b.LayoutOrder = order
		if entry.confirm then
			b.BackgroundColor3 = DANGER_COLOR
			b.Size = UDim2.fromOffset(200, 44)
		end
	end

	if HudModel.showsPropertiesToggle(snapshot) then
		local toggle = button(if self.propertiesOpen then "Hide properties" else "Properties", self.buttonRow, function()
			self.propertiesOpen = not self.propertiesOpen
			self:render(self.snapshot, self.localId)
		end)
		toggle.LayoutOrder = 100
		toggle.BackgroundColor3 = TOGGLE_COLOR
	end
	renderProperties(self, snapshot, localId)

	self.results.Visible = snapshot.phase == "GameOver"
	for _, child in self.resultsRows:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if snapshot.phase == "GameOver" then
		self.resultsTitle.Text = HudModel.status(snapshot, localId)
		for order, standing in HudModel.standings(snapshot) do
			local line = text(`Rank{order}`, self.resultsRows, UDim2.new(1, 0, 0, 24), 18)
			line.LayoutOrder = order
			local worth = if standing.bankrupt then "Bankrupt" else `${standing.netWorth}`
			line.Text = `{order}. {standing.name}{if standing.winner then " 🏆" else ""}   {worth}`
		end
	end
end

return HudView
