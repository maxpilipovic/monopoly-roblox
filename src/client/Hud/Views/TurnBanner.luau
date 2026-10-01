--!strict
-- "YOUR TURN": a gold banner that drops in under the top edge when the turn becomes yours.

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local TurnBanner = {}
TurnBanner.__index = TurnBanner

TurnBanner.SECONDS = 1.4
local REST_Y = 14
local HIDDEN_Y = -80

export type TurnBanner = typeof(setmetatable({} :: { frame: Frame, generation: number }, TurnBanner))

function TurnBanner.new(parent: Instance): TurnBanner
	local frame = Instance.new("Frame")
	frame.Name = "TurnBanner"
	frame.Size = UDim2.fromOffset(300, 58)
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, HIDDEN_Y)
	frame.BackgroundColor3 = Theme.color.accent
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 15
	frame.Parent = parent
	Ui.corner(frame, Theme.radius.panel)
	Ui.stroke(frame, Theme.color.accentLip, 3, 0)
	local text = Ui.label("Text", frame, UDim2.fromScale(1, 1), 30, Theme.font.display)
	text.TextColor3 = Theme.color.ink
	text.Text = "YOUR TURN"
	return setmetatable({ frame = frame, generation = 0 }, TurnBanner)
end

function TurnBanner.play(self: TurnBanner)
	self.generation += 1
	local generation = self.generation
	local frame = self.frame
	frame.Position = UDim2.new(0.5, 0, 0, HIDDEN_Y)
	frame.Visible = true
	TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, REST_Y),
	}):Play()
	task.delay(TurnBanner.SECONDS, function()
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
