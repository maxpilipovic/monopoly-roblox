--!strict
-- Your deeds, right side: what you own, what's built on it, and what you may do with it now.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local HudModel = require(script.Parent.Parent.HudModel)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local PropertiesPanel = {}
PropertiesPanel.__index = PropertiesPanel

local OTHER_SWATCH = Color3.fromRGB(150, 150, 150) -- railroads and utilities have no colour group
local ROW_BUTTON_WIDTH = 120

export type PropertiesPanel = typeof(setmetatable(
	{} :: {
		frame: Frame,
		scroll: ScrollingFrame,
		send: (action: { [string]: any }) -> (),
		inspect: ((position: number) -> ())?,
		key: string?,
	},
	PropertiesPanel
))

function PropertiesPanel.new(
	parent: Instance,
	send: (action: { [string]: any }) -> (),
	inspect: ((position: number) -> ())?
): PropertiesPanel
	local frame = Ui.panel("Properties", UDim2.fromOffset(470, 360), UDim2.new(1, -12, 0, 224), Vector2.new(1, 0), parent)
	frame.Visible = false
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Rows"
	scroll.Size = UDim2.new(1, -12, 1, -16)
	scroll.Position = UDim2.fromOffset(8, 8)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Theme.color.textDim
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = frame
	Ui.list(scroll, Enum.FillDirection.Vertical, Theme.space.xs, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
	return setmetatable({ frame = frame, scroll = scroll, send = send, inspect = inspect, key = nil }, PropertiesPanel)
end

function PropertiesPanel.render(self: PropertiesPanel, open: boolean, rows: { HudModel.PropertyRow }, emptyText: string)
	Ui.setVisible(self.frame, open)
	-- Rebuild only when something shown changed: a rebuild resets the scroll and can swallow a click.
	local key = HttpService:JSONEncode({ open = open, rows = if open then rows else {}, empty = emptyText })
	if key == self.key then
		return
	end
	self.key = key
	Ui.clear(self.scroll)
	if not open then
		return
	end

	if #rows == 0 then
		local empty = Ui.label("Empty", self.scroll, UDim2.new(1, -8, 0, 40), 16, Theme.font.body)
		empty.TextColor3 = Theme.color.textDim
		empty.Text = emptyText
		return
	end
	for order, entry in rows do
		local row = Ui.surface(entry.name, UDim2.new(1, -8, 0, 40), self.scroll)
		row.LayoutOrder = order
		Ui.list(row, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
		Ui.padding(row, { left = 6, right = 6 })

		local swatch = Instance.new("Frame")
		swatch.Name = "Swatch"
		swatch.Size = UDim2.fromOffset(8, 28)
		swatch.BorderSizePixel = 0
		local group = ColorGroups[entry.group]
		swatch.BackgroundColor3 = if group then group.color else OTHER_SWATCH
		swatch.Parent = row
		Ui.corner(swatch, 3)

		local label = Ui.label("Name", row, UDim2.fromOffset(176, 28), 15)
		label.LayoutOrder = 1
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = false
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = `{entry.name}  {HudModel.buildingText(entry)}`
		label.TextColor3 = if entry.mortgaged then Theme.color.textDim else Theme.color.text
		local inspect = self.inspect
		if inspect then
			-- The name is the way to the deed.
			local open = Instance.new("TextButton")
			open.Name = "Inspect"
			open.Size = UDim2.fromScale(1, 1)
			open.BackgroundTransparency = 1
			open.Text = ""
			open.Parent = label
			open.Activated:Connect(function()
				inspect(entry.position)
			end)
		end

		for i, entryButton in entry.buttons do
			local button = Ui.button(entryButton.label, row, function()
				self.send(entryButton.action)
			end, "secondary")
			button.Size = UDim2.fromOffset(ROW_BUTTON_WIDTH, 30)
			button.LayoutOrder = 1 + i
			Ui.setTextSize(button, 13)
		end
	end
end

-- Forgets what was drawn, so the next render rebuilds (used when the game ends).
function PropertiesPanel.reset(self: PropertiesPanel)
	self.key = nil
	self.frame.Visible = false
end

return PropertiesPanel
