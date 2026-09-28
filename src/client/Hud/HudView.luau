--!strict
-- The on-screen HUD: lobby panel, player list, status + action buttons, and event log.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local HudModel = require(script.Parent.HudModel)

local LOG_LINES = 8
local FONT = Font.fromEnum(Enum.Font.GothamBold)
local PANEL_COLOR = Color3.fromRGB(25, 27, 32)
local BUTTON_COLOR = Color3.fromRGB(46, 160, 67)
local TEXT_COLOR = Color3.new(1, 1, 1)

export type Callbacks = {
	onAction: (action: { [string]: any }) -> (),
	onStart: (seats: number) -> (),
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
	local bar = panel("ActionBar", UDim2.fromOffset(560, 100), UDim2.new(0.5, 0, 1, -12), Vector2.new(0.5, 1), gui)
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

	return self
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
	self.lobby.Visible = snapshot == nil
	self.playerList.Visible = snapshot ~= nil
	self.buttonRow.Parent.Visible = snapshot ~= nil

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
		row.Text = `{marker}{player.name}{you}   ${player.money}`
	end

	local roll = snapshot.lastRoll
	local dice = if roll then `   🎲 {roll[1]} + {roll[2]}` else ""
	self.status.Text = HudModel.status(snapshot, localId) .. dice

	for order, entry in HudModel.buttons(snapshot, localId) do
		local b = button(entry.label, self.buttonRow, function()
			self.callbacks.onAction(entry.action)
		end)
		b.LayoutOrder = order
	end
end

return HudView
