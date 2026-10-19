--!strict
-- Runs the casual games: the room list, each room's game (turn clock, bots, broadcasts to its own
-- members only), results and Elo at the end, and moving players between the lobby (with their
-- character) and the board (without one).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local Maps = require(ReplicatedStorage.Shared.Board.Maps)
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local Pacing = require(ReplicatedStorage.Shared.Rules.Pacing)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local RoomSettings = require(ReplicatedStorage.Shared.Rules.RoomSettings)
local Elo = require(script.Parent.Data.Elo)
local GameSession = require(script.Parent.Game.GameSession)
local PlayerData = require(script.Parent.Data.PlayerData)
local Profile = require(script.Parent.Data.Profile)
local Rooms = require(script.Parent.Rooms)
local Snapshot = require(script.Parent.Game.Snapshot)
local Throttle = require(script.Parent.Game.Throttle)
local TurnClock = require(script.Parent.Game.TurnClock)

local RoomService = {}

RoomService.RESULTS_SECONDS = 15
RoomService.RESPAWN_SECONDS = 3
local refusals = Throttle.new(0.25) -- at most this often per player, so spam can't flood them
local readies = Throttle.new(1)
local requests = Throttle.new(0.2)

-- A running game and the machinery around it.
type Live = {
	room: Rooms.Room,
	session: GameSession.Session,
	clock: TurnClock.Clock,
	clockGeneration: number,
	botScheduled: boolean,
	ending: boolean, -- the results screen is up
	recorded: boolean, -- results written to profiles
}

local registry = Rooms.new()
local live: { [number]: Live } = {}
local updateRemote: RemoteEvent
local roomsRemote: RemoteEvent
local random = Random.new()
local scheduleBots: (Live, number?) -> ()
local refreshClock: (Live, string?, number?) -> ()

local function studioNumber(name: string): number?
	local value = workspace:GetAttribute(name)
	return if RunService:IsStudio() and typeof(value) == "number" then value else nil
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

local function playerFor(id: string): Player?
	local userId = tonumber(id)
	return if userId then Players:GetPlayerByUserId(userId) else nil
end

local function members(room: Rooms.Room): { Player }
	local list = {}
	for _, member in room.members do
		local player = playerFor(member.id)
		if player then
			table.insert(list, player)
		end
	end
	return list
end

-- Card text and tile names follow the map; rooms may be on different maps, so switch to this one
-- before touching its game.
local function useMap(l: Live)
	Maps.use(l.session.settings.map)
end

local function sendRooms(notifyOnly: Player?, notice: string?)
	local list = Rooms.list(registry)
	for _, player in (if notifyOnly then { notifyOnly } else Players:GetPlayers()) :: { Player } do
		local id = tostring(player.UserId)
		local room = Rooms.roomOf(registry, id)
		roomsRemote:FireClient(player, {
			rooms = list,
			mine = if room then room.id else nil,
			hostOf = if room and room.hostId == id then room.id else nil,
			notice = if player == notifyOnly then notice else nil,
		} :: Protocol.RoomsUpdate)
	end
end

local function update(l: Live, events: { any }): Protocol.Update
	useMap(l)
	return {
		snapshot = Snapshot.fromState(l.session.state, {
			timer = l.session.settings.timer,
			length = l.session.settings.length,
			endsAt = l.session.endsAt,
			turnDeadline = l.clock.deadline,
			looks = l.session.looks,
		}),
		events = events,
	}
end

local LOBBY_UPDATE: Protocol.Update = { snapshot = nil, events = {} }

-- Characters live in the lobby only; a game's players watch the board instead.
local function toLobby(player: Player)
	player.ReplicationFocus = nil
	if player.Parent and not player.Character then
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

local function toBoard(player: Player)
	if player.Character then
		player.Character:Destroy()
	end
	player.Character = nil
	local baseplate = workspace:FindFirstChild("Baseplate")
	player.ReplicationFocus = if baseplate and baseplate:IsA("BasePart") then baseplate else nil
end

-- Writes everyone's result into their profile once the game is over.
local function recordResults(l: Live)
	if l.recorded then
		return
	end
	l.recorded = true
	local state = l.session.state
	local entries = {}
	for _, seat in state.players do
		if seat.isBot then
			table.insert(entries, { id = seat.id, rating = Profile.START_ELO, isBot = true })
		else
			local player = playerFor(seat.id)
			local profile = player and PlayerData.peek(player)
			if profile then
				table.insert(entries, { id = seat.id, rating = profile.stats.elo })
			end
		end
	end
	local changes = Elo.changes(entries, state.winner)
	for id, delta in changes do
		local player = playerFor(id)
		if player then
			PlayerData.update(player, function(profile)
				Profile.recordGame(profile, state.winner == id, delta)
			end, true)
		end
	end
