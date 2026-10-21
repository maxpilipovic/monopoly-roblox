--!strict
-- Winter Lodge: the table stands on a lodge's snowy terrace at twilight. A two-storey log lodge
-- glows behind it with string lights and icicles under a deep snowy roof; snow-laden pines, a
-- frozen lake, a crackling campfire ring, a snowman with a sled, lantern posts along the path,
-- mountains on the horizon, the northern lights rippling overhead, and snow falling.

local Kit = require(script.Parent.Kit)
local Sounds = require(script.Parent.Parent.Sounds)
local Table = require(script.Parent.Table)

local G = Kit.GROUND
local LOG = Color3.fromRGB(122, 80, 50)
local LOG_DARK = Color3.fromRGB(96, 62, 40)
local SNOW = Color3.fromRGB(244, 248, 255)
local PINE = Color3.fromRGB(46, 98, 66)
local WARM = Color3.fromRGB(255, 196, 120)
local IRON = Color3.fromRGB(34, 34, 40)
local XMAS = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(80, 220, 120), Color3.fromRGB(255, 210, 90), Color3.fromRGB(90, 170, 255) }

local LAKE = Vector3.new(150, G, -60)
local LODGE = Vector3.new(0, G, -125)

local function ground(random: Random)
	Kit.fillBlock(CFrame.new(0, G - 10, 0), Vector3.new(1800, 20, 1800), Enum.Material.Snow)
	-- Rolling drifts, then mountains round the horizon.
	for _ = 1, 26 do
		local a = random:NextNumber(0, 2 * math.pi)
		local r = random:NextNumber(150, 420)
		Kit.mound(Vector3.new(math.cos(a) * r, G, math.sin(a) * r), random:NextNumber(40, 90), random:NextNumber(6, 22), Enum.Material.Snow)
	end
	for index = 0, 13 do
		local a = math.rad(160) + index / 13 * math.rad(220)
		local r = random:NextNumber(620, 760)
		Kit.mountain(Vector3.new(math.cos(a) * r, G - 4, math.sin(a) * r), random:NextNumber(150, 230), random:NextNumber(150, 300), Enum.Material.Snow, random)
	end
	-- The frozen lake, flush with the snow.
	Kit.fillCylinder(LAKE + Vector3.new(0, -2, 0), 4, 56, Enum.Material.Glacier)
	workspace.Terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(236, 242, 252))
	workspace.Terrain:SetMaterialColor(Enum.Material.Glacier, Color3.fromRGB(150, 200, 235))
	workspace.Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(96, 100, 112))
end

-- A snow-laden pine: tiers of green cones, each dusted with a smaller cone of snow.
local function pine(model: Instance, base: Vector3, scale: number, random: Random)
	Kit.cylinder("Trunk", 0.8 * scale, 4 * scale, base, Color3.fromRGB(80, 56, 38), Enum.Material.Wood, model)
	for tier = 0, 3 do
		local radius = (7 - tier * 1.5) * scale
		local y = (3 + tier * 3.8) * scale
		local tall = 6.5 * scale
		Kit.cone("Needles", base + Vector3.new(0, y, 0), radius, tall, 7, { PINE }, Enum.Material.Grass, model)
		-- Snow lies over the upper part of each tier: the same slope, just proud of the needles.
		Kit.cone("SnowCap", base + Vector3.new(0, y + tall * 0.45 + 0.3, 0), radius * 0.55, tall * 0.55, 7, { SNOW }, Enum.Material.Snow, model)
	end
end

local function forest(ctx: Kit.Context)
	local model, random = ctx.model, ctx.random
	local placed = 0
	local tries = 0
	while placed < 54 and tries < 400 do
		tries += 1
		local a = random:NextNumber(0, 2 * math.pi)
		local r = random:NextNumber(75, 330)
		local base = Vector3.new(math.cos(a) * r, G - 0.5, math.sin(a) * r)
		local clear = (base - LAKE).Magnitude > 70
			and (math.abs(base.X - LODGE.X) > 52 or base.Z < LODGE.Z - 40 or base.Z > LODGE.Z + 38)
			and not (math.abs(base.X) < 24 and base.Z < 0 and base.Z > LODGE.Z) -- the path
			and not (base.Z > 40 and math.abs(base.X) < 90) -- keep the camera's side open
		if clear then
			pine(model, base, random:NextNumber(1.3, 2.6), random)
			placed += 1
		end
	end
