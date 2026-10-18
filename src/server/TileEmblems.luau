--!strict
-- Stands each emblem on its tiles: the gold question mark on Chance, the chest on Community Chest,
-- the locomotive on the railroads, the bulb and the tap on the utilities. They sit in the tile's
-- inner half (the label moves to the outer half) facing the players, and stay still so the board
-- stays calm. Waits for Assets to load the models; tiles without them simply stay bare.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmblemLook = require(ReplicatedStorage.Shared.Board.EmblemLook)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

local TileEmblems = {}

local WAIT_SECONDS = 60
-- How tall each emblem stands, in studs.
local HEIGHTS = { Question = 2.6, Chest = 2.0, Locomotive = 2.2, Bulb = 2.6, Tap = 2.6 }

local function template(shape: string): Model?
	local assets = ReplicatedStorage:WaitForChild("Assets", WAIT_SECONDS)
	local emblems = assets and assets:WaitForChild("Emblems", WAIT_SECONDS)
	local model = emblems and emblems:WaitForChild(shape, WAIT_SECONDS)
	return if model and model:IsA("Model") then model else nil
end

function TileEmblems.place(board: Model)
	task.spawn(function()
		local tiles = board:FindFirstChild("Tiles")
		if not tiles then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "Emblems"
		folder.Parent = board
		for _, part in tiles:GetChildren() do
			local position = part:GetAttribute("TilePosition")
			if typeof(position) ~= "number" or not part:IsA("BasePart") then
				continue
			end
			local shape = EmblemLook.forTile(Tiles.at(position))
			local source = shape and template(shape)
			if not (shape and source) then
				continue
			end
			local model = source:Clone()
			EmblemLook.apply(model, shape)
			local box, size = model:GetBoundingBox()
			model.WorldPivot = CFrame.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
			model:ScaleTo(HEIGHTS[shape] / size.Y)
			for _, child in model:GetDescendants() do
				if child:IsA("BasePart") then
					child.CastShadow = true
				end
			end
			-- Inner half of the tile (its -Z side faces the board's centre), front towards the players.
			model:PivotTo(part.CFrame * CFrame.new(0, part.Size.Y / 2, -part.Size.Z / 4))
			model.Name = `{shape}{position}`
			model.Parent = folder
		end
	end)
end

return TileEmblems
