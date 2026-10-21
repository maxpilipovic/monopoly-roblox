--!strict
-- A drawn card, centre screen. It lands face down (midnight for Chance, charcoal for Community Chest,
-- steel for jail, each in a gold foil frame around its turning 3D emblem), flips, and shows what it
-- says on parchment, with a badge for what it does. A foil shine crosses the face once. No hue on
-- these cards: colour belongs to the properties. Clicking it sends it away.

local TweenService = game:GetService("TweenService")
local CardFace = require(script.Parent.Parent.CardFace)
local CardStyle = require(script.Parent.Parent.CardStyle)
local EmblemView = require(script.Parent.Parent.EmblemView)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)
local Sounds = require(script.Parent.Parent.Parent.Sounds)

local CardReveal = {}
CardReveal.__index = CardReveal

local SIZE = Vector2.new(280, 384)
local RADIUS = 18
local FACE_DOWN_SECONDS = 0.55
local FLIP_HALF_SECONDS = 0.14
local SHINE_SECONDS = 0.65
local BAR_COUNT = 5 -- iron bars on the jail card

local TONE_TEXT = {
	good = Theme.color.moneyUp,
	bad = Theme.color.moneyDown,
	neutral = CardStyle.GOLD,
}

export type CardReveal = typeof(setmetatable(
	{} :: {
		frame: Frame,
		scale: UIScale,
		card: TextButton,
		back: Frame,
		backFoil: UIStroke,
		backTitle: TextLabel,
		backEmblem: EmblemView.EmblemView,
		bars: Frame,
		front: Frame,
		header: Frame,
		headerFill: Frame,
		foilLine: Frame,
		title: TextLabel,
		frontEmblem: EmblemView.EmblemView,
		drawer: TextLabel,
		text: TextLabel,
		badge: TextLabel,
		shine: Frame,
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

-- Vertical iron bars across the jail card's emblem space.
local function makeBars(parent: Instance): Frame
	local bars = Ui.frame("Bars", UDim2.fromOffset(170, 170), parent)
	bars.AnchorPoint = Vector2.new(0.5, 0)
	bars.Position = UDim2.new(0.5, 0, 0, 58)
	for index = 1, BAR_COUNT do
		local bar = Instance.new("Frame")
		bar.Name = `Bar{index}`
		bar.Size = UDim2.new(0, 12, 1, 0)
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.Position = UDim2.fromScale((index - 0.5) / BAR_COUNT, 0)
		bar.BackgroundColor3 = Color3.fromRGB(196, 202, 212)
		bar.BorderSizePixel = 0
		bar.Parent = bars
		Ui.corner(bar, 6)
		local shade = Instance.new("UIGradient")
		shade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 126, 138))
		shade.Parent = bar
	end
	for _, y in { 0.12, 0.88 } do
		local rail = Instance.new("Frame")
		rail.Size = UDim2.new(1, 10, 0, 10)
		rail.AnchorPoint = Vector2.new(0.5, 0.5)
		rail.Position = UDim2.fromScale(0.5, y)
		rail.BackgroundColor3 = Color3.fromRGB(150, 156, 168)
		rail.BorderSizePixel = 0
		rail.Parent = bars
		Ui.corner(rail, 5)
	end
	return bars
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
	-- Clips only while flipping: Roblox doesn't draw a ViewportFrame (the emblem) under a clipping
	-- ancestor.
	card.ClipsDescendants = false
	card.Parent = frame
	card.Activated:Connect(function()
		Sounds.play("Close")
		onDismiss()
	end)

	-- Face down: the deck's dark ground, a gold foil frame, the emblem, the deck's name.
	local back = side("Back", card)
	local backShade = Instance.new("UIGradient")
	backShade.Rotation = 60
	backShade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 160))
	backShade.Parent = back
	local border = Ui.frame("Border", UDim2.new(1, -24, 1, -24), back)
	border.Position = UDim2.fromOffset(12, 12)
	Ui.corner(border, RADIUS - 6)
	local backFoil = Ui.stroke(border, CardStyle.GOLD, 2, 0.1)
	local innerBorder = Ui.frame("InnerBorder", UDim2.new(1, -36, 1, -36), back)
	innerBorder.Position = UDim2.fromOffset(18, 18)
	Ui.corner(innerBorder, RADIUS - 10)
	Ui.stroke(innerBorder, CardStyle.GOLD, 1, 0.55)
	local backEmblem = EmblemView.new("Emblem", back, UDim2.fromOffset(200, 200), 150)
	backEmblem.frame.AnchorPoint = Vector2.new(0.5, 0)
	backEmblem.frame.Position = UDim2.new(0.5, 0, 0, 44)
	local bars = makeBars(back)
	local backTitle = Ui.label("DeckTitle", back, UDim2.new(1, -40, 0, 34), 26, Theme.font.display)
	backTitle.Position = UDim2.new(0, 20, 1, -92)
	backTitle.TextColor3 = CardStyle.GOLD

	-- Face up: parchment under a dark band, a foil line, the emblem beside the title.
	local front = side("Front", card)
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
	local foilLine = Instance.new("Frame")
	foilLine.Name = "FoilLine"
	foilLine.Size = UDim2.new(1, 0, 0, 3)
	foilLine.Position = UDim2.fromOffset(0, 68)
	foilLine.BackgroundColor3 = CardStyle.GOLD
	foilLine.BorderSizePixel = 0
	foilLine.Parent = front
	local frontEmblem = EmblemView.new("Emblem", front, UDim2.fromOffset(56, 56), 34)
	frontEmblem.frame.Position = UDim2.fromOffset(8, 6)
	frontEmblem.frame.ZIndex = 2
	local title = Ui.label("Title", front, UDim2.new(1, -84, 0, 68), 26, Theme.font.display)
	title.Position = UDim2.fromOffset(64, 0)
	title.ZIndex = 2

	local drawer = Ui.label("Drawer", front, UDim2.new(1, -32, 0, 20), 14, Theme.font.bodyBold)
	drawer.Position = UDim2.fromOffset(16, 84)
	drawer.TextTransparency = 0.45
	drawer.TextWrapped = false
	drawer.TextTruncate = Enum.TextTruncate.AtEnd

	local text = Ui.label("Text", front, UDim2.new(1, -44, 0, 150), 21, Theme.font.bodyBold)
	text.Position = UDim2.fromOffset(22, 112)

	local badge = Ui.label("Badge", front, UDim2.new(1, -44, 0, 46), 20, Theme.font.display)
	badge.Position = UDim2.new(0, 22, 1, -92)
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = CardStyle.INK
	badge.TextWrapped = true
	Ui.corner(badge, 12)
	Ui.padding(badge, { left = 8, right = 8 })
	Ui.stroke(badge, CardStyle.GOLD, 1, 0.5)

	local hint = Ui.label("Hint", front, UDim2.new(1, 0, 0, 16), 12, Theme.font.body)
	hint.Position = UDim2.new(0, 0, 1, -30)
	hint.TextColor3 = Theme.color.ink
	hint.TextTransparency = 0.55
	hint.Text = "Click to dismiss"

	-- A band of light that sweeps across the face once it's turned over, in its own clipping layer
	-- so the emblem beside the title isn't under a clipping ancestor.
	local shineClip = Ui.frame("ShineClip", UDim2.new(1, -12, 1, -12), front)
	shineClip.Position = UDim2.fromOffset(6, 6)
	shineClip.ClipsDescendants = true
	shineClip.ZIndex = 5
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(0.4, 0, 1.6, 0)
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.fromScale(-0.4, 0.5)
	shine.Rotation = 18
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BorderSizePixel = 0
	shine.ZIndex = 5
	shine.Parent = shineClip
	local shineFade = Instance.new("UIGradient")
	shineFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	shineFade.Parent = shine

	return setmetatable({
		frame = frame,
		scale = scale,
		card = card,
		back = back,
		backFoil = backFoil,
		backTitle = backTitle,
		backEmblem = backEmblem,
		bars = bars,
		front = front,
		header = header,
		headerFill = headerFill,
		foilLine = foilLine,
		title = title,
		frontEmblem = frontEmblem,
		drawer = drawer,
		text = text,
		badge = badge,
		shine = shine,
		face = nil,
		generation = 0,
	}, CardReveal)
