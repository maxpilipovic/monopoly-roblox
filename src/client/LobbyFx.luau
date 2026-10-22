--!strict
-- The lobby's moving parts on this client: the giant die turning over the fountain, the three
-- leaderboards drawn from the server's published scores, the kiosks that open the games browser,
-- and the game tables' chair prompts, hidden while you're already in a game.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyFx = {}

local SPIN_TAG = "LobbySpin"
local BOARD_TAG = "LobbyLeaderboard"
local KIOSK_TAG = "LobbyKiosk"
local TABLE_TAG = "LobbyTable"
local GOLD = Color3.fromRGB(222, 190, 110)
local MEDALS = { Color3.fromRGB(255, 206, 84), Color3.fromRGB(205, 212, 224), Color3.fromRGB(214, 140, 86) }

local function drawBoard(part: BasePart, rows: { { name: string, value: number } })
	local gui = part:FindFirstChild("BoardGui") :: SurfaceGui?
	if not gui then
		local made = Instance.new("SurfaceGui")
		made.Name = "BoardGui"
		made.Face = Enum.NormalId.Front -- the side facing the plaza (boards look at its centre)
		made.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		made.PixelsPerStud = 40
		made.LightInfluence = 0
		made.Parent = part
		gui = made
	end
	local surface = gui :: SurfaceGui
	surface:ClearAllChildren()
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.16, 0)
	title.BackgroundTransparency = 1
	title.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	title.TextScaled = true
	title.TextColor3 = GOLD
	title.Text = tostring(part:GetAttribute("Title") or "")
	title.Parent = surface
	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, -40, 0.8, 0)
	list.Position = UDim2.new(0, 20, 0.18, 0)
	list.BackgroundTransparency = 1
	list.Parent = surface
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.005, 0)
	layout.Parent = list
	if #rows == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0.2, 0)
		empty.BackgroundTransparency = 1
		empty.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
		empty.TextScaled = true
		empty.TextColor3 = Color3.fromRGB(154, 166, 196)
		empty.Text = "Play a game to get on the board!"
		empty.Parent = list
	end
	for index, row in rows do
		local line = Instance.new("Frame")
		line.LayoutOrder = index
		line.Size = UDim2.new(1, 0, 0.095, 0)
		line.BackgroundColor3 = Color3.fromRGB(30, 39, 64)
		line.BackgroundTransparency = if index % 2 == 0 then 0.4 else 0.75
		line.BorderSizePixel = 0
		line.Parent = list
		local rank = Instance.new("TextLabel")
		rank.Size = UDim2.new(0.12, 0, 1, 0)
		rank.BackgroundTransparency = 1
		rank.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		rank.TextScaled = true
		rank.TextColor3 = MEDALS[index] or Color3.fromRGB(154, 166, 196)
		rank.Text = `#{index}`
		rank.Parent = line
		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0.6, 0, 1, 0)
		name.Position = UDim2.new(0.14, 0, 0, 0)
		name.BackgroundTransparency = 1
		name.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = Color3.fromRGB(244, 246, 251)
		name.Text = row.name
		name.Parent = line
		local value = Instance.new("TextLabel")
		value.Size = UDim2.new(0.24, 0, 1, 0)
		value.Position = UDim2.new(0.76, 0, 0, 0)
		value.BackgroundTransparency = 1
		value.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		value.TextScaled = true
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.TextColor3 = GOLD
		value.Text = tostring(math.floor(row.value))
		value.Parent = line
	end
end

local function redrawBoards()
	local raw = ReplicatedStorage:GetAttribute("Leaderboards")
	local ok, boards = pcall(function()
		return if typeof(raw) == "string" then HttpService:JSONDecode(raw) else {}
	end)
	if not ok or typeof(boards) ~= "table" then
		boards = {}
	end
	for _, part in CollectionService:GetTagged(BOARD_TAG) do
		if part:IsA("BasePart") then
			local id = part:GetAttribute("Board")
			drawBoard(part, (boards :: any)[id] or {})
		end
	end
end

local inRoom = false

-- A chair offers itself when the server says it's free ("Open") and you're not in a game already.
local function showChairPrompt(seat: Instance)
	local prompt = seat:FindFirstChild("SitPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = seat:GetAttribute("Open") == true and not inRoom
	end
end

local function chairsOf(model: Instance): { Instance }
	local chairs = model:FindFirstChild("Chairs")
	return if chairs then chairs:GetChildren() else {}
end

local function hookTable(model: Instance)
	for _, seat in chairsOf(model) do
		seat:GetAttributeChangedSignal("Open"):Connect(function()
			showChairPrompt(seat)
		end)
		showChairPrompt(seat)
	end
end

-- In a game (sitting at a table, or hosting from the menu): no other chair offers itself.
function LobbyFx.setInRoom(value: boolean)
	inRoom = value
	for _, model in CollectionService:GetTagged(TABLE_TAG) do
		for _, seat in chairsOf(model) do
			showChairPrompt(seat)
		end
	end
end

function LobbyFx.start(openGames: () -> ())
	-- The die over the fountain turns slowly, tumbling a little.
	RunService.RenderStepped:Connect(function(dt)
		for _, model in CollectionService:GetTagged(SPIN_TAG) do
			if model:IsA("Model") then
				model:PivotTo(model:GetPivot() * CFrame.Angles(dt * 0.25, dt * 0.6, dt * 0.15))
			end
		end
	end)
	redrawBoards()
	ReplicatedStorage:GetAttributeChangedSignal("Leaderboards"):Connect(redrawBoards)
	CollectionService:GetInstanceAddedSignal(BOARD_TAG):Connect(redrawBoards)
	local function hookKiosk(prompt: Instance)
		if prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(openGames)
		end
	end
	for _, prompt in CollectionService:GetTagged(KIOSK_TAG) do
		hookKiosk(prompt)
	end
	CollectionService:GetInstanceAddedSignal(KIOSK_TAG):Connect(hookKiosk)
	for _, model in CollectionService:GetTagged(TABLE_TAG) do
		hookTable(model)
	end
	CollectionService:GetInstanceAddedSignal(TABLE_TAG):Connect(hookTable)
end

return LobbyFx
