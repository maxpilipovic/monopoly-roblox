--!strict
-- The draw for who goes first: a reel spins through every player's face (a robot for bots), slows
-- and lands on the player in the first seat, then the second, and so on, each joining the order list.
-- Its timing matches Pacing.turnOrderSeconds, so the first turn starts as it finishes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Pacing = require(ReplicatedStorage.Shared.Rules.Pacing)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local TurnOrderSpin = {}
TurnOrderSpin.__index = TurnOrderSpin

export type Entry = { name: string, userId: number? } -- no userId: a bot

export type TurnOrderSpin = typeof(setmetatable(
	{} :: {
		frame: Frame,
		face: ImageLabel,
		botFace: TextLabel,
		reelName: TextLabel,
		list: Frame,
		generation: number,
	},
	TurnOrderSpin
))

local GOLD = Color3.fromRGB(222, 190, 110)
local ORDINALS = { "1st", "2nd", "3rd", "4th", "5th", "6th" }

local function headshot(userId: number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

function TurnOrderSpin.new(parent: Instance): TurnOrderSpin
	local frame = Ui.panel("TurnOrder", UDim2.fromOffset(560, 340), UDim2.fromScale(0.5, 0.45), Vector2.new(0.5, 0.5), parent)
	frame.Visible = false
	frame.ZIndex = 25
	local title = Ui.label("Title", frame, UDim2.new(1, 0, 0, 44), 28, Theme.font.display)
	title.Position = UDim2.fromOffset(0, 12)
	title.TextColor3 = GOLD
	title.Text = "Who goes first?"

	local reel = Ui.surface("Reel", UDim2.fromOffset(200, 220), frame)
	reel.Position = UDim2.fromOffset(24, 76)
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.fromOffset(150, 150)
	ring.AnchorPoint = Vector2.new(0.5, 0)
	ring.Position = UDim2.new(0.5, 0, 0, 14)
	ring.BackgroundColor3 = Theme.color.surfaceHigh
	ring.Parent = reel
	Ui.corner(ring, 75)
	Ui.stroke(ring, GOLD, 3, 0)
	local face = Instance.new("ImageLabel")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundTransparency = 1
	face.Parent = ring
	Ui.corner(face, 75)
	local botFace = Ui.label("BotFace", ring, UDim2.fromScale(1, 1), 80, Theme.font.display)
	botFace.Text = "🤖"
	local reelName = Ui.label("ReelName", reel, UDim2.new(1, -12, 0, 34), 20, Theme.font.display)
	reelName.Position = UDim2.new(0, 6, 1, -44)
	reelName.TextTruncate = Enum.TextTruncate.AtEnd
	reelName.TextWrapped = false

	local list = Ui.frame("Order", UDim2.new(1, -260, 0, 240), frame)
	list.Position = UDim2.fromOffset(244, 76)
	Ui.list(list, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)

	return setmetatable({ frame = frame, face = face, botFace = botFace, reelName = reelName, list = list, generation = 0 }, TurnOrderSpin)
end

local function showOnReel(self: TurnOrderSpin, entry: Entry)
	self.reelName.Text = entry.name
	if entry.userId then
		self.face.Image = headshot(entry.userId)
		self.face.Visible = true
		self.botFace.Visible = false
	else
		self.face.Visible = false
		self.botFace.Visible = true
	end
end

local function addRow(self: TurnOrderSpin, seat: number, entry: Entry)
	local row = Ui.surface(`Seat{seat}`, UDim2.new(1, 0, 0, 34), self.list)
	row.LayoutOrder = seat
	local place = Ui.label("Place", row, UDim2.fromOffset(52, 34), 18, Theme.font.display)
	place.TextColor3 = GOLD
	place.Text = ORDINALS[seat] or `{seat}th`
	local name = Ui.label("Name", row, UDim2.new(1, -60, 1, 0), 17, Theme.font.bodyBold)
	name.Position = UDim2.fromOffset(56, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextWrapped = false
	name.Text = entry.name
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = row
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Plays the draw for `order` (seat 1 first), then hides itself.
function TurnOrderSpin.play(self: TurnOrderSpin, order: { Entry })
	self.generation += 1
	local generation = self.generation
	Ui.clear(self.list)
	self.frame.Visible = #order > 0
	if #order == 0 then
		return
	end
	task.spawn(function()
		local function stale(): boolean
			return self.generation ~= generation or self.frame.Parent == nil
		end
		-- Everything runs to deadlines from the start, so frame rounding never lets the draw outlast
		-- the time the game gives it.
		local started = os.clock()
		local function waitUntil(time: number)
			local left = time - os.clock()
			if left > 0 then
				task.wait(left)
			end
		end
		for seat, winner in order do
			-- Spin fast, slow down, and stop on this seat's player.
			local seatStart = started + (seat - 1) * Pacing.SPIN_SECONDS
			local spinTime = Pacing.SPIN_SECONDS * 0.8
			local index = seat
			while true do
				local elapsed = os.clock() - seatStart
				local step = 0.05 + 0.25 * (elapsed / spinTime) ^ 2
				if elapsed + step >= spinTime or stale() then
					break
				end
				index = index % #order + 1
				showOnReel(self, order[index])
				task.wait(step)
			end
			waitUntil(seatStart + spinTime)
			if stale() then
				return
			end
			showOnReel(self, winner)
			addRow(self, seat, winner)
			waitUntil(seatStart + Pacing.SPIN_SECONDS)
		end
		waitUntil(started + Pacing.turnOrderSeconds(#order) - 0.1)
		if not stale() then
			self.frame.Visible = false
		end
	end)
end

function TurnOrderSpin.hide(self: TurnOrderSpin)
	self.generation += 1
	self.frame.Visible = false
end

return TurnOrderSpin
