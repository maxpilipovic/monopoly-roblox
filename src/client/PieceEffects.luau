--!strict
-- The special effects that come with chest pieces: particles, trails and lights attached to the
-- piece's model, built from code by effect id (Catalog's `effect`).

local PieceEffects = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function primary(model: Model): BasePart?
	local body = model:FindFirstChild("Body", true)
	if body and body:IsA("BasePart") then
		return body
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function attachment(part: BasePart, offset: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Position = offset
	a.Parent = part
	return a
end

local function sequence(from: number, to: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, to) })
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0.3
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function light(part: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = part
end

local function trail(part: BasePart, size: Vector3, color: ColorSequence, lifetime: number)
	local top = attachment(part, Vector3.new(0, size.Y * 0.3, 0))
	local bottom = attachment(part, Vector3.new(0, -size.Y * 0.3, 0))
	local t = Instance.new("Trail")
	t.Attachment0 = top
	t.Attachment1 = bottom
	t.Color = color
	t.Lifetime = lifetime
	t.LightEmission = 1
	t.Transparency = sequence(0.2, 1)
	t.FaceCamera = true
	t.Parent = part
end

local BUILDERS: { [string]: (BasePart, Vector3) -> () } = {
	Bubbles = function(part, size)
		emitter(attachment(part, Vector3.new(0, size.Y * 0.4, 0)), {
			Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(200, 236, 255)), Rate = 6,
			Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(30, 30),
			Size = sequence(0.25, 0.4), Transparency = sequence(0.2, 1), Acceleration = Vector3.new(0, 1, 0),
		})
	end,
	SandPuff = function(part, size)
		emitter(attachment(part, Vector3.new(0, -size.Y * 0.45, 0)), {
			Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(226, 196, 140)), Rate = 4,
			Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(0.5, 1.2), SpreadAngle = Vector2.new(80, 10),
			Size = sequence(0.3, 0.9), Transparency = sequence(0.4, 1),
		})
	end,
	Droplets = function(part, size)
		emitter(attachment(part, Vector3.new(0, size.Y * 0.2, 0)), {
			Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(120, 190, 255)), Rate = 8,
			Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0, 0.5), Acceleration = Vector3.new(0, -12, 0),
			Size = sequence(0.15, 0.1), Transparency = sequence(0.1, 0.8),
		})
	end,
	NeonSparks = function(part, size)
		emitter(attachment(part, Vector3.new(0, size.Y * 0.3, 0)), {
			Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(80, 230, 255)), LightEmission = 1, Rate = 10,
			Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(180, 180),
			Size = sequence(0.2, 0), Acceleration = Vector3.new(0, -6, 0),
		})
		light(part, Color3.fromRGB(80, 230, 255), 8, 1.5)
	end,
	Beam = function(part, size)
		local glow = part.Parent and part.Parent:FindFirstChild("Glow", true)
		local source = if glow and glow:IsA("BasePart") then glow else part
		local spot = Instance.new("SpotLight")
		spot.Color = Color3.fromRGB(255, 236, 160)
		spot.Range = 16
		spot.Angle = 35
		spot.Brightness = 3
		spot.Face = Enum.NormalId.Front
		spot.Parent = source
		light(source, Color3.fromRGB(255, 232, 140), 6, 1.2)
		local _ = size
	end,
	Confetti = function(part, size)
		emitter(attachment(part, Vector3.new(0, size.Y * 0.5, 0)), {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 80)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 200, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 120)),
			}),
			Rate = 7, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(2, 3.5), SpreadAngle = Vector2.new(40, 40),
			Size = sequence(0.2, 0.15), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200),
			Acceleration = Vector3.new(0, -5, 0),
		})
	end,
	FireTrail = function(part, size)
		emitter(attachment(part, Vector3.new(0, -size.Y * 0.5, 0)), {
			Texture = FIRE, Color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 70, 20)), LightEmission = 1,
			Rate = 30, Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(2, 4), EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(15, 15), Size = sequence(0.5, 0.1), Transparency = sequence(0.1, 1),
		})
		trail(part, size, ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 60, 20)), 0.35)
		light(part, Color3.fromRGB(255, 140, 60), 8, 1.4)
	end,
	Mist = function(part, size)
		emitter(attachment(part, Vector3.new(0, -size.Y * 0.3, 0)), {
			Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(230, 236, 255)), Rate = 6,
			Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(0.2, 0.6), SpreadAngle = Vector2.new(180, 20),
			Size = sequence(0.6, 1.4), Transparency = sequence(0.5, 1),
		})
		trail(part, size, ColorSequence.new(Color3.fromRGB(220, 230, 255)), 0.5)
	end,
	TractorBeam = function(part, size)
		emitter(attachment(part, Vector3.new(0, -size.Y * 0.4, 0)), {
			Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(140, 255, 160)), LightEmission = 1, Rate = 14,
			Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(1.5, 2.5), EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(12, 12), Size = sequence(0.25, 0.05),
		})
		light(part, Color3.fromRGB(120, 255, 150), 9, 1.6)
	end,
	GoldHalo = function(part, size)
		emitter(attachment(part, Vector3.new(0, size.Y * 0.6, 0)), {
			Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 220, 110)), LightEmission = 1, Rate = 12,
			Lifetime = NumberRange.new(0.8, 1.2), Speed = NumberRange.new(0.3, 0.8), Shape = Enum.ParticleEmitterShape.Disc,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Size = sequence(0.3, 0),
		})
		light(part, Color3.fromRGB(255, 210, 110), 9, 1.4)
	end,
	Frost = function(part, size)
		emitter(attachment(part, Vector3.new(0, 0, 0)), {
			Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(220, 250, 255)), LightEmission = 1, Rate = 10,
			Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
			Size = sequence(0.25, 0),
		})
		emitter(attachment(part, Vector3.new(0, -size.Y * 0.4, 0)), {
			Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(200, 240, 255)), Rate = 3,
			Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.2, 0.5), Size = sequence(0.4, 1), Transparency = sequence(0.6, 1),
		})
		light(part, Color3.fromRGB(150, 220, 255), 10, 1.6)
	end,
	PurpleFlames = function(part, size)
		emitter(attachment(part, Vector3.new(0, size.Y * 0.2, 0)), {
			Texture = FIRE, Color = ColorSequence.new(Color3.fromRGB(200, 120, 255), Color3.fromRGB(110, 30, 220)), LightEmission = 1,
			Rate = 22, Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(1.5, 3), SpreadAngle = Vector2.new(20, 20),
			Size = sequence(0.6, 0.1), Transparency = sequence(0.1, 1),
		})
		light(part, Color3.fromRGB(170, 70, 255), 10, 1.8)
	end,
}

-- Adds `effect` to a piece model (nil does nothing).
function PieceEffects.attach(model: Model, effect: string?)
	local builder = if effect then BUILDERS[effect] else nil
	local part = primary(model)
	if builder and part then
		local _, size = model:GetBoundingBox()
		builder(part, size)
	end
end

PieceEffects.IDS = {}
for id in BUILDERS do
	table.insert(PieceEffects.IDS, id)
end

return PieceEffects
