--!strict
-- A property's deed, centre screen while it's being bought or auctioned (or when you look one up).

local DeedModel = require(script.Parent.Parent.DeedModel)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local DeedCard = {}
DeedCard.__index = DeedCard

local WIDTH = 250
local PLAIN_BAND = Theme.color.ink -- railroads and utilities have no colour group
local KIND_CAPTIONS = { Property = "TITLE DEED", Railroad = "RAILROAD", Utility = "UTILITY" }

export type DeedCard = typeof(setmetatable(
	{} :: {
		frame: Frame,
		onClose: () -> (),
		deed: DeedModel.Deed?,
		note: string?,
		closable: boolean,
	},
	DeedCard
))

function DeedCard.new(parent: Instance, onClose: () -> ()): DeedCard
	local frame = Instance.new("Frame")
	frame.Name = "Deed"
	frame.Size = UDim2.fromOffset(WIDTH, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.42)
	frame.BackgroundColor3 = Theme.color.paper
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 5
	frame.Parent = parent
	Ui.corner(frame, Theme.radius.panel)
	Ui.stroke(frame, Theme.color.ink, 2, 0.6)
	Ui.list(frame, Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	Ui.padding(frame, { bottom = 10 })
	return setmetatable({ frame = frame, onClose = onClose, deed = nil, note = nil, closable = false }, DeedCard)
end

-- Dark text on light bands (yellow, light blue), white on the rest.
local function readableOn(color: Color3): Color3
	local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return if luminance > 0.6 then Theme.color.ink else Color3.new(1, 1, 1)
end

local function row(parent: Instance, order: number, label: string, value: string, emphasis: "current" | "normal" | "dim"): Frame
	local frame = Ui.frame(label, UDim2.new(1, -20, 0, 22), parent)
	frame.LayoutOrder = order
	if emphasis == "current" then
		-- The rent that applies right now.
		frame.BackgroundTransparency = 0
		frame.BackgroundColor3 = Theme.color.accent
		Ui.corner(frame, 6)
	end
	local font = if emphasis == "current" then Theme.font.bodyBold else Theme.font.body
	local transparency = if emphasis == "dim" then 0.4 else 0
	local left = Ui.label("Label", frame, UDim2.new(0.6, -8, 1, 0), 15, font)
	left.Position = UDim2.fromOffset(8, 0)
	left.TextXAlignment = Enum.TextXAlignment.Left
	left.TextColor3 = Theme.color.ink
	left.TextTransparency = transparency
	left.TextWrapped = false
	left.Text = label
	local right = Ui.label("Value", frame, UDim2.new(0.4, -8, 1, 0), 15, Theme.font.bodyBold)
	right.Position = UDim2.fromScale(0.6, 0)
	right.TextXAlignment = Enum.TextXAlignment.Right
	right.TextColor3 = Theme.color.ink
	right.TextTransparency = transparency
	right.TextWrapped = false
	right.Text = value
	return frame
end

local function divider(parent: Instance, order: number)
	local holder = Ui.frame("Divider", UDim2.new(1, -20, 0, 9), parent)
	holder.LayoutOrder = order
	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.new(0, 0, 0.5, 0)
	line.BackgroundColor3 = Theme.color.ink
	line.BackgroundTransparency = 0.8
	line.BorderSizePixel = 0
	line.Parent = holder
end

-- Shows a deed (nil hides). `note` is a line under it (the auction's high bid); `closable` adds a
-- close button for deeds the player opened themselves.
function DeedCard.render(self: DeedCard, deed: DeedModel.Deed?, note: string?, closable: boolean)
	if deed == self.deed and note == self.note and closable == self.closable then
		return -- called every frame; rebuild only for something new
	end
	self.deed = deed
	self.note = note
	self.closable = closable
	Ui.clear(self.frame)
	if not deed then
		self.frame.Visible = false
		return
	end

	local bandColor = deed.color or PLAIN_BAND
	local onBand = readableOn(bandColor)
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.Size = UDim2.new(1, 0, 0, 66)
	band.BackgroundColor3 = bandColor
	band.BorderSizePixel = 0
	band.LayoutOrder = 1
	band.Parent = self.frame
	Ui.corner(band, Theme.radius.panel)
	-- Squares off the band's bottom corners.
	local bandFill = Instance.new("Frame")
	bandFill.Name = "BandFill"
	bandFill.Size = UDim2.new(1, 0, 0, 20)
	bandFill.AnchorPoint = Vector2.new(0, 1)
	bandFill.Position = UDim2.fromScale(0, 1)
	bandFill.BackgroundColor3 = bandColor
	bandFill.BorderSizePixel = 0
	bandFill.Parent = band
	local caption = Ui.label("Caption", band, UDim2.new(1, 0, 0, 14), 11, Theme.font.bodyBold)
	caption.Position = UDim2.fromOffset(0, 9)
	caption.TextColor3 = onBand
	caption.TextTransparency = 0.25
	caption.Text = KIND_CAPTIONS[deed.kind] or ""
	local name = Ui.label("Name", band, UDim2.new(1, -24, 0, 40), 19, Theme.font.display)
	name.Position = UDim2.fromOffset(12, 22)
	name.TextColor3 = onBand
	name.Text = deed.name
	if closable then
		local close = Instance.new("TextButton")
		close.Name = "Close"
		close.Size = UDim2.fromOffset(26, 26)
		close.AnchorPoint = Vector2.new(1, 0)
		close.Position = UDim2.new(1, -6, 0, 6)
		close.BackgroundColor3 = Theme.color.ink
		close.BackgroundTransparency = 0.5
		close.BorderSizePixel = 0
		close.FontFace = Theme.font.display
		close.TextSize = 16
		close.TextColor3 = Color3.new(1, 1, 1)
		close.Text = "X"
		close.Parent = band
		Ui.corner(close, 13)
		close.Activated:Connect(self.onClose)
	end

	local spacer = Ui.frame("Spacer", UDim2.new(1, 0, 0, 8), self.frame)
	spacer.LayoutOrder = 2
	row(self.frame, 3, "Price", `${deed.price}`, "normal")
	divider(self.frame, 4)
	for index, line in deed.lines do
		row(self.frame, 10 + index, line.label, line.value, if line.current then "current" else "normal")
	end
	divider(self.frame, 30)
	for index, entry in deed.footer do
		row(self.frame, 30 + index, entry.label, entry.value, "dim")
	end

	if deed.mortgaged then
		local stamp = Ui.label("Mortgaged", self.frame, UDim2.new(1, -20, 0, 26), 15, Theme.font.display)
		stamp.LayoutOrder = 40
		stamp.TextColor3 = Theme.color.danger
		stamp.Text = "MORTGAGED"
	end
	if note then
		local holder = Ui.frame("NoteHolder", UDim2.new(1, -20, 0, 40), self.frame)
		holder.LayoutOrder = 50
		local pill = Ui.label("Note", holder, UDim2.new(1, 0, 0, 32), 15, Theme.font.bodyBold)
		pill.Position = UDim2.fromOffset(0, 8)
		pill.BackgroundTransparency = 0
		pill.BackgroundColor3 = Theme.color.panel
		pill.TextWrapped = false
		pill.TextTruncate = Enum.TextTruncate.AtEnd
		pill.Text = note
		Ui.corner(pill, 8)
	end

	Ui.show(self.frame)
end

return DeedCard