end

-- The game is over (or abandoned): the room goes back to waiting and its players to the lobby.
local function closeGame(l: Live)
	if live[l.room.id] ~= l then
		return
	end
	live[l.room.id] = nil
	l.room.status = "Waiting"
	l.room.session = nil
	l.clockGeneration += 1
	for _, player in members(l.room) do
		updateRemote:FireClient(player, LOBBY_UPDATE)
		toLobby(player)
	end
	sendRooms()
end

local function scheduleClose(l: Live)
	if l.ending or l.session.state.phase ~= "GameOver" then
		return
	end
	l.ending = true
	recordResults(l)
	task.delay(RoomService.RESULTS_SECONDS, function()
		closeGame(l)
	end)
end

-- Sends the room's players the state and what just happened; returns the time it takes to watch.
local function broadcast(l: Live, refresh: boolean?, actedBy: string?): number
	local events = GameSession.takeNewEvents(l.session)
	local pause = Pacing.timeline(events).total
	if refresh then
		refreshClock(l, actedBy, pause)
	end
	local message = update(l, events)
	for _, player in members(l.room) do
		updateRemote:FireClient(player, message)
	end
	scheduleClose(l)
	return pause
end

function scheduleBots(l: Live, pause: number?)
	if l.botScheduled or live[l.room.id] ~= l then
		return
	end
	l.botScheduled = true
	task.delay(Pacing.BOT_THINK_SECONDS + (pause or 0), function()
		l.botScheduled = false
		if live[l.room.id] ~= l then
			return
		end
		useMap(l)
		if GameSession.stepBot(l.session) then
			scheduleBots(l, broadcast(l, true, nil))
		end
	end)
end

function refreshClock(l: Live, actedBy: string?, pause: number?)
	l.clockGeneration += 1
	local now = workspace:GetServerTimeNow()
	local seconds = studioNumber("TimerSeconds") or MatchSettings.timerSeconds(l.session.settings)
	TurnClock.update(l.clock, l.session.state, seconds, now + (pause or 0), actedBy)
	local expiresAt, actor = TurnClock.expiresAt(l.clock), l.clock.actor
	if not expiresAt or not actor then
		return
	end
	local generation = l.clockGeneration
	task.delay(math.max(expiresAt - now, 0), function()
		if live[l.room.id] ~= l or generation ~= l.clockGeneration then
			return
		end
		useMap(l)
		if GameSession.timeout(l.session, actor) then
			scheduleBots(l, broadcast(l, true, actor))
		else
			l.clock.deadline = nil
			broadcast(l)
		end
	end)
end

