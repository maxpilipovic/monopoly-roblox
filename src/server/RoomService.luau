--!strict
-- Runs the games: hosted rooms, casual or ranked (listed, any house rules; ranked ones are rated), the ranked queue (matched
-- by rating, fixed rules, Elo like chess), each game's turn clock, bots and broadcasts to its own
-- players only, results and rating changes at the end, and moving players between the lobby (with
-- their character) and the board (without one).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Cosmetics.Catalog)
local Maps = require(ReplicatedStorage.Shared.Board.Maps)
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local Pacing = require(ReplicatedStorage.Shared.Rules.Pacing)
local Progress = require(ReplicatedStorage.Shared.Progress.Progress)
local Rewards = require(ReplicatedStorage.Shared.Progress.Rewards)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local Ranks = require(ReplicatedStorage.Shared.Rules.Ranks)
local RoomSettings = require(ReplicatedStorage.Shared.Rules.RoomSettings)
local Scenes = require(ReplicatedStorage.Shared.Board.Scenes)
local TalkScope = require(ReplicatedStorage.Shared.Net.TalkScope)
local Elo = require(script.Parent.Data.Elo)
local GameSession = require(script.Parent.Game.GameSession)
local PlayerData = require(script.Parent.Data.PlayerData)
local Placement = require(script.Parent.Game.Placement)
local Profile = require(script.Parent.Data.Profile)
local RankedQueue = require(script.Parent.RankedQueue)
local Rooms = require(script.Parent.Rooms)
local Snapshot = require(script.Parent.Game.Snapshot)
local TableService = require(script.Parent.Lobby.TableService)
local Tables = require(script.Parent.Lobby.Tables)
local Tally = require(script.Parent.Game.Tally)
local Throttle = require(script.Parent.Game.Throttle)
local TurnClock = require(script.Parent.Game.TurnClock)

local RoomService = {}

RoomService.RESULTS_SECONDS = 15
RoomService.RESPAWN_SECONDS = 3
RoomService.MATCH_SECONDS = 2 -- how often the ranked queue looks for matches
local refusals = Throttle.new(0.25) -- at most this often per player, so spam can't flood them
local readies = Throttle.new(1)
local requests = Throttle.new(0.12)

-- A running game and the machinery around it.
type Live = {
	room: Rooms.Room,
	session: GameSession.Session,
	clock: TurnClock.Clock,
	clockGeneration: number,
	botScheduled: boolean,
	ending: boolean, -- the results screen is up
	rated: { [string]: boolean }, -- players whose result is already in their profile
	returned: { [string]: boolean }, -- players who left the results screen for the lobby
	tally: Tally.Tally, -- counts the game toward everyone's challenges
	rolls: { [string]: number }, -- each human's rolls this game (a game barely played pays no coins)
}

local registry = Rooms.new()
local queue = RankedQueue.new()
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

-- The room's players still watching the board (not gone back to the lobby from the results).
local function watchers(l: Live): { Player }
	local list = {}
	for _, player in members(l.room) do
		if not l.returned[tostring(player.UserId)] then
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
	for _, view in list do
		(view :: any).tableId = Tables.tableOf(TableService.seating, view.id)
	end
	TableService.refresh(list)
	for _, player in (if notifyOnly then { notifyOnly } else Players:GetPlayers()) :: { Player } do
		local id = tostring(player.UserId)
		local room = Rooms.roomOf(registry, id)
		local entry = RankedQueue.entryOf(queue, id)
		roomsRemote:FireClient(player, {
			rooms = list,
			mine = if room and not room.matched then room.id else nil,
			hostOf = if room and room.hostId == id and not room.matched then room.id else nil,
			notice = if player == notifyOnly then notice else nil,
			queue = if entry then { mode = entry.mode, since = entry.since } else nil,
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
			scene = l.session.scene,
		}),
		events = events,
	}
end

local LOBBY_UPDATE: Protocol.Update = { snapshot = nil, events = {} }

-- Characters live in the lobby only; a game's players watch the board instead.
local function toLobby(player: Player)
	player.ReplicationFocus = nil
	player:SetAttribute(TalkScope.ATTRIBUTE, nil) -- talks with the lobby again (TableTalk, Talk)
	if player.Parent and not player.Character then
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

local function toBoard(player: Player, roomId: number)
	player:SetAttribute(TalkScope.ATTRIBUTE, roomId) -- chat and voice with this table only
	if player.Character then
		player.Character:Destroy()
	end
	player.Character = nil
	local baseplate = workspace:FindFirstChild("Baseplate")
	player.ReplicationFocus = if baseplate and baseplate:IsA("BasePart") then baseplate else nil
end

