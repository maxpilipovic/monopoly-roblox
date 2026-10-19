--!strict
-- The table the board sits on, in every scene: a thick top with a rounded edge and a brass inlay,
-- an apron, and four turned legs standing on the scene's ground. Each scene picks its woods.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local Kit = require(script.Parent.Kit)

local Table = {}

Table.SIZE = Layout.BOARD_SIZE + 26
Table.TOP_Y = -0.15 -- just under the board's base
-- The margin between the board's edge and the table's: where a scene's little props go.
Table.MARGIN_CENTRE = (Layout.BOARD_SIZE / 2 + Table.SIZE / 2) / 2

-- keyLight: a warm spotlight over the board (night scenes), so it reads clearly in the dark.
export type Style = { top: Color3, edge: Color3, legs: Color3, inlay: Color3, material: Enum.Material?, keyLight: number? }

local BRASS = Color3.fromRGB(214, 172, 84)

function Table.build(style: Style, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Table"
	model.Parent = parent
	local half = Table.SIZE / 2
	local material = style.material or Enum.Material.Wood
	local topCentre = Table.TOP_Y - 1
	Kit.block("TableTop", Vector3.new(Table.SIZE, 2, Table.SIZE), CFrame.new(0, topCentre, 0), style.top, material, model)
	-- A rounded edge all round, and round corners.
	for side = 0, 3 do
		local yaw = side * math.pi / 2
		local edge = CFrame.Angles(0, yaw, 0) * CFrame.new(0, topCentre, half)
		Kit.part({ Name = "Edge", Shape = Enum.PartType.Cylinder, Size = Vector3.new(Table.SIZE, 2.2, 2.2), CFrame = edge, Color = style.edge, Material = material }, model)
		local corner = CFrame.Angles(0, yaw, 0) * Vector3.new(half, topCentre, half)
		Kit.ball("Corner", corner, 2.2, style.edge, material, model)
		Kit.ball("CornerCap", corner + Vector3.new(0, 0.9, 0), 0.9, BRASS, Enum.Material.Metal, model)
		-- A brass inlay line a little in from the edge.
		Kit.block("Inlay", Vector3.new(Table.SIZE - 6, 0.06, 0.35), CFrame.Angles(0, yaw, 0) * CFrame.new(0, Table.TOP_Y + 0.02, half - 2.6), style.inlay, Enum.Material.Metal, model)
	end
	-- The apron under the top, and the legs.
	local apronTop = topCentre - 1
	Kit.block("Apron", Vector3.new(Table.SIZE - 8, 3, Table.SIZE - 8), CFrame.new(0, apronTop - 1.5, 0), style.edge, material, model)
	Kit.block("ApronTrim", Vector3.new(Table.SIZE - 7.6, 0.3, Table.SIZE - 7.6), CFrame.new(0, apronTop - 2.9, 0), BRASS, Enum.Material.Metal, model)
	local legTop = apronTop - 3
	local floor = Kit.GROUND
	for corner = 0, 3 do
		local at = CFrame.Angles(0, corner * math.pi / 2, 0) * Vector3.new(half - 7, 0, half - 7)
		local x, z = at.X, at.Z
		Kit.block("LegBlock", Vector3.new(2.8, 2.4, 2.8), CFrame.new(x, legTop - 1.2, z), style.legs, material, model)
		local span = legTop - 2.4 - (floor + 1.2)
		Kit.cylinder("Leg", 0.9, span, Vector3.new(x, floor + 1.2, z), style.legs, material, model)
		Kit.ball("LegTurn", Vector3.new(x, floor + 1.2 + span * 0.62, z), 2.6, style.legs, material, model)
		Kit.ball("LegTurn", Vector3.new(x, floor + 1.2 + span * 0.3, z), 2.1, style.legs, material, model)
		Kit.cylinder("LegRing", 1.05, 0.35, Vector3.new(x, floor + 1.2 + span * 0.62 - 1.6, z), BRASS, Enum.Material.Metal, model)
		Kit.ball("Foot", Vector3.new(x, floor + 0.9, z), 2.4, BRASS, Enum.Material.Metal, model)
	end
	if style.keyLight then
		local lamp = Kit.part({ Name = "KeyLight", Size = Vector3.one, CFrame = CFrame.new(0, 52, 0), Transparency = 1, CastShadow = false }, model)
		local light = Kit.spotLight(lamp, Enum.NormalId.Bottom, Color3.fromRGB(255, 238, 214), 90, style.keyLight, 95)
		light.Shadows = true
	end
	return model
end

-- Where to stand a little prop on the table: one of the four corners of the margin (0-3), nudged
-- along the edge by `along` studs.
function Table.cornerSpot(corner: number, along: number?): Vector3
	local m = Table.MARGIN_CENTRE
	local spot = CFrame.Angles(0, corner * math.pi / 2, 0) * Vector3.new(m, 0, m)
	local nudge = CFrame.Angles(0, corner * math.pi / 2, 0) * Vector3.new(-(along or 0), 0, 0)
	return Vector3.new(spot.X + nudge.X, Table.TOP_Y, spot.Z + nudge.Z)
end

return Table
