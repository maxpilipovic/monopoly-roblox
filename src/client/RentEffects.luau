--!strict
-- The rent effects players win from chests: when someone pays them rent, theirs plays over the
-- payer's token. Each is a short burst of parts, particles and lights, cleaned up after itself.

local TweenService = game:GetService("TweenService")

local RentEffects = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function sequence(from: number, to: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, to) })
end

local function anchor(at: Vector3, lifetime: number): Part
	local p = Instance.new("Part")
	p.Name = "RentEffect"
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = CFrame.new(at)
	p.Parent = workspace
	task.delay(lifetime, function()
		p:Destroy()
	end)
	return p
end

local function burst(parent: Instance, count: number, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	e:Emit(count)
end

local function flash(parent: BasePart, color: Color3, range: number, seconds: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 6
	l.Parent = parent
	TweenService:Create(l, TweenInfo.new(seconds), { Brightness = 0 }):Play()
end

local function glowBall(at: Vector3, color: Color3, from: number, to: number, seconds: number, material: Enum.Material?)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * from
	ball.CFrame = CFrame.new(at)
	ball.Color = color
	ball.Material = material or Enum.Material.Neon
	ball.Transparency = 0.2
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Parent = workspace
	TweenService:Create(ball, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * to, Transparency = 1 }):Play()
	task.delay(seconds + 0.05, function()
		ball:Destroy()
	end)
end

local PLAYERS: { [string]: (Vector3) -> () } = {
	CoinBurst = function(at)
		local a = anchor(at + Vector3.new(0, 1.5, 0), 2.5)
		burst(a, 40, {
			Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 210, 80)), LightEmission = 0.8,
			Lifetime = NumberRange.new(1, 1.5), Speed = NumberRange.new(10, 16), SpreadAngle = Vector2.new(35, 35),
			Acceleration = Vector3.new(0, -30, 0), Size = sequence(0.6, 0.4), Rotation = NumberRange.new(0, 360),
		})
		flash(a, Color3.fromRGB(255, 210, 90), 14, 0.8)
	end,
	ConfettiPop = function(at)
		local a = anchor(at + Vector3.new(0, 2, 0), 3)
		burst(a, 70, {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 80)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 200, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 255, 120)),
			}),
			Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, -12, 0), Drag = 2, Size = sequence(0.35, 0.25),
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300),
		})
	end,
	MoneyRain = function(at)
		local a = anchor(at + Vector3.new(0, 10, 0), 4)
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromRGB(120, 210, 120))
		e.Shape = Enum.ParticleEmitterShape.Disc
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Lifetime = NumberRange.new(1.5, 2)
		e.Speed = NumberRange.new(0, 1)
		e.Acceleration = Vector3.new(0, -8, 0)
		e.Drag = 1
		e.Size = NumberSequence.new(0.6)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-180, 180)
		e.Rate = 50
		e.Parent = a
		local _ = a.Size
		task.delay(1.6, function()
			e.Enabled = false
		end)
	end,
	GoldenAura = function(at)
		glowBall(at + Vector3.new(0, 1, 0), Color3.fromRGB(255, 205, 90), 1, 9, 1.2)
		local a = anchor(at + Vector3.new(0, 1, 0), 2.5)
		burst(a, 40, {
			Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 225, 120)), LightEmission = 1,
			Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(180, 180),
			Size = sequence(0.5, 0),
		})
		flash(a, Color3.fromRGB(255, 210, 100), 16, 1.2)
	end,
	Lightning = function(at)
		-- A jagged neon bolt from the sky down to the token.
		local top = at + Vector3.new(0, 30, 0)
		local points = { top }
		for index = 1, 6 do
			local t = index / 7
			table.insert(points, top:Lerp(at, t) + Vector3.new(math.random(-15, 15) / 10, 0, math.random(-15, 15) / 10))
		end
		table.insert(points, at)
		for index = 1, #points - 1 do
			local a, b = points[index], points[index + 1]
			local segment = Instance.new("Part")
			segment.Size = Vector3.new(0.35, 0.35, (b - a).Magnitude)
			segment.CFrame = CFrame.lookAt((a + b) / 2, b)
			segment.Color = Color3.fromRGB(200, 230, 255)
			segment.Material = Enum.Material.Neon
			segment.Anchored = true
			segment.CanCollide = false
			segment.CanQuery = false
			segment.CanTouch = false
			segment.Parent = workspace
			TweenService:Create(segment, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			task.delay(0.55, function()
				segment:Destroy()
			end)
		end
		local a = anchor(at, 2)
		flash(a, Color3.fromRGB(180, 220, 255), 30, 0.6)
		burst(a, 30, {
			Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(190, 230, 255)), LightEmission = 1,
			Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(8, 14), SpreadAngle = Vector2.new(80, 80),
			Size = sequence(0.4, 0), Acceleration = Vector3.new(0, -20, 0),
		})
	end,
	Fireworks = function(at)
		local colors = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(110, 200, 255), Color3.fromRGB(255, 220, 90) }
		for index, color in colors do
			task.delay((index - 1) * 0.3, function()
				local spot = at + Vector3.new(math.random(-4, 4), 9 + math.random(0, 4), math.random(-4, 4))
				local a = anchor(spot, 2.5)
				burst(a, 60, {
					Texture = SPARKLE, Color = ColorSequence.new(color), LightEmission = 1,
					Lifetime = NumberRange.new(0.9, 1.3), Speed = NumberRange.new(10, 14), SpreadAngle = Vector2.new(180, 180),
					Drag = 3, Acceleration = Vector3.new(0, -6, 0), Size = sequence(0.5, 0),
				})
				flash(a, color, 20, 0.8)
			end)
		end
	end,
	BlackHole = function(at)
		local centre = at + Vector3.new(0, 2.5, 0)
		local hole = Instance.new("Part")
		hole.Shape = Enum.PartType.Ball
		hole.Size = Vector3.one * 0.5
		hole.CFrame = CFrame.new(centre)
		hole.Color = Color3.fromRGB(8, 4, 16)
		hole.Material = Enum.Material.SmoothPlastic
		hole.Anchored = true
		hole.CanCollide = false
		hole.CanQuery = false
		hole.CanTouch = false
		hole.Parent = workspace
		TweenService:Create(hole, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.one * 4 }):Play()
		local a = anchor(centre, 2.6)
		local swirl = Instance.new("ParticleEmitter")
		swirl.Texture = SMOKE
		swirl.Color = ColorSequence.new(Color3.fromRGB(170, 70, 255), Color3.fromRGB(40, 10, 80))
		swirl.LightEmission = 0.6
		swirl.Shape = Enum.ParticleEmitterShape.Sphere
		swirl.ShapeInOut = Enum.ParticleEmitterShapeInOut.InAndOut
		swirl.Lifetime = NumberRange.new(0.6, 0.9)
		swirl.Speed = NumberRange.new(-8, -6) -- inward
		swirl.Size = sequence(1.2, 0.2)
		swirl.Transparency = sequence(0.2, 1)
		swirl.Rate = 80
		swirl.Parent = a
		flash(a, Color3.fromRGB(150, 60, 255), 18, 1.8)
		task.delay(1.6, function()
			swirl.Enabled = false
			TweenService:Create(hole, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Size = Vector3.one * 0.05 }):Play()
			task.delay(0.4, function()
				hole:Destroy()
				glowBall(centre, Color3.fromRGB(190, 120, 255), 0.5, 6, 0.4)
			end)
		end)
	end,
}

function RentEffects.play(effect: string?, at: Vector3)
	local player = if effect then PLAYERS[effect] else nil
	if player then
		player(at)
	end
end

RentEffects.IDS = {}
for id in PLAYERS do
	table.insert(RentEffects.IDS, id)
end

return RentEffects
