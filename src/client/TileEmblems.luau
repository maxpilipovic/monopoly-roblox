--!strict
-- Stands each emblem on its tiles: the locomotive on the railroads, the bulb and the tap on the
-- utilities. They sit in the tile's
-- inner half (the label moves to the outer half) facing the players, and stay still so the board
-- stays calm. Waits for Assets to load the models; tiles without them simply stay bare.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmblemLook = require(ReplicatedStorage.Shared.Board.EmblemLook)
local TileArt = require(ReplicatedStorage.Shared.Board.TileArt)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

local TileEmblems = {}

local FOLDER_WAIT_SECONDS = 60 -- for Assets to reach the emblems
local SHAPE_WAIT_SECONDS = 20 -- for one emblem inside it
-- How tall each emblem stands, in studs.
local HEIGHTS = { Question = 3.2, Chest = 2.5, Locomotive = 2.7, Bulb = 3.2, Tap = 3.2, Hangout = 3, Sub = 1.6, Pizza = 1.8, CarePackage = 2.3 }

-- Each shape is waited for once, whatever the answer, so a model that failed to load costs one
-- wait rather than one per tile.
local function templates(): (string) -> Model?
	local assets = ReplicatedStorage:WaitForChild("Assets", FOLDER_WAIT_SECONDS)
	local emblems = assets and assets:WaitForChild("Emblems", FOLDER_WAIT_SECONDS)
	local found: { [string]: Model | false } = {}
	return function(shape: string): Model?
		if not emblems then
			return nil
		end
		if found[shape] == nil then
			local model = emblems:WaitForChild(shape, SHAPE_WAIT_SECONDS)
			found[shape] = if model and model:IsA("Model") then model else false
		end
		return found[shape] or nil
	end
end

function TileEmblems.place(board: Model)
	task.spawn(function()
		local tiles = board:FindFirstChild("Tiles")
		if not tiles then
			return
		end
		local template = templates()
		local folder = Instance.new("Folder")
		folder.Name = "Emblems"
		folder.Parent = board
		for _, part in tiles:GetChildren() do
			local position = part:GetAttribute("TilePosition")
			if typeof(position) ~= "number" or not part:IsA("BasePart") then
				continue
			end
			local tile = Tiles.at(position)
			-- Chance and Community Chest have their pictures printed on (TileArt) instead.
			local shape = if TileArt.covers(tile) then nil else EmblemLook.forTile(tile)
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
