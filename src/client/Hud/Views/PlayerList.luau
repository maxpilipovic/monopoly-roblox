--!strict
-- Who's playing, top left: a row per player with their token colour, cash and standing in the game.
-- Cash counts to its new value and the change floats off the row.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local HudModel = require(script.Parent.Parent.HudModel)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local PlayerList = {}
PlayerList.__index = PlayerList

local WIDTH = 300
local ROW_HEIGHT = 46
local ROW_GAP = 4
local PADDING = 8
local COUNT_SECONDS = 0.4
local FLOAT_SECONDS = 1.4

export type PlayerList = typeof(setmetatable(
	{} :: {
		frame: Frame,
		rows: Frame,
		floaters: Frame,
		matchLabel: TextLabel,
		shown: { [string]: number }, -- the cash each row last displayed
	},
	PlayerList
))

function PlayerList.new(parent: Instance): PlayerList
	local frame = Ui.panel("Players", UDim2.fromOffset(WIDTH, 0), UDim2.fromOffset(12, 12), Vector2.zero, parent)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	local content = Ui.frame("Content", UDim2.new(1, 0, 0, 0), frame)
	content.AutomaticSize = Enum.AutomaticSize.Y
	Ui.list(content, Enum.FillDirection.Vertical, ROW_GAP)
	Ui.padding(content, PADDING)
	local rows = Ui.frame("Rows", UDim2.new(1, 0, 0, 0), content)
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.LayoutOrder = 1
	Ui.list(rows, Enum.FillDirection.Vertical, ROW_GAP)
	local matchLabel = Ui.label("Match", content, UDim2.new(1, -8, 0, 20), Theme.textSize.small, Theme.font.body)
	matchLabel.TextColor3 = Theme.color.textDim
	matchLabel.TextXAlignment = Enum.TextXAlignment.Left
	matchLabel.LayoutOrder = 2
	matchLabel.Visible = false
	-- Floaters live outside the rows, which are rebuilt on every update.
	local floaters = Ui.frame("Floaters", UDim2.fromScale(1, 0), frame)
	floaters.ZIndex = 2
	return setmetatable({ frame = frame, rows = rows, floaters = floaters, matchLabel = matchLabel, shown = {} }, PlayerList)
end

local function subline(row: HudModel.PlayerRow): string
	if row.bankrupt then
		return "Out of the game"
	elseif row.deeds == 0 then
		return "No properties"
	end
	return `{row.deeds} propert{if row.deeds == 1 then "y" else "ies"}`
end

local function float(self: PlayerList, index: number, delta: number)
	local label = Ui.label("Floater", self.floaters, UDim2.fromOffset(100, 20), 17, Theme.font.display)
	local y = PADDING + (index - 1) * (ROW_HEIGHT + ROW_GAP) + 2
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, -18, 0, y)
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextWrapped = false
	label.TextColor3 = if delta > 0 then Theme.color.moneyUp else Theme.color.moneyDown
	label.Text = if delta > 0 then `+${delta}` else `−${-delta}`
	local outline = Ui.stroke(label, Theme.color.panel, 2, 0.2)
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	TweenService:Create(outline, TweenInfo.new(FLOAT_SECONDS), { Transparency = 1 }):Play()
	TweenService:Create(label, TweenInfo.new(FLOAT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -18, 0, y - 20),
		TextTransparency = 1,
	}):Play()
	task.delay(FLOAT_SECONDS, function()
		label:Destroy()
	end)
end

-- Counts a money label from what the row last showed to its new value.
local function count(self: PlayerList, label: TextLabel, id: string, from: number, to: number)
	local value = Instance.new("NumberValue")
	value.Value = from
	value.Parent = label -- dies with the label when the rows are rebuilt
	value.Changed:Connect(function(now)
		local shown = math.round(now)
		self.shown[id] = shown
		label.Text = `${shown}`
	end)
	TweenService:Create(value, TweenInfo.new(COUNT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = to }):Play()
end