end

-- The lodge: two storeys of logs with lit windows, a porch, a deep snowy gable roof, a stone
-- chimney, string lights and icicles along the eaves.
local function lodge(ctx: Kit.Context)
	local model = ctx.model
	local width, depth, wall = 72, 40, 26
	local function p(x: number, y: number, z: number): CFrame
		return CFrame.new(LODGE + Vector3.new(x, y, z))
	end
	-- Log walls (front, back and sides), with crossed log ends at the corners.
	for course = 0, math.floor(wall / 2.2) - 1 do
		local y = 1.1 + course * 2.2
		local colour = if course % 2 == 0 then LOG else LOG_DARK
		for _, z in { -depth / 2, depth / 2 } do
			Kit.part({ Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(width + 4, 2.3, 2.3), CFrame = p(0, y, z), Color = colour, Material = Enum.Material.Wood }, model)
		end
		for _, x in { -width / 2, width / 2 } do
			Kit.part({ Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(depth + 4, 2.3, 2.3), CFrame = p(x, y + 1.1, 0) * CFrame.Angles(0, math.pi / 2, 0), Color = colour, Material = Enum.Material.Wood }, model)
		end
	end
	Kit.block("Inside", Vector3.new(width - 1, wall, depth - 1), p(0, wall / 2, 0), Color3.fromRGB(60, 40, 28), Enum.Material.Wood, model)
	-- Windows: warm glass in dark frames with a cross of mullions, two rows.
	local front = depth / 2 + 1.3
	for _, row in { 7, 18 } do
		for _, x in { -27, -15, 15, 27 } do
			local pane = Kit.glow("Window", Vector3.new(7, 6, 0.3), p(x, row, front), WARM, model)
			Kit.pointLight(pane, Color3.fromRGB(255, 180, 110), 24, 1.2, true)
			Kit.block("Frame", Vector3.new(8, 0.6, 0.6), p(x, row + 3.2, front + 0.1), LOG_DARK, Enum.Material.Wood, model)
			Kit.block("Frame", Vector3.new(8, 0.6, 0.6), p(x, row - 3.2, front + 0.1), LOG_DARK, Enum.Material.Wood, model)
			Kit.block("Frame", Vector3.new(0.6, 7, 0.6), p(x - 3.7, row, front + 0.1), LOG_DARK, Enum.Material.Wood, model)
			Kit.block("Frame", Vector3.new(0.6, 7, 0.6), p(x + 3.7, row, front + 0.1), LOG_DARK, Enum.Material.Wood, model)
			Kit.block("Mullion", Vector3.new(0.3, 6, 0.4), p(x, row, front + 0.15), LOG_DARK, Enum.Material.Wood, model)
			Kit.block("Mullion", Vector3.new(7, 0.3, 0.4), p(x, row, front + 0.15), LOG_DARK, Enum.Material.Wood, model)
			Kit.block("SnowSill", Vector3.new(8.4, 0.6, 1.4), p(x, row - 3.7, front + 0.6), SNOW, Enum.Material.Snow, model)
		end
	end
	-- The front door with a wreath, under a porch roof on log posts.
	Kit.block("Door", Vector3.new(7, 11, 0.6), p(0, 5.5, front), Color3.fromRGB(110, 40, 36), Enum.Material.Wood, model)
	Kit.glow("DoorGlass", Vector3.new(3, 3, 0.3), p(0, 8.4, front + 0.3), WARM, model)
	Kit.part({ Name = "Wreath", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 3.4, 3.4), CFrame = p(0, 6, front + 0.5) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(30, 100, 50), Material = Enum.Material.Grass }, model)
	Kit.ball("Bow", (p(0, 4.5, front + 0.9)).Position, 0.9, Color3.fromRGB(220, 30, 40), Enum.Material.SmoothPlastic, model)
	Kit.block("Porch", Vector3.new(30, 1, 12), p(0, 0.5, depth / 2 + 6), LOG_DARK, Enum.Material.WoodPlanks, model)
	for _, x in { -14, 14 } do
		Kit.cylinder("PorchPost", 0.9, 13, (p(x, 0, depth / 2 + 11)).Position, LOG, Enum.Material.Wood, model)
	end
	Kit.part({ ClassName = "WedgePart", Name = "PorchRoof", Size = Vector3.new(34, 3, 14), CFrame = p(0, 14.5, depth / 2 + 6) * CFrame.Angles(0, math.pi, 0), Color = SNOW, Material = Enum.Material.Snow }, model)
	local porchLamp = Kit.glow("PorchLamp", Vector3.new(1.4, 2, 1.4), p(0, 12.4, depth / 2 + 8), WARM, model)
	Kit.pointLight(porchLamp, Color3.fromRGB(255, 190, 120), 22, 0.8, true)
	-- The roof: two snowy slopes over a dark underside, deep eaves.
	local ridge = wall + 16
	for side = -1, 1, 2 do
		Kit.part({ ClassName = "WedgePart", Name = "Roof", Size = Vector3.new(width + 10, 16, depth / 2 + 6), CFrame = p(0, wall + 8, side * (depth / 4 + 3)) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0), Color = SNOW, Material = Enum.Material.Snow }, model)
		Kit.part({ ClassName = "WedgePart", Name = "RoofUnder", Size = Vector3.new(width + 9.6, 15.6, depth / 2 + 5.6), CFrame = p(0, wall + 7.6, side * (depth / 4 + 3)) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0), Color = LOG_DARK, Material = Enum.Material.Wood }, model)
	end
	-- Gables fill under the roof at each end.
	for _, x in { -width / 2, width / 2 } do
		for side = -1, 1, 2 do
			Kit.part({ ClassName = "WedgePart", Name = "Gable", Size = Vector3.new(1.5, 16, depth / 2), CFrame = p(x, wall + 8, side * depth / 4) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0), Color = LOG, Material = Enum.Material.Wood }, model)
		end
	end
	-- The chimney, smoking.
	local chimney = Kit.block("Chimney", Vector3.new(7, ridge + 6, 7), p(width / 2 - 12, (ridge + 6) / 2, -6), Color3.fromRGB(120, 112, 108), Enum.Material.Cobblestone, model)
	Kit.block("ChimneyCap", Vector3.new(8, 1, 8), p(width / 2 - 12, ridge + 6.5, -6), SNOW, Enum.Material.Snow, model)
	Kit.emitter(chimney, {
		Texture = Kit.SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(200, 200, 210)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 14) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(4, 6),
		Rate = 5,
		Acceleration = Vector3.new(2, 0.5, 0),
		EmissionDirection = Enum.NormalId.Top,
	})
	-- String lights and icicles along the front eave.
	local eave = depth / 2 + 8.5
	Kit.festoon((p(-width / 2 - 4, wall + 0.6, eave)).Position, (p(width / 2 + 4, wall + 0.6, eave)).Position, 2.4, 36, XMAS, model, 5)
	for index = 0, 30 do
		local x = -width / 2 - 3 + index * (width + 6) / 30
		local length = 1.2 + ((index * 7) % 5) * 0.5
		Kit.part({ ClassName = "WedgePart", Name = "Icicle", Size = Vector3.new(0.35, length, 0.35), CFrame = p(x, wall - 0.3 - length / 2, eave + 0.4) * CFrame.Angles(math.pi, 0, 0), Color = Color3.fromRGB(200, 230, 255), Material = Enum.Material.Glass, Transparency = 0.3 }, model)
	end
	-- Firewood stacked by the porch, skis leaning on the wall.
	for row = 0, 2 do
		for log = 0, 5 - row do
			Kit.part({ Name = "Firewood", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.4, 1.4), CFrame = p(-24 + log * 1.45 + row * 0.7, 0.7 + row * 1.25, depth / 2 + 4) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(150, 104, 66), Material = Enum.Material.Wood }, model)
		end
	end
	for index, colour in { Color3.fromRGB(220, 40, 50), Color3.fromRGB(40, 110, 220) } do
		Kit.block("Ski", Vector3.new(0.6, 14, 0.2), p(20 + index * 1.4, 7, depth / 2 + 1.8) * CFrame.Angles(math.rad(-10), 0, 0), colour, Enum.Material.SmoothPlastic, model)
	end
