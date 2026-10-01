--!strict
-- Your deeds, right side, grouped by set: what you own, what's built on it, and what you may do
-- with it now.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PropertyRules = require(ReplicatedStorage.Shared.Rules.PropertyRules)
local HudModel = require(script.Parent.Parent.HudModel)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local PropertiesPanel = {}
PropertiesPanel.__index = PropertiesPanel

local OTHER_SWATCH = Color3.fromRGB(150, 150, 150) -- railroads and utilities have no colour group
local ROW_BUTTON_WIDTH = 104
local WIDTH = 440
local MAX_HEIGHT = 360 -- ends above the action bar
local HEADER_HEIGHT = 26
local ROW_HEIGHT = 40
local HOUSE_COLOR = Color3.fromRGB(47, 191, 113)
local HOTEL_COLOR = Color3.fromRGB(229, 72, 77)

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
	local frame = Ui.panel("Properties", UDim2.fromOffset(WIDTH, MAX_HEIGHT), UDim2.new(1, -12, 0, 224), Vector2.new(1, 0), parent)
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

-- Houses as green blocks, a hotel as one red block.
local function buildings(parent: Instance, houses: number)
	local holder = Ui.frame("Buildings", UDim2.fromOffset(46, 28), parent)
	holder.LayoutOrder = 2
	Ui.list(holder, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Left)
	local hotel = houses == PropertyRules.HOTEL
	for index = 1, if hotel then 1 else houses do
		local block = Instance.new("Frame")
		block.Name = if hotel then "Hotel" else "House"
		block.Size = if hotel then UDim2.fromOffset(22, 14) else UDim2.fromOffset(9, 12)
		block.BackgroundColor3 = if hotel then HOTEL_COLOR else HOUSE_COLOR
		block.BorderSizePixel = 0
		block.LayoutOrder = index
		block.Parent = holder
		Ui.corner(block, 3)
	end
end

function PropertiesPanel.render(self: PropertiesPanel, open: boolean, groups: { HudModel.PropertyGroup }, emptyText: string)
	Ui.setVisible(self.frame, open)
	-- Rebuild only when something shown changed: a rebuild resets the scroll and can swallow a click.
	local shown = {}
	if open then
		for _, group in groups do
			-- Colours can't be encoded and never change; everything else that's drawn is in the key.
			table.insert(shown, { group.key, group.owned, group.size, group.rows })
		end
	end
	local key = HttpService:JSONEncode({ open = open, groups = shown, empty = emptyText })
	if key == self.key then
		return
	end
	self.key = key
	Ui.clear(self.scroll)
	-- As tall as its content, up to the cap: a short list shouldn't hang a big empty panel over the board.
	local content = 16
	for _, group in groups do
		content += HEADER_HEIGHT + Theme.space.xs + #group.rows * (ROW_HEIGHT + Theme.space.xs)
	end
	self.frame.Size = UDim2.fromOffset(WIDTH, math.clamp(content, 64, MAX_HEIGHT))
	if not open then
		return
	end

	if #groups == 0 then
		local empty = Ui.label("Empty", self.scroll, UDim2.new(1, -8, 0, 40), 16, Theme.font.body)
		empty.TextColor3 = Theme.color.textDim
		empty.Text = emptyText
		return
	end
	local order = 0
	for _, group in groups do
		order += 1
		local complete = group.owned == group.size
		local header = Ui.frame(group.title, UDim2.new(1, -8, 0, HEADER_HEIGHT), self.scroll)
		header.LayoutOrder = order
		local title = Ui.label("Title", header, UDim2.new(1, -70, 1, 0), 15, Theme.font.display)
		title.Position = UDim2.fromOffset(4, 0)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = if complete then Theme.color.accent else Theme.color.textDim
		title.Text = group.title
		-- How much of the set you hold; gold once it's complete.
		local owned = Ui.pill(`{group.owned}/{group.size}`, header, if complete then Theme.color.accent else Theme.color.surface, if complete then Theme.color.ink else Theme.color.text)
		owned.Name = "Owned"
		owned.AnchorPoint = Vector2.new(1, 0.5)
		owned.Position = UDim2.new(1, -4, 0.5, 0)

		for _, entry in group.rows do
			order += 1
			local row = Ui.surface(entry.name, UDim2.new(1, -8, 0, ROW_HEIGHT), self.scroll)
			row.LayoutOrder = order
			Ui.list(row, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
			Ui.padding(row, { left = 6, right = 6 })

			local swatch = Instance.new("Frame")
			swatch.Name = "Swatch"
			swatch.Size = UDim2.fromOffset(8, 28)
			swatch.BorderSizePixel = 0
			swatch.BackgroundColor3 = group.color or OTHER_SWATCH
			swatch.LayoutOrder = 0
			swatch.Parent = row
			Ui.corner(swatch, 3)

			local label = Ui.label("Name", row, UDim2.fromOffset(if entry.mortgaged then 96 else if entry.houses > 0 then 110 else 158, 28), 15)
			label.LayoutOrder = 1
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextWrapped = false
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.Text = entry.name
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

			if entry.mortgaged then
				local tag = Ui.pill("MORTGAGED", row, Theme.color.danger)
				tag.LayoutOrder = 2
			else
				if entry.houses > 0 then
					buildings(row, entry.houses)
				end
			end

			for i, entryButton in entry.buttons do
				local button = Ui.button(entryButton.label, row, function()
					self.send(entryButton.action)
				end, "secondary")
				button.Size = UDim2.fromOffset(ROW_BUTTON_WIDTH, 30)
				button.LayoutOrder = 2 + i
				Ui.setTextSize(button, 13)
			end
		end
	end
end

-- Forgets what was drawn, so the next render rebuilds (used when the game ends).
function PropertiesPanel.reset(self: PropertiesPanel)
	self.key = nil
	self.frame.Visible = false
end

return PropertiesPanel
