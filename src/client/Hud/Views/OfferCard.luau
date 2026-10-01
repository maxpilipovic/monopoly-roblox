--!strict
-- An open trade offer, shown above the action bar to the player who must answer it.

local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local OfferCard = {}
OfferCard.__index = OfferCard

export type OfferCard = typeof(setmetatable({} :: { frame: Frame, give: TextLabel, get: TextLabel }, OfferCard))

local function column(parent: Frame, title: string, x: number): TextLabel
	local heading = Ui.label(`{title}Title`, parent, UDim2.new(0.5, -18, 0, 20), Theme.textSize.small, Theme.font.display)
	heading.Position = UDim2.new(x, 12, 0, 8)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = Theme.color.accent
	heading.Text = title
	local body = Ui.label(title, parent, UDim2.new(0.5, -18, 1, -34), 16)
	body.Position = UDim2.new(x, 12, 0, 28)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextTruncate = Enum.TextTruncate.AtEnd
	return body
end

function OfferCard.new(parent: Instance, bottomOffset: number): OfferCard
	local frame = Ui.panel("Offer", UDim2.fromOffset(700, 84), UDim2.new(0.5, 0, 1, -bottomOffset), Vector2.new(0.5, 1), parent)
	frame.Visible = false
	return setmetatable({
		frame = frame,
		give = column(frame, "You give", 0),
		get = column(frame, "You get", 0.5),
	}, OfferCard)
end

function OfferCard.render(self: OfferCard, summary: { give: string, get: string }?)
	Ui.setVisible(self.frame, summary ~= nil)
	if summary then
		self.give.Text = summary.give
		self.get.Text = summary.get
	end
end

return OfferCard
