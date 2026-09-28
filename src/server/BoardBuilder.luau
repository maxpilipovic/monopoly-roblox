--!strict
-- Builds the 3D board from tile data. Server-side so it replicates to every client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorGroups = require(ReplicatedStorage.Shared.Board.ColorGroups)
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

local BoardBuilder = {}

BoardBuilder.MODEL_NAME = "Board"

local TILE_COLOR = Color3.fromRGB(214, 234, 214)
local BASE_COLOR = Color3.fromRGB(35, 35, 35)
local CENTER_COLOR = Color3.fromRGB(196, 226, 200)
local TEXT_COLOR = Color3.fromRGB(25, 25, 25)
local TILE_GAP = 0.15 -- tiles are shrunk by this much so the dark base shows as grid lines
local STRIP_DEPTH = 2.5 -- depth of the color band on property tiles
local PIXELS_PER_STUD = 40

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function labelText(tile: Tiles.Tile): string
	if tile.price then
		return `{tile.name}\n${tile.price}`
	elseif tile.amount then
		return `{tile.name}\nPay ${tile.amount}`
	end
	return tile.name
end

-- Text on the tile's top face, reading upright for someone sitting outside the board.
local function addLabel(part: BasePart, text: string, topInset: number)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.Parent = part

	-- A Top-face SurfaceGui's up points along the part's -X, but the tile's inner edge is -Z.
	-- Rotate the label a quarter turn clockwise and swap its proportions so it still fills the tile.
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(part.Size.X / part.Size.Z, part.Size.Z / part.Size.X)
	label.Rotation = 90
	label.TextScaled = true
	label.TextWrapped = true
	label.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	label.TextColor3 = TEXT_COLOR
	label.Text = text
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(topInset, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = label
end

local function buildTile(tile: Tiles.Tile, parent: Instance)
	local placement = Layout.getTilePlacement(tile.position)
	local size = placement.size - Vector3.new(TILE_GAP, 0, TILE_GAP)
	local part = makePart(
		string.format("Tile%02d", tile.position),
		size,
		Layout.ORIGIN * placement.cframe,
		TILE_COLOR,
		parent
	)
	part:SetAttribute("TilePosition", tile.position)
	part:SetAttribute("TileName", tile.name)

	local topInset = 0
	if tile.group then
		-- Band along the inner edge (the tile's -Z side), sitting just on top of the tile.
		local strip = makePart(
			"ColorStrip",
			Vector3.new(size.X, 0.1, STRIP_DEPTH),
			part.CFrame * CFrame.new(0, size.Y / 2 + 0.05, -(size.Z / 2 - STRIP_DEPTH / 2)),
			ColorGroups[tile.group].color,
			part
		)
		strip.CanCollide = false
		topInset = STRIP_DEPTH / size.Z
	end

	addLabel(part, labelText(tile), topInset)
end

function BoardBuilder.build(parent: Instance): Model
	local existing = parent:FindFirstChild(BoardBuilder.MODEL_NAME)
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = BoardBuilder.MODEL_NAME
	-- Players have no characters to stream around, so the whole board must always be sent.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	-- Dark slab under everything; slightly lower so tile tops sit above it.
	makePart(
		"Base",
		Vector3.new(Layout.BOARD_SIZE, Layout.TILE_THICKNESS, Layout.BOARD_SIZE),
		Layout.ORIGIN * CFrame.new(0, -0.1, 0),
		BASE_COLOR,
		model
	)

	local innerSize = Layout.BOARD_SIZE - 2 * Layout.CORNER_SIZE - TILE_GAP
	local center = makePart(
		"Center",
		Vector3.new(innerSize, Layout.TILE_THICKNESS, innerSize),
		Layout.ORIGIN,
		CENTER_COLOR,
		model
	)
	model.PrimaryPart = center

	local tileFolder = Instance.new("Folder")
	tileFolder.Name = "Tiles"
	tileFolder.Parent = model
	for _, tile in Tiles.list do
		buildTile(tile, tileFolder)
	end

	model.Parent = parent
	return model
end

return BoardBuilder