end

local function terrace(ctx: Kit.Context)
	local model = ctx.model
	Kit.block("Terrace", Vector3.new(118, 1.4, 118), CFrame.new(0, G - 0.7, 0), Color3.fromRGB(110, 76, 52), Enum.Material.WoodPlanks, model)
	-- A railing with snow along its top, and lantern posts at the corners.
	for side = 0, 3 do
		local yaw = side * math.pi / 2
		local edge = CFrame.Angles(0, yaw, 0)
		for index = 0, 14 do
			local along = -56 + index * 8
			if not (side == 2 and math.abs(along) < 12) then -- the gap toward the lodge
				Kit.block("Baluster", Vector3.new(0.9, 4, 0.9), edge * CFrame.new(along, G + 2, 58), LOG, Enum.Material.Wood, model)
			end
		end
		local segments = if side == 2 then { { -58, -12 }, { 12, 58 } } else { { -58, 58 } }
		for _, seg in segments do
			local a = (edge * CFrame.new(seg[1], G + 4.3, 58)).Position
			local b = (edge * CFrame.new(seg[2], G + 4.3, 58)).Position
			Kit.beam("Rail", a, b, 0.9, LOG_DARK, Enum.Material.Wood, model)
			Kit.beam("RailSnow", a + Vector3.new(0, 0.7, 0), b + Vector3.new(0, 0.7, 0), 0.7, SNOW, Enum.Material.Snow, model)
		end
		local corner = (edge * CFrame.new(58, G, 58)).Position
		Kit.block("LanternPost", Vector3.new(1.4, 7, 1.4), CFrame.new(corner + Vector3.new(0, 3.5, 0)), LOG_DARK, Enum.Material.Wood, model)
		local lantern = Kit.block("Lantern", Vector3.new(1.8, 2.4, 1.8), CFrame.new(corner + Vector3.new(0, 8.2, 0)), Color3.fromRGB(255, 220, 160), Enum.Material.Glass, model)
		lantern.Transparency = 0.3
		Kit.flame(ctx, corner + Vector3.new(0, 7.8, 0), 0.5, model)
		Kit.pyramid("LanternTop", corner + Vector3.new(0, 9.4, 0), 2.4, 1.4, IRON, Enum.Material.Metal, model)
		Kit.ball("SnowCap", corner + Vector3.new(0, 10.6, 0), 1.6, SNOW, Enum.Material.Snow, model)
	end
	-- A paved path from the terrace to the lodge's porch, lit by lamp posts.
	Kit.block("Path", Vector3.new(16, 0.4, 44), CFrame.new(0, G - 0.1, -80), Color3.fromRGB(120, 116, 124), Enum.Material.Slate, model)
	for _, z in { -70, -92 } do
		for _, x in { -10, 10 } do
			local base = Vector3.new(x, G, z)
			Kit.cylinder("LampPost", 0.35, 10, base, IRON, Enum.Material.Metal, model)
			local glass = Kit.ball("LampGlobe", base + Vector3.new(0, 10.8, 0), 1.6, WARM, Enum.Material.Neon, model)
			Kit.pointLight(glass, Color3.fromRGB(255, 190, 120), 22, 1.2)
			Kit.ball("LampSnow", base + Vector3.new(0, 11.8, 0), 1.2, SNOW, Enum.Material.Snow, model)
		end
	end
