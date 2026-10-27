--!strict
-- EIU Campus: the table stands on the Library Quad lawn at Eastern Illinois University on an
-- autumn evening. (Old Main, the campus pond, the panther statue and the rest come next.)

local Kit = require(script.Parent.Kit)
local Table = require(script.Parent.Table)

local G = Kit.GROUND
local LAWN = Color3.fromRGB(86, 120, 58)

local function lawn(model: Instance)
	Kit.block("Lawn", Vector3.new(600, 2, 600), CFrame.new(0, G - 1, 0), LAWN, Enum.Material.Grass, model)
end

return function(ctx: Kit.Context)
	local model = ctx.model
	Table.build({ top = Color3.fromRGB(96, 64, 44), edge = Color3.fromRGB(78, 52, 36), legs = Color3.fromRGB(70, 46, 32), inlay = Color3.fromRGB(150, 156, 166), keyLight = 1.4 }, model)
	lawn(model)
end
