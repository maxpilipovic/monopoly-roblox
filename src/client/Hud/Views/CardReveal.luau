--!strict
-- A drawn card, centre screen, printed like the real decks: orange Chance, yellow Community Chest
-- (steel-grey for the jail card), wide, with the deck's name across the top in heavy black ink, a
-- picture on the left and the words on the right (CardArt). It lands face down (the big question
-- mark, the chest or the officer under the deck's name), flips, and a shine crosses the face once.
-- A badge under the words says at a glance what the card does. Clicking it sends it away.

local TweenService = game:GetService("TweenService")
local CardArt = require(script.Parent.Parent.CardArt)
local CardFace = require(script.Parent.Parent.CardFace)
local CardStyle = require(script.Parent.Parent.CardStyle)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)
local Sounds = require(script.Parent.Parent.Parent.Sounds)

local CardReveal = {}
CardReveal.__index = CardReveal

local SIZE = Vector2.new(440, 272)
local RADIUS = 16
local INSET = 10 -- the printed border, inside the card's edge
local PICTURE = 150 -- the picture's square on the face
local MARGIN = 26
local WORDS_X = MARGIN + PICTURE + 14 -- where the words start when there's a picture
local FACE_DOWN_SECONDS = 0.55
local FLIP_HALF_SECONDS = 0.14
local SHINE_SECONDS = 0.65

-- On the bright card stock: a dark pill with the tone in its text colour.
local TONE_TEXT = {
	good = Theme.color.moneyUp,
	bad = Theme.color.moneyDown,
	neutral = Color3.new(1, 1, 1),
}