end

local function campfire(ctx: Kit.Context, at: Vector3)
	local model = ctx.model
	for index = 0, 9 do
		local a = index / 10 * 2 * math.pi
		Kit.ball("FireStone", at + Vector3.new(math.cos(a) * 4, 0.5, math.sin(a) * 4), 1.8, Color3.fromRGB(110, 106, 104), Enum.Material.Slate, model)
	end
	for index = 0, 3 do
		local a = index / 4 * 2 * math.pi
		Kit.rod("FireLog", at + Vector3.new(math.cos(a) * 2.6, 0.4, math.sin(a) * 2.6), at + Vector3.new(0, 2.2, 0), 0.45, Color3.fromRGB(90, 60, 40), Enum.Material.Wood, model)
	end
	Kit.glow("Embers", Vector3.new(3, 0.4, 3), CFrame.new(at + Vector3.new(0, 0.3, 0)), Color3.fromRGB(255, 110, 40), model)
	local fire = Kit.flame(ctx, at + Vector3.new(0, 1, 0), 3.2, model)
	Sounds.attach(fire, Sounds.FIRE, 0.35, 170) -- it crackles, louder as the camera passes it
	-- Log benches round it.
	for index = 0, 2 do
		local a = index / 3 * 2 * math.pi + 0.4
		local seat = at + Vector3.new(math.cos(a) * 11, 1.2, math.sin(a) * 11)
		Kit.part({ Name = "Bench", Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 2.4, 2.4), CFrame = CFrame.new(seat) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = LOG, Material = Enum.Material.Wood }, model)
		Kit.part({ Name = "BenchSnow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8.4, 0.6, 1.6), CFrame = CFrame.new(seat + Vector3.new(0, 1.15, 0)) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = SNOW, Material = Enum.Material.Snow }, model)
	end
end

local function snowman(model: Instance, at: Vector3)
	Kit.ball("Snowball", at + Vector3.new(0, 3.2, 0), 7, SNOW, Enum.Material.Snow, model)
	Kit.ball("Snowball", at + Vector3.new(0, 8.2, 0), 5.2, SNOW, Enum.Material.Snow, model)
	Kit.ball("Snowball", at + Vector3.new(0, 12, 0), 3.8, SNOW, Enum.Material.Snow, model)
	for _, x in { -0.7, 0.7 } do
		Kit.ball("Eye", at + Vector3.new(x, 12.5, 1.7), 0.5, Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, model)
	end
	for index = 0, 2 do
		Kit.ball("Button", at + Vector3.new(0, 7 + index * 1.3, 2.5 - math.abs(index - 1) * 0.15), 0.6, Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, model)
	end
	Kit.rod("Nose", at + Vector3.new(0, 12, 1.7), at + Vector3.new(0, 11.8, 4), 0.25, Color3.fromRGB(255, 130, 40), Enum.Material.SmoothPlastic, model)
	Kit.cylinder("HatBrim", 2.4, 0.3, at + Vector3.new(0, 13.6, 0), Color3.fromRGB(20, 20, 24), Enum.Material.Fabric, model)
	Kit.cylinder("Hat", 1.5, 3, at + Vector3.new(0, 13.9, 0), Color3.fromRGB(20, 20, 24), Enum.Material.Fabric, model)
	Kit.cylinder("HatBand", 1.55, 0.6, at + Vector3.new(0, 14.1, 0), Color3.fromRGB(200, 30, 40), Enum.Material.Fabric, model)
	Kit.cylinder("Scarf", 2.2, 1, at + Vector3.new(0, 9.9, 0), Color3.fromRGB(200, 30, 40), Enum.Material.Fabric, model)
	Kit.block("ScarfTail", Vector3.new(1, 3.4, 0.3), CFrame.new(at + Vector3.new(1.2, 8.4, 2)) * CFrame.Angles(0, 0, 0.2), Color3.fromRGB(200, 30, 40), Enum.Material.Fabric, model)
	for side = -1, 1, 2 do
		Kit.rod("Arm", at + Vector3.new(side * 2.2, 8.6, 0), at + Vector3.new(side * 6, 11, 0.5), 0.2, Color3.fromRGB(90, 60, 40), Enum.Material.Wood, model)
	end
	-- A red sled beside him.
	local sled = CFrame.new(at + Vector3.new(8, 0, 3)) * CFrame.Angles(0, 0.5, 0)
	Kit.block("SledSeat", Vector3.new(3, 0.4, 7), sled * CFrame.new(0, 1.4, 0), Color3.fromRGB(190, 40, 40), Enum.Material.Wood, model)
	for _, x in { -1.3, 1.3 } do
		Kit.block("Runner", Vector3.new(0.3, 0.3, 8), sled * CFrame.new(x, 0.3, 0), Color3.fromRGB(200, 200, 210), Enum.Material.Metal, model)
		Kit.block("Strut", Vector3.new(0.3, 1, 0.3), sled * CFrame.new(x, 0.8, 2), Color3.fromRGB(200, 200, 210), Enum.Material.Metal, model)
		Kit.block("Strut", Vector3.new(0.3, 1, 0.3), sled * CFrame.new(x, 0.8, -2), Color3.fromRGB(200, 200, 210), Enum.Material.Metal, model)
	end
end

-- The northern lights: tall translucent curtains rippling across the sky.
local function aurora(ctx: Kit.Context)
	-- Overlapping glowing beams hung along a wavy line, each fading out at top and bottom, so they
	-- blend into soft curtains; the line ripples and the light breathes.
	local anchor = Kit.part({ Name = "Aurora", Size = Vector3.one, CFrame = CFrame.new(), Transparency = 1, CastShadow = false }, ctx.model)
	local curtains = {}
	local count = 90
	for layer = 0, 1 do
		for index = 0, count - 1 do
			local f = index / (count - 1)
			local bottom = Instance.new("Attachment")
			local top = Instance.new("Attachment")
			bottom.Parent = anchor
			top.Parent = anchor
			local beam = Instance.new("Beam")
			beam.Attachment0 = bottom
			beam.Attachment1 = top
			beam.FaceCamera = true
			beam.Width0 = 34
			beam.Width1 = 46
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Brightness = 1.4
			beam.Segments = 10 -- transparency is only sampled per segment
			beam.Color = if layer == 0
				then ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 255, 160)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 230, 200)), ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 90, 255)) })
				else ColorSequence.new(Color3.fromRGB(120, 255, 190), Color3.fromRGB(200, 100, 255))
			-- Faded at both ends (never fully 1: a beam with fully clear ends doesn't draw at all).
			beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.96), NumberSequenceKeypoint.new(0.2, 0.7), NumberSequenceKeypoint.new(0.6, 0.78), NumberSequenceKeypoint.new(1, 0.97) })
			beam.Parent = anchor
			table.insert(curtains, { bottom = bottom, top = top, beam = beam, x = -1000 + f * 2000, layer = layer, height = if layer == 0 then 180 else 120 })
		end
	end
	local lastShimmer = -1
	ctx.animate(function(t)
		for _, c in curtains do
			local z = -650 - c.layer * 80 + math.sin(c.x * 0.004 + t * 0.25 + c.layer) * 110 + math.noise(c.x * 0.003, t * 0.08) * 60
			local y = 230 + c.layer * 70 + math.sin(c.x * 0.006 + t * 0.4) * 15
			c.bottom.Position = Vector3.new(c.x, y, z)
			c.top.Position = Vector3.new(c.x + math.sin(t * 0.3 + c.x * 0.01) * 20, y + c.height, z - 30)
		end
		if t - lastShimmer > 0.1 then
			lastShimmer = t
			for _, c in curtains do
				c.beam.Brightness = 0.8 + 1.2 * (0.5 + 0.5 * math.noise(c.x * 0.008, t * 0.3, c.layer))
			end
		end
	end)
