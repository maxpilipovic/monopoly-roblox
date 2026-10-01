--!strict
-- Bottom centre: what's happening, and the buttons for what the local player may do about it.

local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local ActionBar = {}
ActionBar.__index = ActionBar

ActionBar.WIDTH = 700
ActionBar.HEIGHT = 112
ActionBar.MARGIN = 12 -- gap to the screen's bottom edge

local BUTTON_GAP = 8
local BUTTON_WIDTH = 150
local PADDING = 12

export type Entry = {
	label: string,
	style: Ui.Style,
	order: number,
	width: number?, -- preferred width; shrinks with the rest if the row is full
	onClick: (button: TextButton) -> (),
}

export type ActionBar = typeof(setmetatable({} :: { frame: Frame, status: TextLabel, buttons: Frame }, ActionBar))

function ActionBar.new(parent: Instance): ActionBar
	local frame = Ui.panel(
		"ActionBar",
		UDim2.fromOffset(ActionBar.WIDTH, ActionBar.HEIGHT),
		UDim2.new(0.5, 0, 1, -ActionBar.MARGIN),
		Vector2.new(0.5, 1),
		parent
	)
	local status = Ui.label("Status", frame, UDim2.new(1, -2 * PADDING, 0, 30), 20)
	status.Position = UDim2.fromOffset(PADDING, 10)
	status.TextWrapped = false
	status.TextTruncate = Enum.TextTruncate.AtEnd
	local buttons = Ui.frame("Buttons", UDim2.new(1, -2 * PADDING, 0, 48), frame)
	buttons.Position = UDim2.fromOffset(PADDING, 50)
	Ui.list(buttons, Enum.FillDirection.Horizontal, BUTTON_GAP)
	return setmetatable({ frame = frame, status = status, buttons = buttons }, ActionBar)
end

function ActionBar.setStatus(self: ActionBar, text: string, color: Color3)
	self.status.Text = text
	self.status.TextColor3 = color
end

-- Replaces the buttons. They share the row: if their preferred widths don't fit, all shrink evenly.
function ActionBar.setButtons(self: ActionBar, entries: { Entry })
	Ui.clear(self.buttons)
	if #entries == 0 then
		return
	end
	local available = ActionBar.WIDTH - 2 * PADDING - BUTTON_GAP * (#entries - 1)
	local wanted = 0
	for _, entry in entries do
		wanted += entry.width or BUTTON_WIDTH
	end
	local shrink = math.min(1, available / wanted)
	for _, entry in entries do
		local button: TextButton
		button = Ui.button(entry.label, self.buttons, function()
			entry.onClick(button)
		end, entry.style)
		button.Size = UDim2.fromOffset(math.floor((entry.width or BUTTON_WIDTH) * shrink), 48)
		button.LayoutOrder = entry.order
	end
end

return ActionBar
