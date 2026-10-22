--!strict
-- The lobby's game tables at work: each free chair's prompt hosts a game at an empty table or joins
-- the one waiting there, and sits you down; standing up (jumping) leaves a waiting game. When a
-- game starts its players' avatars go, emptying the chairs, which leaves the room alone; when it
-- ends they come back seated at their table for a rematch. Every rooms change redraws the signs
-- and which chairs can be taken. RoomService owns the rooms and hands this module its request
-- handler (no circular require); `seating` is the one shared record of tables and chairs.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableLayout = require(ReplicatedStorage.Shared.Lobby.TableLayout)
local Tables = require(script.Parent.Tables)

export type RoomState = { id: number, status: string, maxPlayers: number }
export type Handlers = {
	request: (Player, { [string]: any }) -> (),
	roomOf: (Player) -> RoomState?,
}

local TableService = {}

TableService.TABLE_TAG = "LobbyTable" -- LobbyBuilder.TABLE_TAG
TableService.seating = Tables.new()

local GOLD = Color3.fromRGB(214, 172, 84)
local DIM = Color3.fromRGB(200, 208, 224)
local CHARACTER_WAIT_SECONDS = 10

local handlers: Handlers? = nil
local tableModels: { [number]: Model } = {}
local occupants: { [Seat]: Player } = {} -- who the server last sat in each chair
local views: { [number]: any } = {} -- room id -> Rooms.RoomView, from the last refresh

local function chairOf(tableId: number, index: number): Seat?
	local model = tableModels[tableId]
	local chairs = model and model:FindFirstChild("Chairs")
	local seat = chairs and chairs:FindFirstChild(`Chair{index}`)
	return if seat and seat:IsA("Seat") then seat else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Sits the player at `tableId`: in `preferred` if it's free and within the player limit, else the
-- lowest free chair. False when there's no chair or no avatar to sit.
function TableService.seat(player: Player, tableId: number, maxPlayers: number, preferred: number?): boolean
	local s = TableService.seating
	local id = tostring(player.UserId)
	local current, currentChair = Tables.chairOf(s, id)
	if current == tableId and currentChair then
		return true
	end
	local taken = s.chairs[tableId] or {}
	local chair = if preferred and preferred <= math.min(maxPlayers, TableLayout.CHAIRS) and not taken[preferred]
		then preferred
		else Tables.freeChair(s, tableId, maxPlayers)
	local seat = chair and chairOf(tableId, chair)
	local humanoid = humanoidOf(player)
	if not (chair and seat and humanoid) or humanoid.Health <= 0 then
		return false
	end
	Tables.sit(s, tableId, chair, id) -- first, so the old chair emptying isn't read as leaving
	occupants[seat] = player
	seat:Sit(humanoid)
	return true
end

-- Gets the player out of their chair (leaving a game from the panel, or the server).
function TableService.unseat(player: Player)
	local tableId, chair = Tables.stand(TableService.seating, tostring(player.UserId))
	local seat = if tableId and chair then chairOf(tableId, chair) else nil
	if seat then
		occupants[seat] = nil
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.Sit = false
		end
	end
end

local function setChairLook(seat: Seat, usable: boolean)
	local transparency = if usable then 0 else 0.6
	seat.Transparency = transparency
	for _, child in seat:GetChildren() do
		if child:IsA("BasePart") then
			child.Transparency = transparency
		end
	end
end

