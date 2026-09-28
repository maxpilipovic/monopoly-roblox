--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local BoardBuilder = require(ServerScriptService.Server.BoardBuilder)
local Expect = require(script.Parent.Expect)

local tests = {}

local function withBoard(fn: (Model) -> ())
	local scratch = Instance.new("Folder")
	local ok, err = pcall(function()
		fn(BoardBuilder.build(scratch))
	end)
	scratch:Destroy()
	if not ok then
		error(err, 0)
	end
end

local function tilePart(board: Model, position: number): BasePart
	return (board:FindFirstChild("Tiles") :: Folder):FindFirstChild(string.format("Tile%02d", position)) :: BasePart
end

tests["builds one part per tile with position attributes"] = function()
	withBoard(function(board)
		Expect.equal(board.Name, "Board")
		Expect.equal(#(board:FindFirstChild("Tiles") :: Folder):GetChildren(), 40, "tile count")
		for _, tile in Tiles.list do
			local part = tilePart(board, tile.position)
			assert(part, `missing Tile{tile.position}`)
			Expect.equal(part:GetAttribute("TilePosition"), tile.position, "TilePosition")
			Expect.equal(part:GetAttribute("TileName"), tile.name, "TileName")
			local expected = (Layout.ORIGIN * Layout.getTilePlacement(tile.position).cframe).Position
			Expect.vectorNear(part.Position, expected, `Tile{tile.position} position`)
			assert(part.Anchored, `Tile{tile.position} not anchored`)
		end
	end)
end

tests["property tiles have a color strip in their group color"] = function()
	withBoard(function(board)
		for _, tile in Tiles.list do
			local strip = tilePart(board, tile.position):FindFirstChild("ColorStrip") :: BasePart?
			if tile.kind == "Property" then
				assert(strip, `{tile.name} has no ColorStrip`)
				Expect.equal(strip.Color, ColorGroups[tile.group :: string].color, `{tile.name} strip color`)
			else
				assert(strip == nil, `{tile.name} should not have a ColorStrip`)
			end
		end
	end)
end

tests["every tile has a label with its name"] = function()
	withBoard(function(board)
		for _, tile in Tiles.list do
			local label = tilePart(board, tile.position):FindFirstChild("Label", true) :: TextLabel
			assert(label, `{tile.name} has no Label`)
			assert(label.Text:find(tile.name, 1, true), `{tile.name} label text is "{label.Text}"`)
		end
	end)
end

tests["rebuilding replaces the existing board"] = function()
	local scratch = Instance.new("Folder")
	BoardBuilder.build(scratch)
	BoardBuilder.build(scratch)
	Expect.equal(#scratch:GetChildren(), 1, "boards in parent")
	scratch:Destroy()
end

return tests
