--!strict
-- Bottom centre: what's happening, and the buttons for what the local player may do about it.

local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)
local Dice = require(script.Parent.Dice)

local ActionBar = {}
ActionBar.__index = ActionBar

ActionBar.WIDTH = 700
ActionBar.HEIGHT = 112
ActionBar.MARGIN = 12 -- gap to the screen's bottom edge

local BUTTON_GAP = 8
local BUTTON_WIDTH = 150
local PADDING = 12
local SIDE_ROOM = 92 -- kept clear either side of the status line: the dice sit on the right

export type Entry = {
	label: string,
	style: Ui.Style,
	order: number,
	width: number?, -- preferred width; shrinks with the rest if the row is full
	onClick: (button: TextButton) -> (),
}

export type ActionBar = typeof(setmetatable(
	{} :: { frame: Frame, status: TextLabel, buttons: Frame, dice: Dice.Dice, track: Frame, timer: Frame },
	ActionBar
))

function ActionBar.new(parent: Instance): ActionBar
	local frame = Ui.panel(
		"ActionBar",
		UDim2.fromOffset(ActionBar.WIDTH, ActionBar.HEIGHT),
		UDim2.new(0.5, 0, 1, -ActionBar.MARGIN),
		Vector2.new(0.5, 1),
		parent
	)
	local status = Ui.label("Status", frame, UDim2.new(1, -2 * (PADDING + SIDE_ROOM), 0, 30), 20)
	status.Position = UDim2.fromOffset(PADDING + SIDE_ROOM, 10)
	-- Long lines (an auction with a long street name) shrink to fit rather than lose their end.
	status.TextScaled = true
	local statusLimit = Instance.new("UITextSizeConstraint")
	statusLimit.MaxTextSize = 20
	statusLimit.MinTextSize = 12
	statusLimit.Parent = status
	local dice = Dice.new(frame)
	dice.frame.AnchorPoint = Vector2.new(1, 0)
	dice.frame.Position = UDim2.new(1, -PADDING - 4, 0, 8)
	status.TextWrapped = false
	status.TextTruncate = Enum.TextTruncate.AtEnd
	local buttons = Ui.frame("Buttons", UDim2.new(1, -2 * PADDING, 0, 48), frame)
	buttons.Position = UDim2.fromOffset(PADDING, 50)
	Ui.list(buttons, Enum.FillDirection.Horizontal, BUTTON_GAP)
	-- The turn clock: a thin bar along the top edge that drains as the decision time runs out.
	local track = Instance.new("Frame")
	track.Name = "TimerTrack"
	track.Size = UDim2.new(1, -32, 0, 4)
	track.Position = UDim2.fromOffset(16, 4)
	track.BackgroundColor3 = Theme.color.surfaceHigh
	track.BorderSizePixel = 0
	track.Visible = false
	track.Parent = frame
	Ui.corner(track, 2)
	local timer = Instance.new("Frame")
	timer.Name = "Timer"
	timer.Size = UDim2.fromScale(1, 1)
	timer.BackgroundColor3 = Theme.color.accent
	timer.BorderSizePixel = 0
	timer.Visible = false
	timer.Parent = track
	Ui.corner(timer, 2)
	return setmetatable({ frame = frame, status = status, buttons = buttons, dice = dice, track = track, timer = timer }, ActionBar)
end

function ActionBar.setStatus(self: ActionBar, text: string, color: Color3)
	self.status.Text = text
	self.status.TextColor3 = color
end

-- Shows how much of the decision time is left (0-1); nil hides the clock.
function ActionBar.setTimer(self: ActionBar, fraction: number?, urgent: boolean)
	self.track.Visible = fraction ~= nil
	self.timer.Visible = fraction ~= nil
	if fraction then
		self.timer.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		self.timer.BackgroundColor3 = if urgent then Theme.color.danger else Theme.color.accent
	end
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
