--!strict
-- Connects players to the game: remotes, lobby, broadcasting state, and pacing bot moves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local GameSession = require(script.Parent.Game.GameSession)
local Snapshot = require(script.Parent.Game.Snapshot)
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local TurnClock = require(script.Parent.Game.TurnClock)
local Throttle = require(script.Parent.Game.Throttle)

local GameService = {}

GameService.BOT_DELAY = 0.8
GameService.RESULTS_SECONDS = 15
GameService.REFUSAL_SECONDS = 0.25 -- at most this often per player, so spam can't flood them with snapshots
GameService.READY_SECONDS = 1
local refusals = Throttle.new(GameService.REFUSAL_SECONDS)
local readies = Throttle.new(GameService.READY_SECONDS)

local session: GameSession.Session? = nil
local updateRemote: RemoteEvent
local random = Random.new()
local botScheduled = false
local endingSession: GameSession.Session? = nil
local scheduleLobbyReturn: () -> ()
local clock = TurnClock.new()
local clockGeneration = 0 -- bumped on every clock change, so only the latest check can fire
local refreshClock: (actedBy: string?) -> ()

-- Playtests: numeric workspace attributes that only count in Studio.
local function studioNumber(name: string): number?
	local value = workspace:GetAttribute(name)
	return if RunService:IsStudio() and typeof(value) == "number" then value else nil
end

local function timerSeconds(current: GameSession.Session): number
	return studioNumber("TimerSeconds") or MatchSettings.timerSeconds(current.settings)
end

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
	local current = session
	return {
		snapshot = if current
			then Snapshot.fromState(current.state, {
				timer = current.settings.timer,
				length = current.settings.length,
				endsAt = current.endsAt,
				turnDeadline = clock.deadline,
			})
			else nil,
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
			refreshClock(nil)
			broadcast()
			scheduleBots()
		end
	end)
end

-- Starts, keeps or clears the acting human's decision timer. When it runs out, their safe
-- default is played through the session like any other move.
function refreshClock(actedBy: string?)
	clockGeneration += 1
	local current = session
	if not current then
		return
	end
	local now = workspace:GetServerTimeNow()
	TurnClock.update(clock, current.state, timerSeconds(current), now, actedBy)
	local expiresAt, actor = TurnClock.expiresAt(clock), clock.actor
	if not expiresAt or not actor then
		return
	end
	local generation = clockGeneration
	task.delay(math.max(expiresAt - now, 0), function()
		if session ~= current or generation ~= clockGeneration then
			return
		end
		if GameSession.timeout(current, actor) then
			refreshClock(actor)
			broadcast()
			scheduleBots()
		else
			warn(`timeout for {actor} in phase {current.state.phase} did nothing`)
			clock.deadline = nil -- don't leave a dead 0:00 on screen; the next move starts a fresh clock
			broadcast()
		end
	end)
end

local function onAction(player: Player, action: any)
	local playerId = tostring(player.UserId)
	if not session then
		return
	end
	local ok, err = GameSession.act(session, playerId, action)
	if ok then
		refreshClock(playerId)
		broadcast()
		scheduleBots()
	elseif Throttle.allow(refusals, playerId, os.clock()) then
		-- Only the sender hears why, with the current state so their HUD unlocks.
		local update = currentUpdate({})
		update.notice = err or "that isn't allowed now"
		updateRemote:FireClient(player, update)
	end
end

local function onLobbyRequest(player: Player, request: any)
	if typeof(request) ~= "table" then
		return
	end
	if request.type == "ReturnToLobby" then
		-- Only players of the game that ended may cut its results screen short.
		if session and session.state.phase == "GameOver" and GameSession.isPlayer(session, tostring(player.UserId)) then
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
	local settings = MatchSettings.validate(request)
	local started = GameSession.new(humans, request.seats, rollDice, shuffle, settings)
	-- Playtests: a workspace StartingMoney attribute makes debts and bankruptcies come quickly.
	local startingMoney = workspace:GetAttribute("StartingMoney")
	if RunService:IsStudio() and typeof(startingMoney) == "number" then
		for _, player in started.state.players do
			player.money = startingMoney
		end
	end
	local roundLimit = studioNumber("RoundLimit")
	if roundLimit then
		started.state.roundLimit = roundLimit
	end
	local minutes = studioNumber("LimitMinutes") or MatchSettings.limitMinutes(settings)
	if minutes then
		started.endsAt = workspace:GetServerTimeNow() + minutes * 60
		task.delay(minutes * 60, function()
			if session == started then
				GameSession.markTimeUp(started)
				broadcast()
			end
		end)
	end
	session = started
	clock = TurnClock.new()
	refreshClock(nil)
	broadcast()
	scheduleBots()
end

local function onPlayerRemoving(player: Player)
	local playerId = tostring(player.UserId)
	Throttle.forget(refusals, playerId)
	Throttle.forget(readies, playerId)
	if not session then
		return
	end
	GameSession.replaceWithBot(session, playerId)
	-- Everyone left: back to the lobby. A finished game keeps its results screen for whoever is still watching.
	if not GameSession.hasHumans(session) and session.state.phase ~= "GameOver" then
		session = nil
	end
	refreshClock(nil)
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
		if Throttle.allow(readies, tostring(player.UserId), os.clock()) then
			updateRemote:FireClient(player, currentUpdate({}))
		end
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
