--!strict
-- A drawn card, centre screen: it lands face down in its deck's colour, flips, and shows what it says
-- with a badge for what it does. Clicking it sends it away.

local TweenService = game:GetService("TweenService")
local CardFace = require(script.Parent.Parent.CardFace)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local CardReveal = {}
CardReveal.__index = CardReveal

local SIZE = Vector2.new(280, 384)
local RADIUS = 18
local FACE_DOWN_SECONDS = 0.45
local FLIP_HALF_SECONDS = 0.14

local DECK_COLORS = {
	Chance = Theme.color.chance,
	CommunityChest = Theme.color.chest,
	Jail = Theme.color.danger,
}
local TONE_COLORS = {
	good = Theme.color.primary,
	bad = Theme.color.danger,
	neutral = Theme.color.secondary,
}

export type CardReveal = typeof(setmetatable(
	{} :: {
		frame: Frame,
		scale: UIScale,
		card: TextButton,
		back: Frame,
		backTitle: TextLabel,
		mark: TextLabel,
		front: Frame,
		header: Frame,
		headerFill: Frame,
		title: TextLabel,
		drawer: TextLabel,
		text: TextLabel,
		badge: TextLabel,
		face: CardFace.Face?,
		generation: number,
	},
	CardReveal
))

local function side(name: string, parent: Instance): Frame
	-- Fixed size and centred, so narrowing the card clips it like a card turning edge-on.
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromOffset(SIZE.X, SIZE.Y)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Ui.corner(frame, RADIUS)
	return frame
end

function CardReveal.new(parent: Instance, onDismiss: () -> ()): CardReveal
	local frame = Ui.frame("CardReveal", UDim2.fromOffset(SIZE.X, SIZE.Y), parent)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.42)
	frame.Visible = false
	frame.ZIndex = 20 -- over the deed card and the windows
	local scale = Instance.new("UIScale")
	scale.Parent = frame

	local card = Instance.new("TextButton")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.BackgroundTransparency = 1
	card.AutoButtonColor = false
	card.Text = ""
	card.ClipsDescendants = true
	card.Parent = frame
	card.Activated:Connect(onDismiss)

	-- Face down: the deck's colour, a framed question mark, the deck's name.
	local back = side("Back", card)
	local inner = Ui.frame("Border", UDim2.new(1, -24, 1, -24), back)
	inner.Position = UDim2.fromOffset(12, 12)
	Ui.corner(inner, RADIUS - 6)
	Ui.stroke(inner, Color3.new(1, 1, 1), 3, 0.35)
	local mark = Ui.label("Mark", back, UDim2.new(1, 0, 0, 170), 150, Theme.font.display)
	mark.Position = UDim2.fromOffset(0, 70)
	mark.Text = "?"
	local backTitle = Ui.label("DeckTitle", back, UDim2.new(1, -40, 0, 34), 26, Theme.font.display)
	backTitle.Position = UDim2.new(0, 20, 1, -84)

	-- Face up: cream paper under a band in the deck's colour.
	local front = side("Front", card)
	front.BackgroundColor3 = Theme.color.paper
	Ui.stroke(front, Theme.color.ink, 2, 0.7) -- the paper needs an edge against the pale board
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 68)
	header.BorderSizePixel = 0
	header.Parent = front
	Ui.corner(header, RADIUS)
	-- Squares off the band's bottom corners.
	local headerFill = Instance.new("Frame")
	headerFill.Name = "HeaderFill"
	headerFill.Size = UDim2.new(1, 0, 0, 30)
	headerFill.Position = UDim2.fromOffset(0, 38)
	headerFill.BorderSizePixel = 0
	headerFill.Parent = front
	local title = Ui.label("Title", front, UDim2.new(1, -24, 0, 68), 26, Theme.font.display)
	title.Position = UDim2.fromOffset(12, 0)
	title.ZIndex = 2

	local drawer = Ui.label("Drawer", front, UDim2.new(1, -32, 0, 20), 14, Theme.font.bodyBold)
	drawer.Position = UDim2.fromOffset(16, 82)
	drawer.TextColor3 = Theme.color.ink
	drawer.TextTransparency = 0.45
	drawer.TextWrapped = false
	drawer.TextTruncate = Enum.TextTruncate.AtEnd

	local text = Ui.label("Text", front, UDim2.new(1, -44, 0, 150), 21, Theme.font.bodyBold)
	text.Position = UDim2.fromOffset(22, 110)
	text.TextColor3 = Theme.color.ink

	local badge = Ui.label("Badge", front, UDim2.new(1, -44, 0, 46), 20, Theme.font.display)
	badge.Position = UDim2.new(0, 22, 1, -92)
	badge.BackgroundTransparency = 0
	badge.TextWrapped = true
	Ui.corner(badge, 12)
	Ui.padding(badge, { left = 8, right = 8 })

	local hint = Ui.label("Hint", front, UDim2.new(1, 0, 0, 16), 12, Theme.font.body)
	hint.Position = UDim2.new(0, 0, 1, -30)
	hint.TextColor3 = Theme.color.ink
	hint.TextTransparency = 0.55
	hint.Text = "Click to dismiss"

	return setmetatable({
		frame = frame,
		scale = scale,
		card = card,
		back = back,
		backTitle = backTitle,
		mark = mark,
		front = front,
		header = header,
		headerFill = headerFill,
		title = title,
		drawer = drawer,
		text = text,
		badge = badge,
		face = nil,
		generation = 0,
	}, CardReveal)
end

local function tween(instance: Instance, seconds: number, style: Enum.EasingStyle, direction: Enum.EasingDirection, goal: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(seconds, style, direction), goal):Play()
end

-- Shows a card (nil hides at once). The same face again changes nothing; a new one plays the reveal.
function CardReveal.show(self: CardReveal, face: CardFace.Face?)
	if face == self.face then
		return
	end
	self.face = face
	self.generation += 1
	local generation = self.generation
	if not face then
		self.frame.Visible = false
		return
	end

	local deckColor = DECK_COLORS[face.deck] or Theme.color.secondary
	self.back.BackgroundColor3 = deckColor
	self.backTitle.Text = face.title
	self.header.BackgroundColor3 = deckColor
	self.headerFill.BackgroundColor3 = deckColor
	self.title.Text = face.title
	self.drawer.Text = face.caption
	self.mark.Text = face.mark
	self.text.Text = face.text
	self.badge.Text = face.badge.text
	self.badge.BackgroundColor3 = TONE_COLORS[face.badge.tone] or Theme.color.secondary
	self.badge.Visible = face.badge.text ~= ""
	-- A long badge (repairs) needs two lines.
	self.badge.TextSize = if #face.badge.text > 22 then 15 else 20

	-- Land face down with a pop and a little tilt.
	self.back.Visible = true
	self.front.Visible = false
	self.card.Size = UDim2.fromScale(1, 1)
	self.card.Rotation = -6
	self.scale.Scale = 0.6
	self.frame.Visible = true
	tween(self.scale, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
	tween(self.card, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Rotation = 0 })

	task.spawn(function()
		local function stale(): boolean
			return self.generation ~= generation or self.frame.Parent == nil
		end
		task.wait(FACE_DOWN_SECONDS)
		if stale() then
			return
		end
		-- Flip: narrow to an edge, swap sides, widen again.
		tween(self.card, FLIP_HALF_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Size = UDim2.fromScale(0, 1) })
		task.wait(FLIP_HALF_SECONDS)
		if stale() then
			return
		end
		self.back.Visible = false
		self.front.Visible = true
		tween(self.card, FLIP_HALF_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Size = UDim2.fromScale(1, 1) })
	end)
end

return CardReveal
