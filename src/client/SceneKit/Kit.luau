--!strict
-- Building blocks for the scenes around the board: anchored, non-colliding parts in handy shapes,
-- lights and particles, terrain fills, and per-frame animation. Everything a scene makes is
-- client-only and is thrown away (terrain included) when the scene is cleared.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Scenes = require(ReplicatedStorage.Shared.Board.Scenes)

local Kit = {}

-- The floor under the board's table in every scene; the table's legs reach down to it.
Kit.GROUND = -14

export type Animator = (t: number, dt: number) -> ()

export type Context = {
	scene: Scenes.Scene,
	model: Model,
	random: Random,
	animate: (Animator) -> (),
	water: (props: { [string]: any }) -> (), -- the terrain water's look (colour, waves...)
}

function Kit.part(props: { [string]: any }, parent: Instance): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = props.CastShadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "ClassName" and key ~= "CastShadow" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

function Kit.block(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance): BasePart
	return Kit.part({ Name = name, Size = size, CFrame = cframe, Color = color, Material = material }, parent)
end

-- A neon block: lit windows, signs and glowing trim (no shadow, not shaded).
function Kit.glow(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): BasePart
	return Kit.part({ Name = name, Size = size, CFrame = cframe, Color = color, Material = Enum.Material.Neon, CastShadow = false }, parent)
end

function Kit.ball(name: string, centre: Vector3, diameter: number, color: Color3, material: Enum.Material, parent: Instance): BasePart
	return Kit.part({ Name = name, Shape = Enum.PartType.Ball, Size = Vector3.one * diameter, CFrame = CFrame.new(centre), Color = color, Material = material, CastShadow = material ~= Enum.Material.Neon }, parent)
end

-- An upright cylinder standing on `base`.
function Kit.cylinder(name: string, radius: number, height: number, base: Vector3, color: Color3, material: Enum.Material, parent: Instance): BasePart
	return Kit.part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = material,
	}, parent)
end

-- A round rod from `a` to `b`.
function Kit.rod(name: string, a: Vector3, b: Vector3, radius: number, color: Color3, material: Enum.Material, parent: Instance): BasePart
	local length = (b - a).Magnitude
	return Kit.part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, radius * 2, radius * 2),
		CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0),
		Color = color,
		Material = material,
		CastShadow = material ~= Enum.Material.Neon,
	}, parent)
end

-- A square beam from `a` to `b`.
function Kit.beam(name: string, a: Vector3, b: Vector3, width: number, color: Color3, material: Enum.Material, parent: Instance): BasePart
	local length = (b - a).Magnitude
	return Kit.part({ Name = name, Size = Vector3.new(width, width, length), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color, Material = material }, parent)
end

-- A four-sided pyramid of wedges (a pine tier, a roof) with its base centred on `base`.
function Kit.pyramid(name: string, base: Vector3, width: number, height: number, color: Color3, material: Enum.Material, parent: Instance, yaw: number?)
	for side = 0, 3 do
		Kit.part({
			ClassName = "WedgePart",
			Name = name,
			Size = Vector3.new(width, height, width / 2),
			CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, (yaw or 0) + side * math.pi / 2, 0) * CFrame.new(0, 0, -width / 4),
			Color = color,
			Material = material,
		}, parent)
	end
end

-- A many-sided cone (umbrella, carousel canopy, tent) whose panels can alternate colours.
function Kit.cone(name: string, base: Vector3, radius: number, height: number, sides: number, colors: { Color3 }, material: Enum.Material, parent: Instance)
	local panel = 2 * radius * math.tan(math.pi / sides)
	for side = 0, sides - 1 do
		local yaw = side / sides * 2 * math.pi
		local apothem = radius * math.cos(math.pi / sides)
		Kit.part({
			ClassName = "WedgePart",
			Name = name,
			Size = Vector3.new(panel + 0.05, height, apothem),
			CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -apothem / 2),
			Color = colors[side % #colors + 1],
			Material = material,
		}, parent)
	end
end

function Kit.pointLight(parent: BasePart, color: Color3, range: number, brightness: number, shadows: boolean?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows == true
	l.Parent = parent
	return l
end

function Kit.spotLight(parent: BasePart, face: Enum.NormalId, color: Color3, range: number, brightness: number, angle: number): SpotLight
	local l = Instance.new("SpotLight")
	l.Face = face
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Angle = angle
	l.Shadows = true
	l.Parent = parent
	return l
end

function Kit.emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

Kit.SMOKE = "rbxasset://textures/particles/smoke_main.dds"
Kit.SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
Kit.FIRE = "rbxasset://textures/particles/fire_main.dds"

-- A small flame (torch, campfire, candle): fire particles, a few sparks and a flickering light.
function Kit.flame(ctx: Context, at: Vector3, size: number, parent: Instance): BasePart
	local anchor = Kit.part({ Name = "Flame", Size = Vector3.one * 0.2, CFrame = CFrame.new(at), Transparency = 1, CastShadow = false }, parent)
	Kit.emitter(anchor, {
		Texture = Kit.FIRE,
		Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 80, 30)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(size * 1.5, size * 2.5),
		Rate = 30,
		SpreadAngle = Vector2.new(10, 10),
		EmissionDirection = Enum.NormalId.Top,
	})
	Kit.emitter(anchor, {
		Texture = Kit.SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 120)),
		LightEmission = 1,
		Size = NumberSequence.new(size * 0.12),
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(size * 3, size * 5),
		Rate = 4,
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
	})
	local light = Kit.pointLight(anchor, Color3.fromRGB(255, 150, 70), size * 9, 2, true)
	local seed = ctx.random:NextNumber(0, 100)
	ctx.animate(function(t)
		light.Brightness = 1.6 + 0.5 * math.noise(seed, t * 3) + 0.3 * math.sin(t * 17 + seed)
	end)
	return anchor