-- Everyone at the table as Elo sees them: humans at their rating with their own K, bots as fixed
-- 1000-rated opponents (and a human who left counts as the bot that took their seat).
local function ratingEntries(l: Live): { Elo.Entry }
	local entries = {}
	for _, seat in l.session.state.players do
		local player = if seat.isBot then nil else playerFor(seat.id)
		local profile = player and PlayerData.peek(player)
		if profile then
			table.insert(entries, {
				id = seat.id,
				rating = profile.stats.elo,
				k = Ranks.kFactor(profile.stats.rankedGames, profile.stats.elo),
			})
		else
			table.insert(entries, { id = seat.id, rating = Ranks.START, isBot = true })
		end
	end
	return entries
end

-- Records one player's result. In a ranked game the rating moves by their finishing place (and
-- they're told where they placed and by how much); a casual game only counts as a game played (and won).
-- Coins are paid for a game seen through (never for walking out), and the game counts toward
-- challenges: played, won, and a top-two finish (a 1 v 1 counts only the win).
local function rate(l: Live, player: Player, place: number, delta: number, walkedOut: boolean?)
	local id = tostring(player.UserId)
	if l.rated[id] then
		return
	end
	l.rated[id] = true
	local ranked = l.room.ranked
	local seats = #l.session.state.players
	local elo = 0
	local coins = Rewards.gameCoins(place, seats, ranked, not walkedOut, l.rolls[id] or 0)
	PlayerData.update(player, function(profile)
		Profile.recordGame(profile, place == 1, if ranked then delta else 0, ranked)
		elo = profile.stats.elo
		Progress.add(profile, {
			games = 1,
			wins = if place == 1 then 1 else 0,
			podiums = if place == 1 or (place == 2 and seats >= 3) then 1 else 0,
			rankedWins = if ranked and place == 1 then 1 else 0,
		})
		Progress.addCoins(profile, coins)
	end, "now")
	if player.Parent and not l.returned[id] and (ranked or coins > 0) then
		local parts = { `{Placement.ordinal(place)} of {seats}` }
		if ranked then
			table.insert(parts, `Rating {Ranks.changeText(elo, delta)}`)
		end
		if coins > 0 then
			table.insert(parts, `+{coins} coins`)
		end
		local message = update(l, {})
		message.notice = table.concat(parts, " · ")
		updateRemote:FireClient(player, message)
	end
end

-- Adds what just happened in the game to each human player's lifetime counters.
local function countProgress(l: Live, events: { any })
	local counts = Tally.count(l.tally, events, l.session.state)
	for id, stats in counts do
		local player = playerFor(id)
		if player and Rooms.roomOf(registry, id) == l.room and not l.rated[id] then
			l.rolls[id] = (l.rolls[id] or 0) + (stats.rolls or 0)
			PlayerData.update(player, function(profile)
				Progress.add(profile, stats)
			end, "soon")
		end
	end
end

-- Where `id` places if they walk out now, and the rating change for it: behind everyone still in,
-- ahead of anyone already broke (like going bankrupt this moment).
local function leavingResult(l: Live, id: string): (number, number)
	local seat = nil
	for _, candidate in l.session.state.players do
		if candidate.id == id then
			seat = candidate
		end
	end
	-- Someone already broke keeps the place going broke earned them.
	local places = if seat and seat.bankrupt then Placement.of(l.session.state) else Placement.leaving(l.session.state, id)
	local delta = if l.room.ranked then Elo.changes(ratingEntries(l), places)[id] or 0 else 0
	return places[id] or #l.session.state.players, delta
end