export type CardReveal = typeof(setmetatable(
	{} :: {
		frame: Frame,
		scale: UIScale,
		card: TextButton,
		back: Frame,
		backBorder: UIStroke,
		backInner: UIStroke,
		backTitle: TextLabel,
		backPicture: ImageLabel,
		front: Frame,
		frontBorder: UIStroke,
		title: TextLabel,
		rule: Frame,
		picture: ImageLabel,
		drawer: TextLabel,
		text: TextLabel,
		badge: TextLabel,
		hint: TextLabel,
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

-- A thin printed line round the card, `inset` in from its edge.
local function border(name: string, parent: Instance, inset: number, thickness: number): UIStroke
	local frame = Ui.frame(name, UDim2.new(1, -2 * inset, 1, -2 * inset), parent)
	frame.Position = UDim2.fromOffset(inset, inset)
	Ui.corner(frame, RADIUS - inset / 2)
	return Ui.stroke(frame, CardStyle.INK, thickness, 0)
end

local function image(name: string, parent: Instance, size: UDim2): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.Size = size
	label.BackgroundTransparency = 1
	label.ScaleType = Enum.ScaleType.Fit
	label.Parent = parent
	return label
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
	card.ClipsDescendants = false -- clips only while flipping
	card.Parent = frame
	card.Activated:Connect(function()
		Sounds.play("Close")
		onDismiss()
	end)

	-- Face down: the deck's stock in a double printed border, its big picture, its name.
	local back = side("Back", card)
	local backShade = Instance.new("UIGradient")
	backShade.Rotation = 60
	backShade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 210, 205))
	backShade.Parent = back
	local backBorder = border("Border", back, INSET, 3)
	local backInner = border("InnerBorder", back, INSET + 6, 1.5)
	local backPicture = image("Picture", back, UDim2.fromOffset(240, 158))
	backPicture.AnchorPoint = Vector2.new(0.5, 0)
	backPicture.Position = UDim2.new(0.5, 0, 0, 26)
	local backTitle = Ui.label("DeckTitle", back, UDim2.new(1, -60, 0, 52), 40, Theme.font.printed)
	backTitle.Position = UDim2.new(0, 30, 1, -82)
	backTitle.TextScaled = true
	local backTitleLimit = Instance.new("UITextSizeConstraint")
	backTitleLimit.MaxTextSize = 40
	backTitleLimit.Parent = backTitle

	-- Face up: the deck's name across the top, a rule, the picture left and the words right.
	local front = side("Front", card)
	local frontBorder = border("Border", front, INSET, 3)
	local title = Ui.label("Title", front, UDim2.new(1, -60, 0, 40), 32, Theme.font.printed)
	title.Position = UDim2.fromOffset(30, 16)
	title.TextScaled = true
	local titleLimit = Instance.new("UITextSizeConstraint")
	titleLimit.MaxTextSize = 32
	titleLimit.Parent = title
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.Size = UDim2.new(1, -2 * MARGIN, 0, 2)
	rule.Position = UDim2.fromOffset(MARGIN, 60)
	rule.BorderSizePixel = 0
	rule.Parent = front

	local picture = image("Picture", front, UDim2.fromOffset(PICTURE, PICTURE))
	picture.Position = UDim2.fromOffset(MARGIN, 76)

	local drawer = Ui.label("Drawer", front, UDim2.new(1, -WORDS_X - MARGIN, 0, 18), 14, Theme.font.bodyBold)
	drawer.Position = UDim2.fromOffset(WORDS_X, 70)
	drawer.TextTransparency = 0.4
	drawer.TextWrapped = false
	drawer.TextTruncate = Enum.TextTruncate.AtEnd

	local text = Ui.label("Text", front, UDim2.new(1, -WORDS_X - MARGIN, 0, 104), 20, Theme.font.bodyBold)
	text.Position = UDim2.fromOffset(WORDS_X, 90)

	local badge = Ui.label("Badge", front, UDim2.new(1, -WORDS_X - MARGIN, 0, 38), 19, Theme.font.display)
	badge.Position = UDim2.fromOffset(WORDS_X, 198)
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = CardStyle.INK
	badge.TextWrapped = true
	Ui.corner(badge, 10)
	Ui.padding(badge, { left = 8, right = 8 })

	local hint = Ui.label("Hint", front, UDim2.new(1, -WORDS_X - MARGIN, 0, 14), 11, Theme.font.body)
	hint.Position = UDim2.fromOffset(WORDS_X, 240)
	hint.TextTransparency = 0.5
	hint.Text = "Click to dismiss"

	-- A band of light that sweeps across the face once it's turned over.
	local shineClip = Ui.frame("ShineClip", UDim2.new(1, -12, 1, -12), front)
	shineClip.Position = UDim2.fromOffset(6, 6)
	shineClip.ClipsDescendants = true
	shineClip.ZIndex = 5
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(0.3, 0, 2, 0)
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
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	shineFade.Parent = shine

	return setmetatable({
		frame = frame,
		scale = scale,
		card = card,
		back = back,
		backBorder = backBorder,
		backInner = backInner,
		backTitle = backTitle,
		backPicture = backPicture,
		front = front,
		frontBorder = frontBorder,
		title = title,
		rule = rule,
		picture = picture,
		drawer = drawer,
		text = text,
		badge = badge,
		hint = hint,
		shine = shine,
		face = nil,
		generation = 0,
	}, CardReveal)
end

local function tween(instance: Instance, seconds: number, style: Enum.EasingStyle, direction: Enum.EasingDirection, goal: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(seconds, style, direction), goal):Play()
end

-- Light print on a dark back (the jail card's steel), ink on the bright stock.
local function printOn(color: Color3): Color3
	local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if luminance < 0.5 then Color3.fromRGB(235, 238, 244) else CardStyle.INK
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

	local style = CardStyle.deck(face.deck)
	local backInk = printOn(style.back)
	self.back.BackgroundColor3 = style.back
	self.backBorder.Color = backInk
	self.backInner.Color = backInk
	self.backTitle.TextColor3 = backInk
	self.backTitle.Text = string.upper(face.title)
	self.backPicture.Image = CardArt.back(face.deck) or ""

	self.front.BackgroundColor3 = style.face
	self.frontBorder.Color = style.ink
	self.rule.BackgroundColor3 = style.ink
	self.title.TextColor3 = style.bandText
	self.title.Text = string.upper(face.title)
	local art = CardArt.forCard(face.id)
	self.picture.Image = art or ""
	self.picture.Visible = art ~= nil
	-- Without a picture the words take the whole width.
	local wordsX = if art then WORDS_X else MARGIN
	for _, label in { self.drawer, self.text, self.badge, self.hint } do
		label.Position = UDim2.fromOffset(wordsX, label.Position.Y.Offset)
		label.Size = UDim2.new(1, -wordsX - MARGIN, 0, label.Size.Y.Offset)
		label.TextColor3 = style.ink
	end
	self.drawer.Text = face.caption
	self.text.Text = face.text
	self.badge.Text = face.badge.text
	self.badge.TextColor3 = TONE_TEXT[face.badge.tone] or TONE_TEXT.neutral
	self.badge.Visible = face.badge.text ~= ""
	-- A long badge (repairs) needs two lines.
	self.badge.TextSize = if #face.badge.text > 22 then 14 else 19
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
