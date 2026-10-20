--!strict
-- The UI icons: rendered in Blender by tools/blender/icons.py (assets/icons/*.png, one house style
-- with the game's own models and colours) and uploaded as images. `Icons.image` drops one in.

local Icons = {}

Icons.IDS = table.freeze({
	BlackHole = 110364613716718,
	Blueprint = 122907392742227,
	Boxcars = 128505471654854,
	BrokenCoin = 74583920643019,
	Bubbles = 107354438353167,
	Calendar = 97538964150318,
	Cash = 131284060771749,
	CashFlow = 114983450579729,
	Chance = 140723348066279,
	Check = 94362391665690,
	Chest = 135215673130504,
	Clock = 125758398280702,
	Clover = 92634819079420,
	Coin = 76841235604470,
	CoinBurst = 95671072366500,
	Coins = 115645140899787,
	ColorSet = 95707670427608,
	ConfettiPop = 113359763743196,
	Deed = 98723023995638,
	Dice = 81792745390281,
	Doubles = 79389270348820,
	Embers = 140196580897813,
	Fireworks = 139823500774926,
	Flag = 116193235597572,
	Gavel = 76560338488316,
	Go = 92505662504557,
	GoldDust = 139069714718771,
	GoldenAura = 93139885332353,
	Hotel = 130528374251561,
	House = 88498157097538,
	Jail = 136718365694421,
	Key = 135322177829092,
	Lightning = 119996738514873,
	Lock = 93401617724364,
	LockOpen = 137746355957314,
	Medal = 81053869644396,
	MoneyRain = 108347015141879,
	Mortgage = 140475776901287,
	Podium = 113257367722105,
	Rainbow = 87020524894262,
	Robot = 126423484015965,
	Shadow = 87666043491531,
	SnakeEyes = 76154596604300,
	Snowfall = 102713315570865,
	Star = 75022585765200,
	Starburst = 81679725084223,
	Stardust = 72780495170435,
	Storm = 127859736388718,
	Swap = 78382592128065,
	Swords = 96941539814302,
	Trade = 128315795832686,
	Tree = 119570873821581,
	Trophy = 99101117784759,
}) :: { [string]: number }

function Icons.uri(name: string): string
	local id = Icons.IDS[name]
	return if id then `rbxassetid://{id}` else ""
end

-- An icon image of `size`, transparent behind.
function Icons.image(parent: Instance, name: string, size: UDim2): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = name .. "Icon"
	image.Size = size
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = Icons.uri(name)
	image.Parent = parent
	return image
end

-- A row: an icon then text, side by side (for "[coin] 1,250" and the like). Returns the row and
-- its label.
function Icons.labelled(parent: Instance, name: string, iconSize: number, label: TextLabel): Frame
	local row = Instance.new("Frame")
	row.Name = label.Name .. "Row"
	row.BackgroundTransparency = 1
	row.Size = label.Size
	row.Position = label.Position
	row.AnchorPoint = label.AnchorPoint
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = if label.TextXAlignment == Enum.TextXAlignment.Right
		then Enum.HorizontalAlignment.Right
		elseif label.TextXAlignment == Enum.TextXAlignment.Left then Enum.HorizontalAlignment.Left
		else Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local icon = Icons.image(row, name, UDim2.fromOffset(iconSize, iconSize))
	icon.LayoutOrder = 1
	label.Parent = row
	label.Position = UDim2.new()
	label.AnchorPoint = Vector2.zero
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.TextWrapped = false
	label.LayoutOrder = 2
	return row
end

-- Puts an icon before a Ui.button's text, the pair centred on its face.
function Icons.onButton(button: TextButton, name: string, iconSize: number?)
	local face = button:FindFirstChild("Face") :: Frame
	local label = face:FindFirstChild("Text") :: TextLabel
	local row = Instance.new("Frame")
	row.Name = "IconRow"
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromScale(0, 1)
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.fromScale(0.5, 0)
	row.Parent = face
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local size = iconSize or math.floor(label.TextSize * 1.6)
	Icons.image(row, name, UDim2.fromOffset(size, size)).LayoutOrder = 1
	label.Parent = row
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	label.LayoutOrder = 2
end

return Icons
