--!strict
-- Any loaded model (ReplicatedStorage.Assets.<Kind>.<Shape>) turning slowly in a ViewportFrame: piece
-- previews in the lobby, chests in the shop. `finish` dresses the clone (colours, materials). Falls
-- back to a text mark until the model has loaded. Never put one under a ClipsDescendants ancestor:
-- Roblox doesn't draw a ViewportFrame there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ModelView = {}
ModelView.__index = ModelView

local FOV = 30
local TILT = math.rad(-14)

export type ModelView = typeof(setmetatable(
	{} :: {
		frame: ViewportFrame,
		mark: TextLabel,
		camera: Camera,
		model: Model?,
		key: string?,
		phase: number,
		speed: number,
		wobble: number, -- extra shake (the chest before it opens)
	},
	ModelView
))

local views: { [ModelView]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local started = false

local function startTurning()
	if started or not RunService:IsClient() then
		return
	end
	started = true
	RunService.RenderStepped:Connect(function(dt)
		for view in views do
			local model = view.model
			if model and view.frame.Visible and view.frame.Parent then
				view.phase += dt * view.speed
				local shake = if view.wobble > 0
					then CFrame.Angles(0, 0, math.sin(os.clock() * 40) * view.wobble) * CFrame.new(math.sin(os.clock() * 33) * view.wobble, 0, 0)
					else CFrame.identity
				model:PivotTo(shake * CFrame.Angles(TILT, 0, 0) * CFrame.Angles(0, view.phase, 0))
			end
		end
	end)
end

function ModelView.new(name: string, parent: Instance, size: UDim2): ModelView
	local frame = Instance.new("ViewportFrame")
	frame.Name = name
	frame.Size = size
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(150, 150, 165)
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
	mark.TextScaled = true
	mark.TextColor3 = Color3.fromRGB(222, 190, 110)
	mark.Text = ""
	mark.Parent = frame
	local self = setmetatable({
		frame = frame,
		mark = mark,
		camera = camera,
		model = nil :: Model?,
		key = nil :: string?,
		phase = math.random() * math.pi * 2,
		speed = 0.8,
		wobble = 0,
	}, ModelView)
	views[self] = true
	startTurning()
	return self
end

local function template(kind: string, shape: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(kind)
	local model = folder and folder:FindFirstChild(shape)
	return if model and model:IsA("Model") then model else nil
end

function ModelView.set(self: ModelView, kind: string?, shape: string?, finish: ((Model) -> ())?, fallback: string?)
	self.mark.Text = fallback or ""
	local source = if kind and shape then template(kind, shape) else nil
	local key = if kind and shape then `{kind}/{shape}/{source ~= nil}` else nil
	if key == self.key then
		self.mark.Visible = self.model == nil
		return
	end
	self.key = key
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
	if source then
		local model = source:Clone()
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		if finish then
			finish(model)
		end
		local box, size = model:GetBoundingBox()
		model.WorldPivot = box
		model:PivotTo(CFrame.identity)
		model.Parent = self.frame
		self.model = model
		local radius = size.Magnitude / 2
		self.camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, radius / math.tan(math.rad(FOV / 2)) * 1.05), Vector3.zero)
	end
	self.mark.Visible = self.model == nil
end

return ModelView