end

local function tween(instance: Instance, seconds: number, style: Enum.EasingStyle, direction: Enum.EasingDirection, goal: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(seconds, style, direction), goal):Play()
end

local FALLBACK_MARKS = { Question = "?", Chest = "$" }

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

	local style = CardStyle.deck(face.deck)
	local emblem = style.emblem
	local fallback = if emblem then FALLBACK_MARKS[emblem] or face.mark else ""
	self.back.BackgroundColor3 = style.back
	self.backTitle.Text = face.title
	self.backEmblem:set(emblem, fallback, style.foil)
	self.bars.Visible = face.deck == "Jail"
	self.front.BackgroundColor3 = style.face
	self.header.BackgroundColor3 = style.band
	self.headerFill.BackgroundColor3 = style.band
	self.frontEmblem:set(emblem, fallback, style.foil)
	self.frontEmblem.frame.Visible = emblem ~= nil
	self.title.TextColor3 = style.bandText
	self.title.Text = face.title
	self.title.Position = UDim2.fromOffset(if emblem then 64 else 12, 0)
	self.title.Size = UDim2.new(1, if emblem then -84 else -24, 0, 68)
	self.drawer.TextColor3 = style.ink
	self.drawer.Text = face.caption
	self.text.TextColor3 = style.ink
	self.text.Text = face.text
	self.badge.Text = face.badge.text
	self.badge.TextColor3 = TONE_TEXT[face.badge.tone] or CardStyle.GOLD
	self.badge.Visible = face.badge.text ~= ""
	-- A long badge (repairs) needs two lines.
	self.badge.TextSize = if #face.badge.text > 22 then 15 else 20
	self.shine.Position = UDim2.fromScale(-0.4, 0.5)

	-- Land face down with a pop and a little tilt.
	self.back.Visible = true
	self.front.Visible = false
	self.card.Size = UDim2.fromScale(1, 1)
	self.card.ClipsDescendants = false -- in case a flip was cut short by this card
	self.card.Rotation = -6
	self.scale.Scale = 0.6
	self.frame.Visible = true
	tween(self.scale, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
	tween(self.card, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Rotation = 0 })
	-- The foil catches the light while it waits.
	self.backFoil.Transparency = 0.6
	tween(self.backFoil, FACE_DOWN_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, { Transparency = 0 })

	task.spawn(function()
		local function stale(): boolean
			return self.generation ~= generation or self.frame.Parent == nil
		end
		task.wait(FACE_DOWN_SECONDS)
		if stale() then
			return
		end
		-- Flip: narrow to an edge, swap sides, widen again.
		self.card.ClipsDescendants = true
		tween(self.card, FLIP_HALF_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Size = UDim2.fromScale(0, 1) })
		task.wait(FLIP_HALF_SECONDS)
		if stale() then
			return
		end
		self.back.Visible = false
		self.front.Visible = true
		tween(self.card, FLIP_HALF_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Size = UDim2.fromScale(1, 1) })
		task.wait(FLIP_HALF_SECONDS)
		self.card.ClipsDescendants = false
		if stale() then
			return
		end
		tween(self.shine, SHINE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, { Position = UDim2.fromScale(1.4, 0.5) })
	end)
end

return CardReveal
