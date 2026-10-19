--!strict
-- The board, built on this client while it's in a game and cleared when it goes back to the lobby
-- (every casual game uses the same spot, so the server can't build one board for all). Also shows
-- the Free Parking pot in the middle: a plaque with the amount, and stacks of cash that grow with it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BoardBuilder = require(ReplicatedStorage.Shared.Board.BoardBuilder)
local CashStacks = require(ReplicatedStorage.Shared.Board.CashStacks)
local DiceThrow = require(ReplicatedStorage.Shared.Dice.DiceThrow)
local TileEmblems = require(script.Parent.TileEmblems)

local BoardView = {}
BoardView.__index = BoardView

local BUNDLE_HEIGHT = 0.34 -- studs per bundle of bills in a stack
local BILL_GREEN = Color3.fromRGB(150, 196, 128)
local BAND = Color3.fromRGB(214, 172, 84)

export type BoardView = typeof(setmetatable(
	{} :: {
		parent: Instance,
		board: Model?,
		pot: Model?,
		amount: TextLabel?,
		shownPot: number,
		stacks: { Model },
	},
	BoardView
))

function BoardView.new(parent: Instance): BoardView
	return setmetatable({ parent = parent, board = nil, pot = nil, amount = nil, shownPot = -1, stacks = {} }, BoardView)
end

local function inert(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

-- One bundle of bills: the Blender cash model when loaded, otherwise a banded green block.
local function bundle(): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	local source = props and props:FindFirstChild("CashStack")
	local model: Model
	if source and source:IsA("Model") then
		model = source:Clone()
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				inert(part)
				if part.Name == "Body" then
					part.Color = BILL_GREEN
					part.Material = Enum.Material.SmoothPlastic
				else
					part.Color = BAND
					part.Material = Enum.Material.SmoothPlastic
				end
			end
		end
		local box, size = model:GetBoundingBox()
		model.WorldPivot = CFrame.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
		model:ScaleTo(BUNDLE_HEIGHT / size.Y)
	else
		model = Instance.new("Model")
		local bills = Instance.new("Part")
		bills.Name = "Body"
		bills.Size = Vector3.new(2.2, BUNDLE_HEIGHT, 1)
		bills.Color = BILL_GREEN
		bills.CFrame = CFrame.new(0, BUNDLE_HEIGHT / 2, 0)
		inert(bills)
		bills.Parent = model
		local band = Instance.new("Part")
		band.Name = "Band"
		band.Size = Vector3.new(0.4, BUNDLE_HEIGHT + 0.02, 1.02)
		band.Color = BAND
		band.CFrame = bills.CFrame
		inert(band)
		band.Parent = model
		model.WorldPivot = CFrame.new()
	end
	model.Name = "Bundle"
	return model
end

local function buildPot(self: BoardView, board: Model)
	local surface = DiceThrow.surface()
	local pot = Instance.new("Model")
	pot.Name = "FreeParkingPot"
	-- An upright plaque facing the players' side of the board.
	local plaque = Instance.new("Part")
	plaque.Name = "Plaque"
	plaque.Size = Vector3.new(15, 6, 0.5)
	-- Leaned back to face the overhead camera.
	plaque.CFrame = surface * CFrame.new(0, 2.4, 0) * CFrame.Angles(math.rad(-40), 0, 0)
	plaque.Color = Color3.fromRGB(20, 26, 42)
	plaque.Material = Enum.Material.SmoothPlastic
	inert(plaque)
	plaque.Parent = pot
	local frame = Instance.new("Part")
	frame.Name = "PlaqueFrame"
	frame.Size = Vector3.new(15.6, 6.6, 0.4)
	frame.CFrame = plaque.CFrame * CFrame.new(0, 0, -0.1)
	frame.Color = BAND
	frame.Material = Enum.Material.Metal
	inert(frame)
	frame.Parent = pot
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- the +Z side, towards the players
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = plaque
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.38)
	title.BackgroundTransparency = 1
	title.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	title.TextScaled = true
	title.TextColor3 = BAND
	title.Text = "FREE PARKING"
	title.Parent = gui
	local amount = Instance.new("TextLabel")
	amount.Name = "Amount"
	amount.Size = UDim2.fromScale(1, 0.58)
	amount.Position = UDim2.fromScale(0, 0.38)
	amount.BackgroundTransparency = 1
	amount.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	amount.TextScaled = true
	amount.TextColor3 = Color3.fromRGB(126, 226, 168)
	amount.Text = "$0"
	amount.Parent = gui
	pot.Parent = board
	self.pot = pot
	self.amount = amount
end

-- Builds the board if it isn't up yet.
function BoardView.ensure(self: BoardView)
	if self.board and self.board.Parent then
		return
	end
	local board = BoardBuilder.build(self.parent)
	TileEmblems.place(board)
	self.board = board
	self.shownPot = -1
	self.stacks = {}
	buildPot(self, board)
end

function BoardView.model(self: BoardView): Model?
	return self.board
end

-- Shows the Free Parking pot (hidden when the rule is off).
function BoardView.setPot(self: BoardView, enabled: boolean, pot: number)
	local model = self.pot
	if not model or not self.board then
		return
	end
	model.Parent = if enabled then self.board else nil
	if not enabled or pot == self.shownPot then
		return
	end
	local grew = pot > self.shownPot
	self.shownPot = pot
	;(self.amount :: TextLabel).Text = `${pot}`
	for _, stack in self.stacks do
		stack:Destroy()
	end
	self.stacks = {}
	local surface = DiceThrow.surface()
	for index, stack in CashStacks.layout(pot) do
		local pile = Instance.new("Model")
		pile.Name = `Stack{index}`
		local yaw = math.rad((index * 37) % 360) -- a little untidy, like a real pile of cash
		for level = 1, stack.bundles do
			local b = bundle()
			b:PivotTo(surface * CFrame.new(stack.offset + Vector3.new(0, (level - 1) * BUNDLE_HEIGHT, 0)) * CFrame.Angles(0, yaw + level * 0.12, 0))
			b.Parent = pile
		end
		pile.Parent = model
		table.insert(self.stacks, pile)
		if grew then
			-- New cash drops in.
			local value = Instance.new("CFrameValue")
			local home = pile:GetPivot()
			value.Value = home * CFrame.new(0, 3, 0)
			pile:PivotTo(value.Value)
			value.Changed:Connect(function(cframe)
				if pile.Parent then
					pile:PivotTo(cframe)
				end
			end)
			TweenService:Create(value, TweenInfo.new(0.35 + index * 0.03, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Value = home }):Play()
			task.delay(1, function()
				value:Destroy()
			end)
		end
	end
end

function BoardView.clear(self: BoardView)
	if self.board then
		self.board:Destroy()
	end
	self.board = nil
	self.pot = nil
	self.amount = nil
	self.stacks = {}
	self.shownPot = -1
end

return BoardView