end

-- Text on a face of a part, glowing (signs, billboards).
function Kit.sign(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- Scaled text tops out at 100px, so set the density for the text to fill the face's height.
	local height = if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then part.Size.Z else part.Size.Y
	gui.PixelsPerStud = math.clamp(90 / math.max(height, 0.1), 2, 50)
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = font or Enum.Font.FredokaOne
	label.Parent = gui
end

-- Bulbs hanging in a sagging line from `a` to `b` (festoon lights); every `lit`th bulb gets a light.
function Kit.festoon(a: Vector3, b: Vector3, sag: number, count: number, colors: { Color3 }, parent: Instance, lit: number?): { BasePart }
	local bulbs = {}
	local previous = a
	for index = 1, count do
		local f = index / (count + 1)
		local point = a:Lerp(b, f) - Vector3.new(0, sag * 4 * f * (1 - f), 0)
		Kit.rod("Wire", previous, point, 0.05, Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic, parent)
		previous = point
		local bulb = Kit.ball("Bulb", point - Vector3.new(0, 0.35, 0), 0.6, colors[index % #colors + 1], Enum.Material.Neon, parent)
		if lit and index % lit == 0 then
			Kit.pointLight(bulb, colors[index % #colors + 1], 10, 0.6)
		end
		table.insert(bulbs, bulb)
	end
	Kit.rod("Wire", previous, b, 0.05, Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic, parent)
	return bulbs
end

-- Moving pieces ---------------------------------------------------------------------------------

-- The parts under `container`, remembered relative to `pivot`, so the whole group can be moved
-- in one go each frame (a turning wheel, a bobbing boat).
export type Rig = { parts: { BasePart }, offsets: { CFrame }, cframes: { CFrame } }

function Kit.rig(container: Instance, pivot: CFrame): Rig
	local parts, offsets = {}, {}
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(offsets, pivot:ToObjectSpace(d.CFrame))
		end
	end
	return { parts = parts, offsets = offsets, cframes = table.clone(offsets) }
end

-- Moves the rig's parts so its pivot is at `pivot`.
function Kit.place(rig: Rig, pivot: CFrame)
	for index, offset in rig.offsets do
		rig.cframes[index] = pivot * offset
	end
	workspace:BulkMoveTo(rig.parts, rig.cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- A group to build a moving piece into.
function Kit.group(name: string, parent: Instance): Model
	local group = Instance.new("Model")
	group.Name = name
	group.Parent = parent
	return group
end

-- Terrain (the scene's ground and water) --------------------------------------------------------

local terrain = workspace.Terrain

function Kit.fillBlock(cframe: CFrame, size: Vector3, material: Enum.Material)
	terrain:FillBlock(cframe, size, material)
end

function Kit.fillBall(centre: Vector3, radius: number, material: Enum.Material)
	terrain:FillBall(centre, radius, material)
end

function Kit.fillCylinder(centre: Vector3, height: number, radius: number, material: Enum.Material)
	terrain:FillCylinder(CFrame.new(centre), height, radius, material)
end

-- A mound: a ball of `material` sunk into the ground so only its cap shows.
function Kit.mound(centre: Vector3, radius: number, rise: number, material: Enum.Material)
	terrain:FillBall(Vector3.new(centre.X, centre.Y + rise - radius, centre.Z), radius, material)
end

-- A mountain from overlapping balls shrinking toward the peak: rock below, `cap` near the top.
function Kit.mountain(base: Vector3, radius: number, height: number, cap: Enum.Material?, random: Random)
	local steps = math.max(5, math.floor(height / 14))
	for step = 0, steps do
		local f = step / steps
		local r = radius * 0.62 * (1 - f) ^ 1.1 + 8
		local wobble = Vector3.new(random:NextNumber(-1, 1), 0, random:NextNumber(-1, 1)) * radius * 0.05
		local material = if cap and f > 0.55 then cap else Enum.Material.Rock
		terrain:FillBall(base + wobble + Vector3.new(0, f * height - r * 0.35, 0), r, material)
	end
end

return Kit
