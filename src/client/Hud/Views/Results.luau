--!strict
-- The final standings, centre screen once the game is over.

local HudModel = require(script.Parent.Parent.HudModel)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local Results = {}
Results.__index = Results

local RANK_COLORS = {
	Color3.fromRGB(245, 197, 66), -- gold
	Color3.fromRGB(196, 204, 220), -- silver
	Color3.fromRGB(205, 133, 79), -- bronze
}

export type Results = typeof(setmetatable({} :: { frame: Frame, title: TextLabel, rows: Frame }, Results))

function Results.new(parent: Instance, onBack: () -> ()): Results
	local frame = Ui.panel("Results", UDim2.fromOffset(420, 0), UDim2.fromScale(0.5, 0.45), Vector2.new(0.5, 0.5), parent)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Visible = false
	Ui.list(frame, Enum.FillDirection.Vertical, Theme.space.m)
	Ui.padding(frame, Theme.space.l)

	local title = Ui.label("Title", frame, UDim2.new(1, 0, 0, 36), Theme.textSize.title, Theme.font.display)
	title.AutomaticSize = Enum.AutomaticSize.Y -- "Round limit reached — …" wraps onto two lines
	title.TextColor3 = Theme.color.accent
	title.LayoutOrder = 1

	local rows = Ui.frame("Standings", UDim2.new(1, 0, 0, 0), frame)
	rows.AutomaticSize = Enum.AutomaticSize.Y
	rows.LayoutOrder = 2
	Ui.list(rows, Enum.FillDirection.Vertical, Theme.space.xs)

	local back = Ui.button("Back to lobby", frame, onBack, "primary")
	back.Size = UDim2.fromOffset(220, 48)
	back.LayoutOrder = 3

	return setmetatable({ frame = frame, title = title, rows = rows }, Results)
end

-- A nil title hides the results.
function Results.render(self: Results, title: string?, standings: { HudModel.Standing })
	Ui.setVisible(self.frame, title ~= nil)
	Ui.clear(self.rows)
	if not title then
		return
	end
	self.title.Text = title
	for rank, standing in standings do
		local row = Ui.surface(`Rank{rank}`, UDim2.new(1, 0, 0, 44), self.rows)
		row.LayoutOrder = rank
		if standing.winner then
			row.BackgroundColor3 = Theme.color.surfaceHigh
			Ui.stroke(row, Theme.color.accent, 2, 0.1)
		end

		local badge = Ui.dot(row, RANK_COLORS[rank] or Theme.color.secondary, 28)
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 10, 0.5, 0)
		local number = Ui.label("Number", badge, UDim2.fromScale(1, 1), 16, Theme.font.display)
		number.Text = tostring(rank)
		number.TextColor3 = if RANK_COLORS[rank] then Theme.color.ink else Theme.color.text

		local name = Ui.label("Name", row, UDim2.new(1, -170, 1, 0), 18)
		name.Position = UDim2.fromOffset(48, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextWrapped = false
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = standing.name
		name.TextTransparency = if standing.bankrupt then 0.5 else 0

		local worth = Ui.label("Worth", row, UDim2.new(0, 110, 1, 0), 19, Theme.font.display)
		worth.AnchorPoint = Vector2.new(1, 0)
		worth.Position = UDim2.new(1, -12, 0, 0)
		worth.TextXAlignment = Enum.TextXAlignment.Right
		if standing.bankrupt then
			worth.Text = "Bankrupt"
			worth.TextSize = 15
			worth.TextColor3 = Theme.color.textDim
		else
			worth.Text = `${standing.netWorth}`
			worth.TextColor3 = if standing.winner then Theme.color.accent else Theme.color.text
		end
	end
end

return Results