end

local function snowfall(model: Instance)
	for _, layer in { { 220, 160, 0.35, 90 }, { 80, 60, 0.18, 40 } } do
		local cloud = Kit.part({ Name = "SnowCloud", Size = Vector3.new(layer[1], 1, layer[1]), CFrame = CFrame.new(0, layer[4], 0), Transparency = 1 }, model)
		Kit.emitter(cloud, {
			Texture = Kit.SPARKLE,
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			LightEmission = 0.4,
			Size = NumberSequence.new(layer[3]),
			Lifetime = NumberRange.new(10, 14),
			Speed = NumberRange.new(6, 9),
			Rate = layer[2],
			Acceleration = Vector3.new(1.5, 0, 0.5),
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(18, 18),
			RotSpeed = NumberRange.new(-60, 60),
		})
	end
end

local function tableProps(ctx: Kit.Context)
	local model = ctx.model
	-- Hot cocoa with marshmallows and steam; a candle in a little lantern.
	local mug = Table.cornerSpot(1)
	Kit.cylinder("Mug", 1.3, 3, mug, Color3.fromRGB(200, 50, 50), Enum.Material.SmoothPlastic, model)
	Kit.cylinder("Cocoa", 1.15, 0.1, mug + Vector3.new(0, 2.85, 0), Color3.fromRGB(90, 50, 30), Enum.Material.SmoothPlastic, model)
	Kit.part({ Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.8, 1.8), CFrame = CFrame.new(mug + Vector3.new(1.4, 1.5, 0)) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(200, 50, 50), Material = Enum.Material.SmoothPlastic }, model)
	for index = 0, 2 do
		Kit.block("Marshmallow", Vector3.new(0.6, 0.5, 0.6), CFrame.new(mug + Vector3.new(-0.4 + index * 0.4, 3, index % 2 * 0.4 - 0.2)) * CFrame.Angles(0, index, 0), Color3.fromRGB(255, 250, 245), Enum.Material.SmoothPlastic, model)
	end
	local steam = Kit.part({ Name = "Steam", Size = Vector3.one * 0.5, CFrame = CFrame.new(mug + Vector3.new(0, 3.3, 0)), Transparency = 1 }, model)
	Kit.emitter(steam, {
		Texture = Kit.SMOKE,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2.2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.6, 2.4),
		Speed = NumberRange.new(1.2, 2),
		Rate = 6,
		EmissionDirection = Enum.NormalId.Top,
	})
	local candle = Table.cornerSpot(3)
	Kit.block("LanternBase", Vector3.new(2.4, 0.4, 2.4), CFrame.new(candle + Vector3.new(0, 0.2, 0)), IRON, Enum.Material.Metal, model)
	Kit.block("LanternGlass", Vector3.new(2, 3, 2), CFrame.new(candle + Vector3.new(0, 1.9, 0)), Color3.fromRGB(255, 240, 210), Enum.Material.Glass, model).Transparency = 0.6
	Kit.pyramid("LanternTop", candle + Vector3.new(0, 3.4, 0), 2.6, 1.2, IRON, Enum.Material.Metal, model)
	Kit.cylinder("Candle", 0.4, 1.4, candle + Vector3.new(0, 0.4, 0), Color3.fromRGB(250, 245, 230), Enum.Material.SmoothPlastic, model)
	Kit.flame(ctx, candle + Vector3.new(0, 2, 0), 0.3, model)
	-- A pine cone and a sprig of holly.
	local cone = Table.cornerSpot(0)
	Kit.cone("PineCone", cone, 0.9, 2.2, 6, { Color3.fromRGB(120, 80, 50), Color3.fromRGB(96, 62, 40) }, Enum.Material.Wood, model)
	for index = 0, 2 do
		Kit.ball("Berry", Table.cornerSpot(2, index * 0.6 - 0.6) + Vector3.new(0, 0.35, index % 2 * 0.5), 0.6, Color3.fromRGB(210, 20, 30), Enum.Material.SmoothPlastic, model)
	end
end

return function(ctx: Kit.Context)
	local model = ctx.model
	Table.build({ top = Color3.fromRGB(110, 70, 46), edge = Color3.fromRGB(88, 56, 36), legs = Color3.fromRGB(80, 50, 32), inlay = Color3.fromRGB(214, 172, 84), keyLight = 1.6 }, model)
	tableProps(ctx)
	ground(ctx.random)
	terrace(ctx)
	lodge(ctx)
	forest(ctx)
	campfire(ctx, Vector3.new(-95, G, -40))
	snowman(model, Vector3.new(80, G - 0.5, 60))
	aurora(ctx)
	snowfall(model)
	local sky = Instance.new("Sky")
	sky.StarCount = 4000
	sky.MoonAngularSize = 12
	sky.Parent = model
end
