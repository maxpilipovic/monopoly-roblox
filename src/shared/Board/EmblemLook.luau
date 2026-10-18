--!strict
-- The emblems that stand for the tiles without a colour group (Chance, Community Chest, railroads,
-- utilities): which shape each tile gets, and how each shape's parts are finished. Shared by the
-- board (server) and the cards (client) so both look the same.

local Tiles = require(script.Parent.Tiles)

export type PartFinish = { color: Color3, material: Enum.Material, transparency: number? }

local EmblemLook = {}

EmblemLook.SHAPES = { "Question", "Chest", "Locomotive", "Bulb", "Tap" }

local ELECTRIC_POSITION = 12 -- the other utility is the water works

local GOLD = { color = Color3.fromRGB(214, 172, 84), material = Enum.Material.Metal }
local INK = { color = Color3.fromRGB(24, 24, 28), material = Enum.Material.SmoothPlastic }

EmblemLook.FINISHES = table.freeze({
	Question = { Body = GOLD },
	Chest = { Body = INK, Trim = GOLD },
	Locomotive = { Body = INK, Trim = GOLD },
	Bulb = {
		Body = { color = Color3.fromRGB(255, 244, 214), material = Enum.Material.Glass, transparency = 0.15 },
		Trim = GOLD,
	},
	Tap = {
		Body = { color = Color3.fromRGB(196, 200, 208), material = Enum.Material.Metal },
		Trim = GOLD,
		Drop = { color = Color3.fromRGB(110, 170, 235), material = Enum.Material.Glass, transparency = 0.2 },
	},
}) :: { [string]: { [string]: PartFinish } }

function EmblemLook.forTile(tile: Tiles.Tile): string?
	if tile.kind == "Chance" then
		return "Question"
	elseif tile.kind == "CommunityChest" then
		return "Chest"
	elseif tile.kind == "Railroad" then
		return "Locomotive"
	elseif tile.kind == "Utility" then
		return if tile.position == ELECTRIC_POSITION then "Bulb" else "Tap"
	end
	return nil
end

-- Finishes a clone of an emblem model: each part by name, everything anchored and inert.
function EmblemLook.apply(model: Model, shape: string)
	local finish = EmblemLook.FINISHES[shape] or {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local look = finish[part.Name]
			if look then
				part.Color = look.color
				part.Material = look.material
				part.Transparency = look.transparency or 0
			end
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

return EmblemLook