-- Writes everyone's result into their profile once the game is over.
local function recordResults(l: Live)
	local state = l.session.state
	local places = Placement.of(state)
	local changes = Elo.changes(ratingEntries(l), places)
	for _, seat in state.players do
		local player = if seat.isBot then nil else playerFor(seat.id)
		if player then
			rate(l, player, places[seat.id] or #state.players, changes[seat.id] or 0)
		end
	end
end

-- The game is over (or abandoned): its players go back to the lobby. A casual room waits for its
-- next game with the same players; a ranked room was for this one game and closes.
local function closeGame(l: Live)
	if live[l.room.id] ~= l then
		return
	end
	live[l.room.id] = nil
	l.room.status = "Waiting"
	l.room.session = nil
	l.clockGeneration += 1
	local tableId = Tables.tableOf(TableService.seating, l.room.id)
	for _, player in members(l.room) do
		local id = tostring(player.UserId)
		if not l.returned[id] then
			updateRemote:FireClient(player, LOBBY_UPDATE)
			toLobby(player) -- respawns them, and TableService seats them back at the table
		elseif tableId and not l.room.matched then
			-- Went back early from the results: sit down at the table again for the rematch.
			TableService.seat(player, tableId, l.room.settings.maxPlayers)
		end
	end
	if l.room.matched then
		for _, member in table.clone(l.room.members) do
			Rooms.leave(registry, member.id)
		end
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
	countProgress(l, events)
	local pause = Pacing.timeline(events).total
	if refresh then
		refreshClock(l, actedBy, pause)
	end
	local message = update(l, events)
	for _, player in watchers(l) do
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
		RankedQueue.leave(queue, member.id)
		table.insert(humans, { id = member.id, name = member.name })
	end
	local seats = if settings.bots then settings.maxPlayers else #humans
	local rules = RoomSettings.rules(settings)
	local studioMoney = studioNumber("StartingMoney")
	if studioMoney then
		rules.startingMoney = studioMoney
	end
	-- Seats are drawn at random; the turn-order spin shows the draw before the first turn.
	local session = GameSession.new(humans, seats, rollDice, shuffle, RoomSettings.match(settings), rules, {
		shuffleSeats = true,
		announceOrder = true,
	})
	session.scene = if room.matched then Scenes.random(random) else settings.scene
	-- Cosmetics are fixed for the game when it starts.
	for _, seat in session.state.players do
		if seat.isBot then
			session.looks[seat.id] = { piece = Catalog.DEFAULT_PIECES[random:NextInteger(1, #Catalog.DEFAULT_PIECES)] }
		else
			local player = playerFor(seat.id)
			local profile = player and PlayerData.peek(player)
			session.looks[seat.id] = if profile then table.clone(profile.equipped) else { piece = Catalog.DEFAULT_PIECE }
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
		rated = {},
		returned = {},
		tally = Tally.new(),
		rolls = {},
	}
	room.status = "Playing"
	room.session = session
	live[room.id] = l
	local minutes = studioNumber("LimitMinutes") -- Studio playtest aid only: games have no time limit
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
		toBoard(player, room.id)
	end
	sendRooms()
	scheduleBots(l, broadcast(l, true, nil))
end

-- Takes a player out of whatever room they're in. Walking out of a running game is a loss (in a
-- ranked game, rated as losing to the strongest player left, like resigning) and a bot takes their
-- seat. If no solvent human is left the game is abandoned, and the bankrupt humans still watching
-- have their loss recorded too.
local function leaveRoom(player: Player)
	local id = tostring(player.UserId)
	TableService.unseat(player)
	RankedQueue.leave(queue, id)
	local room = Rooms.roomOf(registry, id)
	if not room then
		sendRooms()
		return
	end
	local l = live[room.id]
	if l and not l.ending then
		useMap(l)
		local place, delta = leavingResult(l, id)
		rate(l, player, place, delta, true)
		GameSession.replaceWithBot(l.session, id)
	end
	Rooms.leave(registry, id)
	if l then
		if player.Parent then
			updateRemote:FireClient(player, LOBBY_UPDATE)
			toLobby(player)
		end
		if not GameSession.hasHumans(l.session) then
			if not l.ending then
				for _, other in members(l.room) do
					rate(l, other, leavingResult(l, tostring(other.UserId)))
				end
			end
			closeGame(l)
		elseif not l.ending then
			scheduleBots(l, broadcast(l, true, nil))
		end
	end
	sendRooms()
end

-- Back to the lobby from the results screen, for this player only; the game closes once nobody is
-- left watching (or its results time runs out).
local function returnToLobby(player: Player, l: Live)
	local id = tostring(player.UserId)
	l.returned[id] = true
	updateRemote:FireClient(player, LOBBY_UPDATE)
	toLobby(player)
	if l.room.matched then
		Rooms.leave(registry, id)
	end
	if #watchers(l) == 0 then
		closeGame(l)
	else
		sendRooms()
	end
end

local function queueFor(player: Player, mode: any): (boolean, string?)
	local id = tostring(player.UserId)
	if typeof(mode) ~= "string" or not RankedQueue.SIZES[mode] then
		return false, "pick Duel or Table"
	elseif Rooms.roomOf(registry, id) then
		return false, "leave your casual game first"
	end
	local profile = PlayerData.get(player)
	if not profile or PlayerData.isUnreadable(player) then
		return false, "your rating couldn't be loaded, so ranked is off for now"
	end
	RankedQueue.join(queue, id, profile.stats.elo, mode, workspace:GetServerTimeNow())
	return true, nil
end

-- Starts every ranked game the queue can make. In Studio, the RankedSolo attribute lets a lone
-- player be matched against bots after a few seconds, for testing.
local function matchQueue()
	local now = workspace:GetServerTimeNow()
	local made = false
	for _, match in RankedQueue.match(queue, now) do
		local matched = {}
		for _, id in match.ids do
			local player = playerFor(id)
			if player then
				table.insert(matched, { id = id, name = player.DisplayName })
			end
		end
		if #matched == #match.ids then
			startGame(Rooms.createRanked(registry, matched, RoomSettings.ranked(#matched)))
			made = true
		end
	end
	if RunService:IsStudio() and workspace:GetAttribute("RankedSolo") == true then
		for _, entry in table.clone(queue.entries) do
			local player = playerFor(entry.id)
			if player and now - entry.since > 3 then
				RankedQueue.leave(queue, entry.id)
				local settings = RoomSettings.ranked(RankedQueue.SIZES[entry.mode])
				settings.bots = true
				startGame(Rooms.createRanked(registry, { { id = entry.id, name = player.DisplayName } }, settings))
				made = true
			end
		end
	end
	if made then
		sendRooms()
	end
end

-- Lobby requests, from the client (throttled, below) or from TableService (sitting, standing up).
local function handleLobby(player: Player, request: any)
	local id = tostring(player.UserId)
	local kind = request.type
	local ok, err = true, nil
	local seatAt: { tableId: number, maxPlayers: number }? = nil
	if kind == "QuickPlay" then
		local infos = {}
		for _, view in Rooms.list(registry) do
			table.insert(infos, { id = view.id, ranked = view.ranked, status = view.status, players = view.players, maxPlayers = view.maxPlayers })
		end
		local pick = if Rooms.roomOf(registry, id) then nil else Tables.quickPlay(TableService.seating, infos)
		if pick and pick.join then
			handleLobby(player, { type = "Join", room = pick.join })
		elseif pick and pick.host then
			handleLobby(player, { type = "Create", table = pick.host, ranked = false })
		else
			sendRooms(player, if Rooms.roomOf(registry, id) then "you're already in a game" else "every table is busy right now")
		end
		return
	elseif kind == "Create" or kind == "Join" then
		if RankedQueue.entryOf(queue, id) then
			ok, err = false, "leave the ranked queue first"
		elseif (request.ranked == true or (kind == "Join" and (Rooms.byId(registry, request.room) or {} :: any).ranked)) and PlayerData.isUnreadable(player) then
			ok, err = false, "your rating couldn't be loaded, so ranked is off for now"
		elseif kind == "Create" then
			local room
			room, err = Rooms.create(registry, id, player.DisplayName, request.settings, request.ranked == true)
			if room then
				-- Every hosted game has a table; none free means no game.
				local wanted = if typeof(request.table) == "number" then request.table else nil
				local tableId = Tables.assign(TableService.seating, room.id, room.ranked, wanted)
				if tableId then
					seatAt = { tableId = tableId, maxPlayers = room.settings.maxPlayers }
				else
					Rooms.leave(registry, id)
					room = nil
					err = if request.ranked == true then "all ranked tables are in use" else "all casual tables are in use"
				end
			end
			ok = room ~= nil
		else
			ok, err = Rooms.join(registry, request.room, id, player.DisplayName)
			local room = if ok then Rooms.byId(registry, request.room) else nil
			local tableId = room and Tables.tableOf(TableService.seating, room.id)
			if room and tableId then
				seatAt = { tableId = tableId, maxPlayers = room.settings.maxPlayers }
			end
		end
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
	elseif kind == "Queue" then
		ok, err = queueFor(player, request.mode)
	elseif kind == "Unqueue" then
		RankedQueue.leave(queue, id)
	elseif kind == "ReturnToLobby" then
		local room = Rooms.roomOf(registry, id)
		local l = room and live[room.id]
		if l and l.session.state.phase == "GameOver" then
			returnToLobby(player, l)
		end
		return
	else
		return
	end
	if seatAt then
		local chair = if typeof(request.chair) == "number" then request.chair else nil
		TableService.seat(player, seatAt.tableId, seatAt.maxPlayers, chair)
	end
	if ok then
		sendRooms()
	else
		sendRooms(player, err)
	end
end

local function onLobbyRequest(player: Player, request: any)
	if typeof(request) ~= "table" or not Throttle.allow(requests, tostring(player.UserId), os.clock()) then
		return
	end
	handleLobby(player, request)
end

local function onAction(player: Player, action: any)
	local id = tostring(player.UserId)
	local room = Rooms.roomOf(registry, id)
	local l = room and live[room.id]
	if not l or l.returned[id] then
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
	updateRemote:FireClient(player, if l and not l.returned[id] then update(l, {}) else LOBBY_UPDATE)
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

	-- Sitting at a lobby table hosts or joins its game; standing up leaves it.
	TableService.start({
		request = handleLobby,
		roomOf = function(player: Player)
			local room = Rooms.roomOf(registry, tostring(player.UserId))
			return if room then { id = room.id, status = room.status, maxPlayers = room.settings.maxPlayers } else nil
		end,
	})

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

	task.spawn(function()
		while true do
			task.wait(RoomService.MATCH_SECONDS)
			-- One bad match must not stop matchmaking for the rest of the server's life.
			local ok, err = pcall(matchQueue)
			if not ok then
				warn(`RoomService: matchmaking failed: {err}`)
			end
		end
	end)
end

return RoomService