-- `deltas` are the cash changes since the last update (player id -> amount); each one floats.
function PlayerList.render(self: PlayerList, rows: { HudModel.PlayerRow }, deltas: { [string]: number }?)
	Ui.clear(self.rows)
	local present = {}
	for index, row in rows do
		present[row.id] = true
		local frame = Ui.surface(row.id, UDim2.new(1, 0, 0, ROW_HEIGHT), self.rows)
		frame.LayoutOrder = row.seat
		frame.BackgroundColor3 = if row.isCurrent then Theme.color.surfaceHigh else Theme.color.surface
		frame.BackgroundTransparency = if row.bankrupt then 0.6 else 0
		local dim = if row.bankrupt then 0.5 else 0

		if row.isCurrent then
			-- Whose turn it is: a gold bar down the row's left edge.
			local bar = Instance.new("Frame")
			bar.Name = "Turn"
			bar.Size = UDim2.new(0, 4, 1, -12)
			bar.Position = UDim2.fromOffset(3, 6)
			bar.BackgroundColor3 = Theme.color.accent
			bar.BorderSizePixel = 0
			bar.Parent = frame
			Ui.corner(bar, 2)
		end

		local dot = Ui.dot(frame, TokenLayout.SEAT_COLORS[row.seat], 18)
		dot.Position = UDim2.new(0, 14, 0.5, 0)
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.BackgroundTransparency = dim

		local nameRow = Ui.frame("NameRow", UDim2.new(1, -150, 0, 20), frame)
		nameRow.Position = UDim2.fromOffset(40, 5)
		Ui.list(nameRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
		local name = Ui.label("Name", nameRow, UDim2.fromOffset(0, 20), 16)
		name.AutomaticSize = Enum.AutomaticSize.X
		name.TextWrapped = false
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextTransparency = dim
		name.Text = row.name
		name.LayoutOrder = 1
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(if row.isYou then 96 else 140, 20)
		limit.Parent = name
		if row.isYou then
			Ui.pill("YOU", nameRow, Theme.color.accent, Theme.color.ink).LayoutOrder = 2
		end

		local sub = Ui.label("Sub", frame, UDim2.new(1, -150, 0, 16), 12, Theme.font.body)
		sub.Position = UDim2.fromOffset(40, 26)
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextColor3 = Theme.color.textDim
		sub.TextWrapped = false
		sub.Text = subline(row)

		local money = Ui.label("Money", frame, UDim2.new(0, 100, 1, 0), 19, Theme.font.display)
		money.AnchorPoint = Vector2.new(1, 0)
		money.Position = UDim2.new(1, -10, 0, 0)
		money.TextXAlignment = Enum.TextXAlignment.Right
		money.TextWrapped = false
		if row.bankrupt then
			money.Text = "BANKRUPT"
			money.TextSize = 13
			money.TextColor3 = Theme.color.textDim
			self.shown[row.id] = row.money
		else
			local from = self.shown[row.id] or row.money
			self.shown[row.id] = from
			money.Text = `${from}`
			if from ~= row.money then
				count(self, money, row.id, from, row.money)
			end
		end

		if row.inJail and not row.bankrupt then
			local jail = Ui.pill("JAIL", frame, Theme.color.danger)
			jail.AnchorPoint = Vector2.new(1, 0.5)
			jail.Position = UDim2.new(1, -82, 0.5, 0)
		end

		local delta = if deltas then deltas[row.id] else nil
		if delta and delta ~= 0 then
			float(self, index, delta)
		end
	end
	for id in self.shown do
		if not present[id] then
			self.shown[id] = nil
		end
	end
end

function PlayerList.setMatchLine(self: PlayerList, line: string?)
	self.matchLabel.Visible = line ~= nil
	self.matchLabel.Text = line or ""
end

-- A new game starts from its own numbers, not the last game's.
function PlayerList.reset(self: PlayerList)
	table.clear(self.shown)
	Ui.clear(self.floaters)
end

return PlayerList
