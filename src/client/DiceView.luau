--!strict
-- The 3D dice. Each roll plays a recorded physics throw (DiceThrow, Throws) on the board centre,
-- and the dice stay where they landed until the next roll. Not ready until the server has loaded
-- the die model; until then GameClient uses the 2D stage dice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DiceThrow = require(ReplicatedStorage.Shared.Dice.DiceThrow)
local Throws = require(ReplicatedStorage.Shared.Dice.Throws)

local BODY_COLOR = Color3.fromRGB(240, 234, 220) -- ivory
local PIP_COLOR = Color3.fromRGB(22, 22, 26)
local MODEL_SIZE = 1.2 -- studs, the Rounded die as uploaded
local WAIT_SECONDS = 30 -- for the server to load the model

local DiceView = {}
DiceView.__index = DiceView

export type DiceView = typeof(setmetatable(
	{} :: {
		parent: Instance,
		folder: Folder,
		dice: { Model },
		random: Random,
		playing: RBXScriptConnection?,
	},
	DiceView
))

local function build(template: Model): Model
	local die = template:Clone()
	local body = die:FindFirstChild("Body") :: BasePart
	local pips = die:FindFirstChild("Pips") :: BasePart
	die.PrimaryPart = body
	die.WorldPivot = body.CFrame -- frames place the die by its centre
	die:ScaleTo(DiceThrow.SIZE / MODEL_SIZE)
	for _, part in die:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	body.Color = BODY_COLOR
	body.Material = Enum.Material.SmoothPlastic
	pips.Color = PIP_COLOR
	pips.Material = Enum.Material.SmoothPlastic
	return die
end

function DiceView.new(parent: Instance): DiceView
	local folder = Instance.new("Folder")
	folder.Name = "Dice"
	local self = setmetatable({ parent = parent, folder = folder, dice = {}, random = Random.new(), playing = nil }, DiceView)
	task.spawn(function()
		local assets = ReplicatedStorage:WaitForChild("Assets", WAIT_SECONDS)
		local kind = assets and assets:WaitForChild("Dice", WAIT_SECONDS)
		local template = kind and kind:WaitForChild("Rounded", WAIT_SECONDS)
		if template and template:IsA("Model") and #Throws > 0 then
			self.dice = { build(template), build(template) }
			for _, die in self.dice do
				die.Parent = folder
			end
		end
	end)
	return self
end

function DiceView.ready(self: DiceView): boolean
	return #self.dice == 2
end

local function stop(self: DiceView)
	if self.playing then
		self.playing:Disconnect()
		self.playing = nil
	end
end

-- Throws the dice from the roller's side (0-3) so they land showing `dice`.
function DiceView.roll(self: DiceView, dice: { number }, side: number)
	stop(self)
	local throw = Throws[self.random:NextInteger(1, #Throws)]
	local spin = { self.random:NextInteger(0, 3), self.random:NextInteger(0, 3) }
	local plan = DiceThrow.plan(throw, dice, side, spin)
	local count = DiceThrow.frameCount(throw)
	local surface = DiceThrow.surface()
	local started = os.clock()

	-- Places the dice `elapsed` seconds into the throw, blending between recorded frames.
	local function place(elapsed: number)
		local at = math.clamp(elapsed * DiceThrow.FPS + 1, 1, count)
		local index = math.floor(at)
		local alpha = at - index
		local nextIndex = math.min(index + 1, count)
		for d, die in self.dice do
			die:PivotTo(surface * plan[d][index]:Lerp(plan[d][nextIndex], alpha))
		end
	end

	place(0)
	self.folder.Parent = self.parent
	self.playing = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		place(elapsed)
		if elapsed * DiceThrow.FPS + 1 >= count then
			stop(self) -- resting: leave them where they landed
		end
	end)
end

-- Takes the dice off the board (game over, back to the lobby).
function DiceView.clear(self: DiceView)
	stop(self)
	self.folder.Parent = nil
end

return DiceView