local function startGame(room: Rooms.Room)
	local settings = room.settings
	local humans = {}
	for _, member in room.members do
		table.insert(humans, { id = member.id, name = member.name })
	end
	local seats = if settings.bots then settings.maxPlayers else #humans
	local rules = RoomSettings.rules(settings)
	local studioMoney = studioNumber("StartingMoney")
	if studioMoney then
		rules.startingMoney = studioMoney
	end
	local session = GameSession.new(humans, seats, rollDice, shuffle, RoomSettings.match(settings), rules)
	-- Cosmetics are fixed for the game when it starts.
	for _, seat in session.state.players do
		if seat.isBot then
			session.looks[seat.id] = { piece = Catalog.DEFAULT_PIECES[random:NextInteger(1, #Catalog.DEFAULT_PIECES)] }
		else
			local player = playerFor(seat.id)
			local profile = player and PlayerData.peek(player)
			session.looks[seat.id] = if profile
				then { piece = profile.equipped.piece, rentEffect = profile.equipped.rentEffect }
				else { piece = Catalog.DEFAULT_PIECE }
		end
	end
	local roundLimit = studioNumber("RoundLimit")
	if roundLimit then
		session.state.roundLimit = roundLimit
	end
	local l: Live = {
		room = room,
		session = session,
		clock = TurnClock.new(),
		clockGeneration = 0,
		botScheduled = false,
		ending = false,
		recorded = false,
	}
	room.status = "Playing"
	room.session = session
	live[room.id] = l
	local minutes = studioNumber("LimitMinutes") or MatchSettings.limitMinutes(session.settings)
	if minutes then
		session.endsAt = workspace:GetServerTimeNow() + minutes * 60
		task.delay(minutes * 60, function()
			if live[room.id] == l then
				useMap(l)
				GameSession.markTimeUp(session)
				broadcast(l)
			end
		end)
	end
	for _, player in members(room) do
		toBoard(player)
	end
	sendRooms()
	scheduleBots(l, broadcast(l, true, nil))
end

-- Takes a player out of whatever room they're in. Walking out of a running game counts as a loss
-- (the streak ends; Elo is untouched) and a bot takes over their seat.
local function leaveRoom(player: Player)
	local id = tostring(player.UserId)
	local room = Rooms.roomOf(registry, id)
	if not room then
		return
	end
	local l = live[room.id]
	if l and not l.ending then
		useMap(l)
		GameSession.replaceWithBot(l.session, id)
		PlayerData.update(player, function(profile)
			Profile.recordGame(profile, false, 0)
		end, true)
	end
	Rooms.leave(registry, id)
	if l then
		if player.Parent then
			updateRemote:FireClient(player, LOBBY_UPDATE)
			toLobby(player)
		end
		if not GameSession.hasHumans(l.session) then
			closeGame(l)
		elseif not l.ending then
			scheduleBots(l, broadcast(l, true, nil))
		end
	end
	sendRooms()
end

local function onLobbyRequest(player: Player, request: any)
	local id = tostring(player.UserId)
	if typeof(request) ~= "table" or not Throttle.allow(requests, id, os.clock()) then
		return
	end
	local kind = request.type
	local ok, err = true, nil
	if kind == "Create" then
		local room
		room, err = Rooms.create(registry, id, player.DisplayName, request.settings)
		ok = room ~= nil
	elseif kind == "Join" then
		ok, err = Rooms.join(registry, request.room, id, player.DisplayName)
	elseif kind == "Leave" then
		leaveRoom(player)
		return
	elseif kind == "Settings" then
		ok, err = Rooms.updateSettings(registry, id, request.settings)
	elseif kind == "Start" then
		ok, err = Rooms.canStart(registry, id)
		if ok then
			startGame(Rooms.roomOf(registry, id) :: Rooms.Room)
			return
		end
	elseif kind == "ReturnToLobby" then
		-- Only players of a game that ended may cut its results screen short.
		local room = Rooms.roomOf(registry, id)
		local l = room and live[room.id]
		if l and l.session.state.phase == "GameOver" then
			closeGame(l)
		end
		return
	else
		return
	end
	if ok then
		sendRooms()
	else
		sendRooms(player, err)
	end
end

local function onAction(player: Player, action: any)
	local id = tostring(player.UserId)
	local room = Rooms.roomOf(registry, id)
	local l = room and live[room.id]
	if not l then
		return
	end
	useMap(l)
	local ok, err = GameSession.act(l.session, id, action)
	if ok then
		scheduleBots(l, broadcast(l, true, id))
	elseif Throttle.allow(refusals, id, os.clock()) then
		local message = update(l, {})
		message.notice = err or "that isn't allowed now"
		updateRemote:FireClient(player, message)
	end
end

local function onReady(player: Player)
	local id = tostring(player.UserId)
	if not Throttle.allow(readies, id, os.clock()) then
		return
	end
	local room = Rooms.roomOf(registry, id)
	local l = room and live[room.id]
	updateRemote:FireClient(player, if l then update(l, {}) else LOBBY_UPDATE)
	sendRooms(player)
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			task.delay(RoomService.RESPAWN_SECONDS, function()
				local room = Rooms.roomOf(registry, tostring(player.UserId))
				if player.Parent and player.Character == character and not (room and live[room.id]) then
					player:LoadCharacter()
				end
			end)
		end)
	end
end

function RoomService.start()
	-- Characters are spawned by hand: in the lobby yes, at the board no.
	Players.CharacterAutoLoads = false

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
	roomsRemote = makeRemote(Protocol.ROOMS)
	folder.Parent = ReplicatedStorage

	actionRemote.OnServerEvent:Connect(onAction)
	lobbyRemote.OnServerEvent:Connect(onLobbyRequest)
	readyRemote.OnServerEvent:Connect(onReady)

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		toLobby(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		leaveRoom(player)
		local id = tostring(player.UserId)
		Throttle.forget(refusals, id)
		Throttle.forget(readies, id)
		Throttle.forget(requests, id)
	end)
end

return RoomService
