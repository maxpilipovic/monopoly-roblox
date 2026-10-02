--!strict
-- Short messages just for you (why an action was refused), stacked above the action bar.

local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local Toasts = {}
Toasts.__index = Toasts

Toasts.SECONDS = 3
local MAX_SHOWN = 3

export type Toasts = typeof(setmetatable({} :: { frame: Frame }, Toasts))

function Toasts.new(parent: Instance, bottomOffset: number): Toasts
	local frame = Ui.frame("Toasts", UDim2.fromOffset(460, 0), parent)
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -bottomOffset)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.ZIndex = 30 -- a refusal must be readable over any panel
	Ui.list(frame, Enum.FillDirection.Vertical, Theme.space.xs, nil, Enum.VerticalAlignment.Bottom)
	return setmetatable({ frame = frame }, Toasts)
end

local function toasts(self: Toasts): { Frame }
	local list = {}
	for _, child in self.frame:GetChildren() do
		if child:IsA("Frame") then
			table.insert(list, child)
		end
	end
	table.sort(list, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return list
end

function Toasts.show(self: Toasts, message: string)
	local existing = toasts(self)
	while #existing >= MAX_SHOWN do
		(table.remove(existing, 1) :: Frame):Destroy()
	end
	local last = existing[#existing]

	local toast = Ui.surface("Toast", UDim2.new(1, 0, 0, 38), self.frame)
	toast.LayoutOrder = if last then last.LayoutOrder + 1 else 1
	toast.BackgroundColor3 = Theme.color.panel
	Ui.stroke(toast, Theme.color.danger, 1.5, 0.3)
	local text = Ui.label("Text", toast, UDim2.new(1, -24, 1, 0), 15)
	text.Position = UDim2.fromOffset(12, 0)
	text.TextWrapped = false
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Text = message
	Ui.hide(toast)
	Ui.show(toast)
	task.delay(Toasts.SECONDS, function()
		toast:Destroy() -- harmless if the lobby already cleared it
	end)
end

function Toasts.clear(self: Toasts)
	Ui.clear(self.frame)
end

return Toasts
