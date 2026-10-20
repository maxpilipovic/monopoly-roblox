--!strict
-- How an item looks in the lobby: pieces and dice turn in a 3D preview, the rest (auras, rent
-- effects, titles, chest keys, coins) get a glyph or a name tag in their rarity's colour.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local DiceLook = require(ReplicatedStorage.Shared.Cosmetics.DiceLook)
local PieceLook = require(ReplicatedStorage.Shared.Cosmetics.PieceLook)
local ModelView = require(script.Parent.Parent.ModelView)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local ItemArt = {}

ItemArt.GLYPHS = table.freeze({
	CoinBurst = "💰",
	ConfettiPop = "🎉",
	MoneyRain = "💸",
	GoldenAura = "✨",
	Lightning = "⚡",
	Fireworks = "🎆",
	BlackHole = "🕳️",
	AuraStardust = "✨",
	AuraBubbles = "💧",
	AuraEmbers = "🔥",
	AuraSnowfall = "❄️",
	AuraStorm = "🌩️",
	AuraRainbow = "🌈",
	AuraGoldDust = "🌟",
	AuraBlueprint = "📐",
	AuraClover = "🍀",
	AuraShadow = "🌑",
	AuraCashFlow = "💵",
	AuraStarburst = "💫",
})

ItemArt.COIN = "💰"
ItemArt.KEY = "🗝️"

function ItemArt.finishPiece(id: string): (Model) -> ()
	return function(model: Model)
		PieceLook.apply(model, id)
	end
end

function ItemArt.finishDice(id: string): (Model) -> ()
	return function(model: Model)
		DiceLook.apply(model, id)
	end
end

-- Shows `itemId` in a view (for pieces and dice), or returns false when it has no model.
function ItemArt.setModel(view: ModelView.ModelView, itemId: string): boolean
	local item = Catalog.byId[itemId]
	if not item then
		return false
	end
	if item.kind == "Piece" then
		local kind, shape = Catalog.modelOf(itemId)
		view:set(kind, shape, ItemArt.finishPiece(itemId), "?", itemId)
		return true
	elseif item.kind == "Dice" then
		view:set("Dice", "Rounded", ItemArt.finishDice(itemId), "🎲", itemId)
		return true
	end
	return false
end

-- A picture of the item filling `size` in `parent`: a turning model, a glyph, or (titles) its name.
function ItemArt.build(parent: Instance, itemId: string, size: UDim2): GuiObject
	local item = Catalog.byId[itemId]
	if item and (item.kind == "Piece" or item.kind == "Dice") then
		local view = ModelView.new("Preview", parent, size)
		ItemArt.setModel(view, itemId)
		return view.frame
	end
	local label = Ui.label("Glyph", parent, size, 44, Theme.font.display)
	if item and item.kind == "Title" then
		label.TextScaled = true
		label.Text = `« {item.name} »`
		label.TextColor3 = Catalog.RARITY_COLORS[item.rarity]
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 26
		limit.Parent = label
		Ui.padding(label, { left = 6, right = 6 })
	else
		label.TextScaled = true
		label.Text = ItemArt.GLYPHS[itemId] or "★"
		Ui.padding(label, 10)
	end
	return label
end

return ItemArt
