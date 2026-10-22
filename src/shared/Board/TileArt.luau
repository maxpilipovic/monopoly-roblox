--!strict
-- The printed faces of the special tiles, laid out like the classic board: Go's diagonal "GO" over
-- its red arrow, the orange jail cell with "Just Visiting" round its edges, the parked car, the
-- pointing officer, Chance's big question mark and Community Chest's chest of coins. The pictures
-- are renders from tools/blender/tile_art.py; the words are text so each map can name the tiles.

local Tiles = require(script.Parent.Tiles)

local TileArt = {}

TileArt.IMAGES = table.freeze({
	Arrow = "rbxassetid://120270451350005",
	Question = "rbxassetid://107953654956090",
	Chest = "rbxassetid://137382609368714",
	Car = "rbxassetid://115835201015082",
	Officer = "rbxassetid://91358765395411",
})

TileArt.GO_SALARY = 200 -- matches Engine.GO_SALARY (server-only)

local PIXELS_PER_STUD = 30 -- scaled text stops at 100 px: this lets "GO" stand over 3 studs tall
local RED = Color3.fromRGB(200, 30, 38)
local INK = Color3.fromRGB(25, 25, 25)
local JAIL_ORANGE = Color3.fromRGB(242, 140, 40)
local DIAGONAL = -45 -- corner words run from the inner side up to the outer corner, like the board

local KINDS = { Go = true, Jail = true, FreeParking = true, GoToJail = true, Chance = true, CommunityChest = true }

function TileArt.covers(tile: Tiles.Tile): boolean
	return KINDS[tile.kind] == true
end

-- Words printed on the tile: capitals, like the board.
function TileArt.title(tile: Tiles.Tile): string
	return string.upper(tile.name)
end

local function place(item: GuiObject, center: Vector2, size: Vector2, rotation: number?)
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Position = UDim2.fromScale(center.X, center.Y)
	item.Size = UDim2.fromScale(size.X, size.Y)
	item.Rotation = rotation or 0
end

local function words(parent: Instance, name: string, text: string, center: Vector2, size: Vector2, options: {
	rotation: number?,
	color: Color3?,
	font: Enum.Font?,
	maxSize: number?,
}): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	place(label, center, size, options.rotation)
	label.TextScaled = true
	label.TextWrapped = true
	label.FontFace = Font.fromEnum(options.font or Enum.Font.GothamBlack)
	label.TextColor3 = options.color or INK
	label.Text = text
	label.Parent = parent
	if options.maxSize then
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = options.maxSize
		limit.Parent = label
	end
	return label
end

local function picture(parent: Instance, image: string, center: Vector2, size: Vector2, rotation: number?): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = "Picture"
	label.BackgroundTransparency = 1
	label.Image = image
	label.ScaleType = Enum.ScaleType.Fit
	place(label, center, size, rotation)
	label.Parent = parent
	return label
end

