--!strict
-- A card's emblem: its 3D model (from ReplicatedStorage.Assets.Emblems) turning slowly in a
-- ViewportFrame. Until the model has loaded, or for a card without one, it shows a text mark.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EmblemLook = require(ReplicatedStorage.Shared.Board.EmblemLook)

local EmblemView = {}
EmblemView.__index = EmblemView

local FOV = 28
local TURN_SPEED = 0.9 -- radians per second
local TILT = math.rad(-12) -- seen from a little above

export type EmblemView = typeof(setmetatable(
	{} :: {
		frame: ViewportFrame,
		mark: TextLabel,
		camera: Camera,
		model: Model?,
		shape: string?,
		centre: CFrame,
		phase: number,
	},
	EmblemView
))

local views: { [EmblemView]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local started = false

local function startTurning()
	if started or not RunService:IsClient() then
		return -- the HUD is also built in server-side tests, where there are no frames to turn on
	end
	started = true
	RunService.RenderStepped:Connect(function(dt)
		for view in views do
			local model = view.model
			if model and view.frame.Visible and view.frame.Parent then
				view.phase += dt * TURN_SPEED
				model:PivotTo(CFrame.Angles(TILT, 0, 0) * CFrame.Angles(0, view.phase, 0) * view.centre)
			end
		end
	end)
end

function EmblemView.new(name: string, parent: Instance, size: UDim2, markSize: number): EmblemView
	local frame = Instance.new("ViewportFrame")
	frame.Name = name
	frame.Size = size
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(150, 150, 160)
	frame.LightColor = Color3.fromRGB(255, 246, 230)
	frame.LightDirection = Vector3.new(-1, -1.4, -1)
	frame.Parent = parent
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = frame
	frame.CurrentCamera = camera

	local mark = Instance.new("TextLabel")
	mark.Name = "Mark"
	mark.Size = UDim2.fromScale(1, 1)
	mark.BackgroundTransparency = 1
	mark.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	mark.TextSize = markSize
	mark.TextColor3 = Color3.new(1, 1, 1)
	mark.Text = ""
	mark.Parent = frame

	local self = setmetatable({
		frame = frame,
		mark = mark,
		camera = camera,
		model = nil :: Model?,
		shape = nil :: string?,
		centre = CFrame.identity,
		phase = math.random() * math.pi * 2,
	}, EmblemView)
	views[self] = true
	startTurning()
	return self
end

local function template(shape: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local emblems = assets and assets:FindFirstChild("Emblems")
	local model = emblems and emblems:FindFirstChild(shape)
	return if model and model:IsA("Model") then model else nil
end

-- Shows `shape`'s model (nil for none), or `fallback` text when there's no model to show.
function EmblemView.set(self: EmblemView, shape: string?, fallback: string, fallbackColor: Color3)
	self.mark.Text = fallback
	self.mark.TextColor3 = fallbackColor
	local source = if shape then template(shape) else nil
	if shape == self.shape and (self.model ~= nil) == (source ~= nil) then
		self.mark.Visible = self.model == nil
		return
	end
	self.shape = shape
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
	if source and shape then
		local model = source:Clone()
		EmblemLook.apply(model, shape)
		local box, size = model:GetBoundingBox()
		-- Pivot on the middle of the model so it turns in place at the origin.
		model.WorldPivot = box
		self.centre = CFrame.identity
		model:PivotTo(self.centre)
		model.Parent = self.frame
		self.model = model
		local radius = size.Magnitude / 2
		local distance = radius / math.tan(math.rad(FOV / 2)) * 1.05
		self.camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, distance), Vector3.zero)
	end
	self.mark.Visible = self.model == nil
end

return EmblemView
