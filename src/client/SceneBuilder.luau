--!strict
-- The world around the board while a game is on, built on this client from SceneKit: the table,
-- the scene's terrain and water, its buildings and props, and its moving parts. Also lights and
-- grades it. When the scene is cleared, everything it changed (lighting, effects, water, terrain,
-- the baseplate) goes back to how the lobby had it.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Scenes = require(ReplicatedStorage.Shared.Board.Scenes)
local Kit = require(script.Parent.SceneKit.Kit)

local BUILDERS: { [string]: (Kit.Context) -> () } = {
	Boardwalk = require(script.Parent.SceneKit.Boardwalk),
	Tropical = require(script.Parent.SceneKit.Tropical),
	Winter = require(script.Parent.SceneKit.Winter),
	City = require(script.Parent.SceneKit.City),
}

local SceneBuilder = {}

type Saved = { [Instance]: { [string]: any } }
local saved: Saved = {} -- every property a scene changed, with the lobby's value
local created: { Instance } = {} -- effects a scene added that the lobby didn't have
local animation: RBXScriptConnection? = nil

-- Sets `props` on `instance`, remembering the values they replace (only the first time).
local function set(instance: Instance, props: { [string]: any })
	local memory = saved[instance]
	if not memory then
		memory = {}
		saved[instance] = memory
	end
	for key, value in props do
		if memory[key] == nil then
			memory[key] = (instance :: any)[key]
		end
		(instance :: any)[key] = value
	end
end

local function effect(className: string): Instance
	local existing = Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local new = Instance.new(className)
	new.Name = "Scene" .. className
	new.Parent = Lighting
	table.insert(created, new)
	return new
end

local function applyLighting(scene: Scenes.Scene)
	set(Lighting, {
		ClockTime = scene.clockTime,
		GeographicLatitude = scene.latitude,
		Brightness = scene.brightness,
		ExposureCompensation = scene.exposure,
		Ambient = scene.ambient,
		OutdoorAmbient = scene.outdoorAmbient,
		FogColor = scene.fogColor,
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 1,
	})
	set(effect("Atmosphere"), {
		Density = scene.atmosphereDensity,
		Color = scene.atmosphereColor,
		Decay = scene.atmosphereDecay,
		Glare = scene.glare,
		Haze = scene.haze,
		Offset = 0.1,
	})
	set(effect("BloomEffect"), { Enabled = true, Intensity = scene.bloom.intensity, Size = scene.bloom.size, Threshold = scene.bloom.threshold })
	set(effect("SunRaysEffect"), { Enabled = scene.sunRays > 0, Intensity = scene.sunRays, Spread = 0.5 })
	set(effect("ColorCorrectionEffect"), {
		Enabled = true,
		Brightness = scene.grade.brightness,
		Contrast = scene.grade.contrast,
		Saturation = scene.grade.saturation,
		TintColor = scene.grade.tint,
	})
	-- A soft far blur: the board stays sharp, the horizon melts a little.
	set(effect("DepthOfFieldEffect"), { Enabled = true, FarIntensity = 0.18, NearIntensity = 0, FocusDistance = 120, InFocusRadius = 110 })
end

local function restore()
	for instance, memory in saved do
		if instance.Parent then
			for key, value in memory do
				(instance :: any)[key] = value
			end
		end
	end
	saved = {}
	for _, instance in created do
		instance:Destroy()
	end
	created = {}
end

local function hideBaseplate()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		set(baseplate, { LocalTransparencyModifier = 1 })
		-- Its grid texture doesn't follow the part's transparency; hide that too.
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				set(child, { Transparency = 1 })
			end
		end
	end
end

-- Builds `sceneId`'s world around the board (on this client only), lights it and sets it moving.
function SceneBuilder.build(sceneId: string?, parent: Instance): Model
	local scene = Scenes.byId[sceneId or ""] or Scenes.LIST[1]
	local model = Instance.new("Model")
	model.Name = "Scene"
	local animators: { Kit.Animator } = {}
	local ctx: Kit.Context = {
		scene = scene,
		model = model,
		random = Random.new(7), -- the same layout every time for a scene
		animate = function(animator: Kit.Animator)
			table.insert(animators, animator)
		end,
		water = function(props: { [string]: any })
			set(workspace.Terrain, props)
		end,
	}
	BUILDERS[scene.id](ctx)
	local sky = model:FindFirstChildOfClass("Sky")
	if sky then
		sky.Name = "SceneSky"
		sky.Parent = Lighting
		table.insert(created, sky)
		-- Only one Sky counts: park the lobby's own while the scene's is up.
		for _, other in Lighting:GetChildren() do
			if other:IsA("Sky") and other ~= sky then
				set(other, { Parent = ReplicatedStorage })
			end
		end
	end
	model.Parent = parent
	applyLighting(scene)
	hideBaseplate()

	if animation then
		animation:Disconnect()
	end
	local started = os.clock()
	animation = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - started
		for _, animator in animators do
			animator(t, dt)
		end
	end)
	return model
end

function SceneBuilder.clear(model: Model?)
	if animation then
		animation:Disconnect()
		animation = nil
	end
	if model then
		model:Destroy()
	end
	workspace.Terrain:Clear() -- the scene's land and water; the lobby is built of parts
	restore()
end

return SceneBuilder
