--!strict
-- The tag over each player's head in the lobby: their name, and their equipped title in its
-- rarity's colour (titles are challenge rewards, so everyone can see what you've earned). Replaces
-- Roblox's own name tag, and follows equips as they happen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local PlayerData = require(script.Parent.Data.PlayerData)

local Nameplates = {}

local DISPLAY = Font.fromEnum(Enum.Font.FredokaOne)

local function plate(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local profile = PlayerData.peek(player)
	local title = if profile and profile.equipped.title then Catalog.byId[profile.equipped.title] else nil
	local gui = head:FindFirstChild("Nameplate") :: BillboardGui?
	if not gui then
		local new = Instance.new("BillboardGui")
		new.Name = "Nameplate"
		new.Size = UDim2.fromOffset(220, 56)
		new.StudsOffset = Vector3.new(0, 2.4, 0)
		new.MaxDistance = 90
		new.LightInfluence = 0
		new.Parent = head
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.Size = UDim2.new(1, 0, 0, 28)
		name.Position = UDim2.fromOffset(0, 26)
		name.BackgroundTransparency = 1
		name.FontFace = DISPLAY
		name.TextSize = 22
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextStrokeTransparency = 0.4
		name.Parent = new
		local tag = Instance.new("TextLabel")
		tag.Name = "Title"
		tag.Size = UDim2.new(1, 0, 0, 24)
		tag.BackgroundTransparency = 1
		tag.FontFace = DISPLAY
		tag.TextSize = 18
		tag.TextStrokeTransparency = 0.3
		tag.Parent = new
		gui = new
	end
	local billboard = gui :: BillboardGui
	local name = billboard:FindFirstChild("Name") :: TextLabel
	local tag = billboard:FindFirstChild("Title") :: TextLabel
	name.Text = player.DisplayName
	tag.Visible = title ~= nil
	if title then
		tag.Text = `« {title.name} »`
		tag.TextColor3 = Catalog.RARITY_COLORS[title.rarity]
	end
end

function Nameplates.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			plate(player)
		end)
		if player.Character then
			plate(player)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	local shown: { [Player]: string } = {}
	PlayerData.onChanged(function(player, profile)
		local title = profile.equipped.title or ""
		if shown[player] ~= title then
			shown[player] = title
			plate(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		shown[player] = nil
	end)
end

return Nameplates
