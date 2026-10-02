--!strict
-- A banner that drops in under the top edge for a moment: "YOUR TURN" in gold, or a quieter one
-- that says where a token just landed.

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local TurnBanner = {}
TurnBanner.__index = TurnBanner

TurnBanner.SECONDS = 1.4
local REST_Y = 14
local HIDDEN_Y = -80

export type Style = {
	name: string,
	text: string, -- what it says unless `play` is given something else
	width: number,
	textSize: number,
	color: Color3,
	textColor: Color3,
	strokeColor: Color3,
	seconds: number,
}

TurnBanner.YOUR_TURN = table.freeze({
	name = "TurnBanner",
	text = "YOUR TURN",
	width = 300,
	textSize = 30,
	color = Theme.color.accent,
	textColor = Theme.color.ink,
	strokeColor = Theme.color.accentLip,
	seconds = 1.4,
}) :: Style

TurnBanner.LANDING = table.freeze({
	name = "LandingBanner",
	text = "",
	width = 460,
	textSize = 21,
	color = Theme.color.panel,
	textColor = Theme.color.text,
	strokeColor = Theme.color.accent,
	seconds = 1.8,
}) :: Style

export type TurnBanner = typeof(setmetatable(
	{} :: { frame: Frame, label: TextLabel, style: Style, generation: number },
	TurnBanner
))

function TurnBanner.new(parent: Instance, style: Style?): TurnBanner
	local look = style or TurnBanner.YOUR_TURN
	local frame = Instance.new("Frame")
	frame.Name = look.name
	frame.Size = UDim2.fromOffset(look.width, 58)
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, HIDDEN_Y)
	frame.BackgroundColor3 = look.color
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 15
	frame.Parent = parent
	Ui.corner(frame, Theme.radius.panel)
	Ui.stroke(frame, look.strokeColor, 3, 0)
	local label = Ui.label("Text", frame, UDim2.new(1, -24, 1, 0), look.textSize, Theme.font.display)
	label.Position = UDim2.fromOffset(12, 0)
	label.TextColor3 = look.textColor
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = look.text
	return setmetatable({ frame = frame, label = label, style = look, generation = 0 }, TurnBanner)
end

function TurnBanner.play(self: TurnBanner, text: string?)
	self.generation += 1
	local generation = self.generation
	local frame = self.frame
	if text then
		self.label.Text = text
	end
	frame.Position = UDim2.new(0.5, 0, 0, HIDDEN_Y)
	frame.Visible = true
	TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, REST_Y),
	}):Play()
	task.delay(self.style.seconds, function()
		if self.generation ~= generation or not frame.Parent then
			return -- played again since, or the HUD is gone
		end
		TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, HIDDEN_Y),
		}):Play()
		task.wait(0.2)
		if self.generation == generation and frame.Parent then
			frame.Visible = false
		end
	end)
end

function TurnBanner.hide(self: TurnBanner)
	self.generation += 1
	self.frame.Visible = false
end

return TurnBanner
