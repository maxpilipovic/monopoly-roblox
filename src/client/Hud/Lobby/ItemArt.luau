--!strict
-- How an item looks in the lobby: pieces and dice turn in a 3D preview, auras and rent effects
-- show their rendered icon (Icons), titles their name in their rarity's colour.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local DiceLook = require(ReplicatedStorage.Shared.Cosmetics.DiceLook)
local PieceLook = require(ReplicatedStorage.Shared.Cosmetics.PieceLook)
local Icons = require(script.Parent.Parent.Icons)
local ModelView = require(script.Parent.Parent.ModelView)
local Theme = require(script.Parent.Parent.Theme)
local Ui = require(script.Parent.Parent.Ui)

local ItemArt = {}

-- The icon each effect item is shown with (pieces and dice turn in 3D instead).
ItemArt.ICONS = table.freeze({
	CoinBurst = "CoinBurst",
	ConfettiPop = "ConfettiPop",
	MoneyRain = "MoneyRain",
	GoldenAura = "GoldenAura",
	Lightning = "Lightning",
	Fireworks = "Fireworks",
	BlackHole = "BlackHole",
	AuraStardust = "Stardust",
	AuraBubbles = "Bubbles",
	AuraEmbers = "Embers",
	AuraSnowfall = "Snowfall",
	AuraStorm = "Storm",
	AuraRainbow = "Rainbow",
	AuraGoldDust = "GoldDust",
	AuraBlueprint = "Blueprint",
	AuraClover = "Clover",
	AuraShadow = "Shadow",
	AuraCashFlow = "CashFlow",
	AuraStarburst = "Starburst",
})

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
		view:set("Dice", "Rounded", ItemArt.finishDice(itemId), "", itemId)
		return true
	end
	return false
end

-- A picture of the item filling `size` in `parent`: a turning model, its icon, or (titles) its name.
function ItemArt.build(parent: Instance, itemId: string, size: UDim2): GuiObject
	local item = Catalog.byId[itemId]
	if item and (item.kind == "Piece" or item.kind == "Dice") then
		local view = ModelView.new("Preview", parent, size)
		ItemArt.setModel(view, itemId)
		return view.frame
	end
	if item and item.kind == "Title" then
		local label = Ui.label("Title", parent, size, 26, Theme.font.display)
		label.TextScaled = true
		label.Text = item.name
		label.TextColor3 = Catalog.RARITY_COLORS[item.rarity]
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 26
		limit.Parent = label
		Ui.padding(label, { left = 6, right = 6 })
		return label
	end
	local holder = Instance.new("Frame")
	holder.Name = "Art"
	holder.Size = size
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	local icon = Icons.image(holder, ItemArt.ICONS[itemId] or "Star", UDim2.fromScale(0.86, 0.86))
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	return holder
end

return ItemArt
