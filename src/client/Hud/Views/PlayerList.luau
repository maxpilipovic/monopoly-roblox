--!strict
-- Who's playing, top left: a row per player with their token colour, cash and standing in the game.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local HudModel = require(script.Parent.Parent.HudModel)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local PlayerList = {}
PlayerList.__index = PlayerList

local WIDTH = 300
local ROW_HEIGHT = 46

export type PlayerList = typeof(setmetatable({} :: { frame: Frame, rows: Frame, matchLabel: TextLabel }, PlayerList))

function PlayerList.new(parent: Instance): PlayerList
	local frame = Ui.panel("Players", UDim2.fromOffset(WIDTH, 0), UDim2.fromOffset(12, 12), Vector2.zero, parent)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	Ui.list(frame, Enum.FillDirection.Vertical, Theme.space.xs)
	Ui.padding(frame, Theme.space.s)
	local rows = Ui.frame("Rows", UDim2.new(1, 0, 0, 0), frame)
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.LayoutOrder = 1
	Ui.list(rows, Enum.FillDirection.Vertical, Theme.space.xs)
	local matchLabel = Ui.label("Match", frame, UDim2.new(1, -8, 0, 20), Theme.textSize.small, Theme.font.body)
	matchLabel.TextColor3 = Theme.color.textDim
	matchLabel.TextXAlignment = Enum.TextXAlignment.Left
	matchLabel.LayoutOrder = 2
	matchLabel.Visible = false
	return setmetatable({ frame = frame, rows = rows, matchLabel = matchLabel }, PlayerList)
end

local function subline(row: HudModel.PlayerRow): string
	if row.bankrupt then
		return "Out of the game"
	elseif row.deeds == 0 then
		return "No properties"
	end
	return `{row.deeds} propert{if row.deeds == 1 then "y" else "ies"}`
end

function PlayerList.render(self: PlayerList, rows: { HudModel.PlayerRow })
	Ui.clear(self.rows)
	for _, row in rows do
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
		else
			money.Text = `${row.money}`
		end

		if row.inJail and not row.bankrupt then
			local jail = Ui.pill("JAIL", frame, Theme.color.danger)
			jail.AnchorPoint = Vector2.new(1, 0.5)
			jail.Position = UDim2.new(1, -82, 0.5, 0)
		end
	end
end

function PlayerList.setMatchLine(self: PlayerList, line: string?)
	self.matchLabel.Visible = line ~= nil
	self.matchLabel.Text = line or ""
end

return PlayerList