local function box(parent: Instance, name: string, color: Color3, center: Vector2, size: Vector2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	place(frame, center, size)
	frame.Parent = parent
	return frame
end

-- Canvas, as seen from outside the board: top is the tile's inner edge (toward the centre), bottom
-- its outer edge, right is +X. On a corner the bottom-right is the board's outer corner.
local function canvas(part: BasePart): Frame
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Art"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.Parent = part
	-- A Top-face SurfaceGui's up is the part's -X; turn a quarter so up is -Z (see BoardBuilder).
	local frame = Instance.new("Frame")
	frame.Name = "Canvas"
	frame.BackgroundTransparency = 1
	place(frame, Vector2.new(0.5, 0.5), Vector2.new(part.Size.X / part.Size.Z, part.Size.Z / part.Size.X), 90)
	frame.Parent = gui
	return frame
end

local function go(art: Frame, tile: Tiles.Tile)
	words(art, "Note", `COLLECT ${TileArt.GO_SALARY} SALARY AS YOU PASS`, Vector2.new(0.3, 0.3), Vector2.new(0.62, 0.14), {
		rotation = DIAGONAL,
		font = Enum.Font.GothamBold,
	})
	words(art, "Label", TileArt.title(tile), Vector2.new(0.55, 0.55), Vector2.new(0.85, 0.34), {
		rotation = DIAGONAL,
		color = RED,
	})
	-- Points the way the pieces go: from Go along this side, toward -X.
	picture(art, TileArt.IMAGES.Arrow, Vector2.new(0.46, 0.88), Vector2.new(0.84, 0.2), 180)
end

TileArt.JAIL_CELL = 0.62 -- the cell fills this much of the corner, from its inner corner (TokenLayout)
local CELL = TileArt.JAIL_CELL

local function jail(art: Frame, tile: Tiles.Tile)
	local cell = box(art, "Cell", JAIL_ORANGE, Vector2.new(CELL / 2, CELL / 2), Vector2.new(CELL, CELL))
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.Parent = cell
	-- The window and the name, turned to face the outer corner like the other corners' words.
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BackgroundTransparency = 1
	place(face, Vector2.new(0.5, 0.5), Vector2.new(0.7, 0.7), DIAGONAL)
	face.Parent = cell
	-- Black bars straight over the orange, as printed.
	local window = box(face, "Window", INK, Vector2.new(0.5, 0.34), Vector2.new(0.9, 0.62))
	window.BackgroundTransparency = 1
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = INK
	frameStroke.Thickness = 3
	frameStroke.Parent = window
	for i = 1, 4 do
		box(window, "Bar", INK, Vector2.new(i / 5, 0.5), Vector2.new(0.07, 1))
	end
	box(window, "Rail", INK, Vector2.new(0.5, 0.5), Vector2.new(1, 0.08))
	words(face, "Label", TileArt.title(tile), Vector2.new(0.5, 0.84), Vector2.new(1, 0.3), {})
	-- Visitors stand round the cell. The canvas bottom is the outer edge of the side Jail starts
	-- (the board's left), its right edge the outer edge of the side before it (the bottom row):
	-- "Just" up the left, "Visiting" along the bottom, as on the board.
	words(art, "Visiting", "VISITING", Vector2.new((1 + CELL) / 2, CELL / 2), Vector2.new(CELL * 0.9, (1 - CELL) * 0.6), {
		rotation = -90,
	})
	words(art, "Just", "JUST", Vector2.new(CELL / 2, (1 + CELL) / 2), Vector2.new(CELL * 0.8, (1 - CELL) * 0.6), {})
end

-- Free Parking and Go To Jail: the name above a picture, both turned to the outer corner.
local function cornerPicture(art: Frame, tile: Tiles.Tile, image: string)
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BackgroundTransparency = 1
	place(face, Vector2.new(0.5, 0.5), Vector2.new(1, 1), DIAGONAL)
	face.Parent = art
	-- The name goes round the picture, its last word underneath ("FREE" / car / "PARKING"). The
	-- face's ends reach into the tile's narrow corners, so the words keep to its middle.
	local head, tail = string.match(TileArt.title(tile), "^(.+)%s(%S+)$")
	words(face, "Label", head or TileArt.title(tile), Vector2.new(0.5, 0.2), Vector2.new(0.6, 0.15), {})
	if tail then
		words(face, "LabelEnd", tail, Vector2.new(0.5, 0.8), Vector2.new(0.6, 0.15), {})
	end
	picture(face, image, Vector2.new(0.5, 0.5), Vector2.new(0.66, 0.42))
end

-- Chance and Community Chest: the name across the inner end, the picture filling the rest.
local function card(art: Frame, tile: Tiles.Tile, image: string)
	words(art, "Label", TileArt.title(tile), Vector2.new(0.5, 0.13), Vector2.new(0.9, 0.2), {})
	picture(art, image, Vector2.new(0.5, 0.6), Vector2.new(0.9, 0.66))
end

local BUILDERS: { [string]: (Frame, Tiles.Tile) -> () } = {
	Go = go,
	Jail = jail,
	FreeParking = function(art, tile)
		cornerPicture(art, tile, TileArt.IMAGES.Car)
	end,
	GoToJail = function(art, tile)
		cornerPicture(art, tile, TileArt.IMAGES.Officer)
	end,
	Chance = function(art, tile)
		card(art, tile, TileArt.IMAGES.Question)
	end,
	CommunityChest = function(art, tile)
		card(art, tile, TileArt.IMAGES.Chest)
	end,
}

-- Prints the tile's face onto its part, replacing any earlier one (each map names tiles anew).
function TileArt.apply(part: BasePart, tile: Tiles.Tile)
	local old = part:FindFirstChild("Art")
	if old then
		old:Destroy()
	end
	local build = BUILDERS[tile.kind]
	if build then
		build(canvas(part), tile)
	end
end

return TileArt
