--!strict
-- The offer on the table, above the action bar: everyone sees what each side would hand over.

local HudModel = require(script.Parent.Parent.HudModel)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local OfferCard = {}
OfferCard.__index = OfferCard

OfferCard.WIDTH = 700

export type OfferCard = typeof(setmetatable({} :: { frame: Frame, key: string? }, OfferCard))

function OfferCard.new(parent: Instance, bottomOffset: number): OfferCard
	local frame = Ui.panel("Offer", UDim2.fromOffset(OfferCard.WIDTH, 0), UDim2.new(0.5, 0, 1, -bottomOffset), Vector2.new(0.5, 1), parent)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Visible = false
	Ui.list(frame, Enum.FillDirection.Vertical, Theme.space.s, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	Ui.padding(frame, Theme.space.m)
	return setmetatable({ frame = frame, key = nil }, OfferCard)
end

local function column(parent: Instance, side: HudModel.OfferSide, order: number)
	local frame = Ui.surface(side.title, UDim2.new(0.5, -4, 0, 0), parent)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	Ui.list(frame, Enum.FillDirection.Vertical, Theme.space.xs, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
	Ui.padding(frame, Theme.space.s)
	local heading = Ui.label("Heading", frame, UDim2.new(1, 0, 0, 18), Theme.textSize.small, Theme.font.display)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = Theme.color.accent
	heading.Text = side.title
	heading.LayoutOrder = 0

	local items = 0
	for index, chip in side.chips do
		local view = Ui.chip(if chip.mortgaged then `{chip.name} (mortgaged)` else chip.name, frame, chip.color, "normal", nil)
		view.Name = chip.name
		view.Size = UDim2.new(1, 0, 0, 28)
		view.LayoutOrder = index
		items += 1
	end
	local extras = {}
	if side.cash > 0 then
		table.insert(extras, `${side.cash}`)
	end
	if side.jailCards > 0 then
		table.insert(extras, `{side.jailCards} jail card{if side.jailCards == 1 then "" else "s"}`)
	end
	if #extras > 0 or items == 0 then
		local line = Ui.label("Extras", frame, UDim2.new(1, 0, 0, 24), 18, Theme.font.display)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.LayoutOrder = 100
		if #extras > 0 then
			line.Text = table.concat(extras, "  +  ")
			line.TextColor3 = Theme.color.moneyUp
		else
			line.Text = "Nothing"
			line.TextColor3 = Theme.color.textDim
		end
	end
end

-- Everything a side shows, as text (chips carry colours, which can't be JSON-encoded).
local function sideKey(side: HudModel.OfferSide): string
	local parts = { side.title, tostring(side.cash), tostring(side.jailCards) }
	for _, chip in side.chips do
		table.insert(parts, `{chip.position}:{chip.mortgaged}`)
	end
	return "|" .. table.concat(parts, ",")
end

function OfferCard.render(self: OfferCard, offer: HudModel.Offer?)
	Ui.setVisible(self.frame, offer ~= nil)
	local key = if offer then offer.title .. sideKey(offer.left) .. sideKey(offer.right) else nil
	if key == self.key then
		return
	end
	self.key = key
	Ui.clear(self.frame)
	if not offer then
		return
	end
	local title = Ui.label("Title", self.frame, UDim2.new(1, 0, 0, 24), 19, Theme.font.display)
	title.Text = offer.title
	title.LayoutOrder = 1
	local columns = Ui.frame("Sides", UDim2.new(1, 0, 0, 0), self.frame)
	columns.AutomaticSize = Enum.AutomaticSize.Y
	columns.LayoutOrder = 2
	Ui.list(columns, Enum.FillDirection.Horizontal, Theme.space.s, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	column(columns, offer.left, 1)
	column(columns, offer.right, 2)
end

return OfferCard
