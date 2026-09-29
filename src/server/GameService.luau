--!strict
-- Connects players to the game: remotes, lobby, broadcasting state, and pacing bot moves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local GameSession = require(script.Parent.Game.GameSession)
local Snapshot = require(script.Parent.Game.Snapshot)

local GameService = {}

GameService.BOT_DELAY = 0.8
GameService.RESULTS_SECONDS = 15

local session: GameSession.Session? = nil
local updateRemote: RemoteEvent
local random = Random.new()
local botScheduled = false
local endingSession: GameSession.Session? = nil
local scheduleLobbyReturn: () -> ()

local function rollDice(): (number, number)
	return random:NextInteger(1, 6), random:NextInteger(1, 6)
end

local function shuffle(ids: { string })
	for i = #ids, 2, -1 do
		local j = random:NextInteger(1, i)
		ids[i], ids[j] = ids[j], ids[i]
	end
end

local function currentUpdate(events: { any }): Protocol.Update
	return {
		snapshot = if session then Snapshot.fromState(session.state) else nil,
		events = events,
	}
end

local function broadcast()
	local events = if session then GameSession.takeNewEvents(session) else {}
	updateRemote:FireAllClients(currentUpdate(events))
	scheduleLobbyReturn()
end

-- Once a game is over, everyone gets RESULTS_SECONDS on the results screen before the lobby returns.
function scheduleLobbyReturn()
	local ended = session
	if not ended or ended.state.phase ~= "GameOver" or endingSession == ended then
		return
	end
	endingSession = ended
	task.delay(GameService.RESULTS_SECONDS, function()
		if session == ended then
			session = nil
			broadcast()
		end
	end)
end

-- Bots move one action at a time with a pause, so players can follow along.
local function scheduleBots()
	if botScheduled or not session then
		return
	end
	botScheduled = true
	task.delay(GameService.BOT_DELAY, function()
		botScheduled = false
		if session and GameSession.stepBot(session) then
			broadcast()
			scheduleBots()
		end
	end)
end

local function onAction(player: Player, action: any)
	if session and GameSession.act(session, tostring(player.UserId), action) then
		broadcast()
		scheduleBots()
	end
end

local function onLobbyRequest(_player: Player, request: any)
	if typeof(request) ~= "table" then
		return
	end
	if request.type == "ReturnToLobby" then
		if session and session.state.phase == "GameOver" then
			session = nil
			broadcast()
		end
		return
	end
	if session or request.type ~= "Start" or typeof(request.seats) ~= "number" then
		return
	end
	local humans = {}
	for _, player in Players:GetPlayers() do
		table.insert(humans, { id = tostring(player.UserId), name = player.DisplayName })
	end
	local started = GameSession.new(humans, request.seats, rollDice, shuffle)
	-- Playtests: a workspace StartingMoney attribute makes debts and bankruptcies come quickly.
	local startingMoney = workspace:GetAttribute("StartingMoney")
	if RunService:IsStudio() and typeof(startingMoney) == "number" then
		for _, player in started.state.players do
			player.money = startingMoney
		end
	end
	session = started
	broadcast()
	scheduleBots()
end

local function onPlayerRemoving(player: Player)
	if not session then
		return
	end
	GameSession.replaceWithBot(session, tostring(player.UserId))
	if not GameSession.hasHumans(session) then
		session = nil -- everyone left: back to the lobby
	end
	broadcast()
	scheduleBots()
end

function GameService.start()
	local folder = Instance.new("Folder")
	folder.Name = Protocol.REMOTES_FOLDER
	local function makeRemote(name: string): RemoteEvent
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end

	local actionRemote = makeRemote(Protocol.ACTION)
	local lobbyRemote = makeRemote(Protocol.LOBBY)
	local readyRemote = makeRemote(Protocol.READY)
	updateRemote = makeRemote(Protocol.UPDATE)
	folder.Parent = ReplicatedStorage

	actionRemote.OnServerEvent:Connect(onAction)
	lobbyRemote.OnServerEvent:Connect(onLobbyRequest)
	-- A client that just loaded gets the current state (its log starts empty).
	readyRemote.OnServerEvent:Connect(function(player)
		updateRemote:FireClient(player, currentUpdate({}))
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Without characters, streaming needs to be told what each player is looking at.
	local function focusOnBoard(player: Player)
		local board = workspace:FindFirstChild("Board") :: Model?
		player.ReplicationFocus = board and board.PrimaryPart
	end
	Players.PlayerAdded:Connect(focusOnBoard)
	for _, player in Players:GetPlayers() do
		focusOnBoard(player)
	end
end

return GameService