local function drawTable(tableId: number, model: Model)
	local s = TableService.seating
	local roomId = Tables.roomAt(s, tableId)
	local view = if roomId then views[roomId] else nil
	local ranked = TableLayout.kind(tableId) == "Ranked"
	local status = model:FindFirstChild("Status", true)
	if status and status:IsA("TextLabel") then
		status.Text = if not view
			then "Open · sit down to host"
			elseif view.status == "Playing" then `Playing · {view.players} {if view.players == 1 then "player" else "players"}`
			else `Waiting · {view.hostName} · {view.players}/{view.maxPlayers}`
		status.TextColor3 = if view and view.status == "Waiting" then GOLD else DIM
	end
	local taken = s.chairs[tableId] or {}
	for index = 1, TableLayout.CHAIRS do
		local seat = chairOf(tableId, index)
		local prompt = seat and seat:FindFirstChild("SitPrompt")
		if not (seat and prompt and prompt:IsA("ProximityPrompt")) then
			continue
		end
		local limit = if view then view.maxPlayers else TableLayout.CHAIRS
		local usable = index <= limit
		setChairLook(seat, usable)
		local open = not view or (view.status == "Waiting" and view.players < view.maxPlayers)
		-- "Open" also tells each client, which hides every chair's prompt from people already in a game.
		local free = usable and open and not taken[index]
		seat:SetAttribute("Open", free)
		prompt.Enabled = free
		prompt.ActionText = if view then "Join game" else "Host a game"
		prompt.ObjectText = if ranked then `Ranked table {TableLayout.number(tableId)}` else `Table {tableId}`
	end
end

-- Redraws every table from the rooms as they are now (and frees the tables of closed rooms).
function TableService.refresh(roomViews: { any })
	table.clear(views)
	local live = {}
	for _, view in roomViews do
		views[view.id] = view
		live[view.id] = true
	end
	Tables.sync(TableService.seating, live)
	for tableId, model in tableModels do
		drawTable(tableId, model)
	end
end

local function onPrompt(tableId: number, index: number, player: Player)
	local h = handlers
	if not h then
		return
	end
	local roomId = Tables.roomAt(TableService.seating, tableId)
	if roomId then
		h.request(player, { type = "Join", room = roomId, chair = index })
	else
		h.request(player, { type = "Create", table = tableId, chair = index, ranked = TableLayout.kind(tableId) == "Ranked" })
	end
end

-- A chair emptied: if its sitter stood up by themselves while their game is waiting, they leave it.
local function onEmptied(seat: Seat, tableId: number, index: number)
	local player = occupants[seat]
	occupants[seat] = nil
	if not player then
		return
	end
	local s = TableService.seating
	local sitting, chair = Tables.chairOf(s, tostring(player.UserId))
	if sitting ~= tableId or chair ~= index then
		return -- moved to another chair, or already let go
	end
	Tables.stand(s, tostring(player.UserId))
	local h = handlers
	local room = h and h.roomOf(player)
	if h and room and room.status == "Waiting" then
		h.request(player, { type = "Leave" })
	end
end

local function hookTable(model: Instance)
	-- Only the real lobby's tables (tests build throwaway lobbies elsewhere).
	local lobby = model:FindFirstAncestor("Lobby")
	if not model:IsA("Model") or not lobby or lobby.Parent ~= workspace then
		return
	end
	local tableId = model:GetAttribute("TableId")
	if typeof(tableId) ~= "number" then
		return
	end
	tableModels[tableId] = model
	for index = 1, TableLayout.CHAIRS do
		local seat = chairOf(tableId, index)
		local prompt = seat and seat:FindFirstChild("SitPrompt")
		if not (seat and prompt and prompt:IsA("ProximityPrompt")) then
			continue
		end
		prompt.Triggered:Connect(function(player)
			onPrompt(tableId, index, player)
		end)
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if seat.Occupant == nil then
				onEmptied(seat, tableId, index)
			end
		end)
	end
	drawTable(tableId, model)
end

-- Back in the lobby with a waiting game (a rematch): sit down at its table again.
local function onCharacter(player: Player, character: Model)
	local h = handlers
	if not h then
		return
	end
	if not character:WaitForChild("Humanoid", CHARACTER_WAIT_SECONDS) or not character:WaitForChild("HumanoidRootPart", CHARACTER_WAIT_SECONDS) then
		return
	end
	task.wait() -- let the spawn finish placing the avatar
	local room = h.roomOf(player)
	local tableId = room and Tables.tableOf(TableService.seating, room.id)
	if room and tableId and room.status == "Waiting" and player.Character == character then
		TableService.seat(player, tableId, room.maxPlayers)
	end
end

function TableService.start(given: Handlers)
	handlers = given
	for _, model in CollectionService:GetTagged(TableService.TABLE_TAG) do
		hookTable(model)
	end
	CollectionService:GetInstanceAddedSignal(TableService.TABLE_TAG):Connect(hookTable)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return TableService
