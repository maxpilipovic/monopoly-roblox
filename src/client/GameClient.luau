--!strict
-- Receives game updates and plays them out on the tokens and HUD; sends the local player's requests.
-- The server resolves a move at once; here it is shown in order (dice, walk, landing, card) and
-- only then does the HUD show what came of it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local Maps = require(ReplicatedStorage.Shared.Board.Maps)
local Pacing = require(ReplicatedStorage.Shared.Rules.Pacing)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Buildings = require(script.Parent.Buildings)
local EventText = require(script.Parent.Hud.EventText)
local HudModel = require(script.Parent.Hud.HudModel)
local HudView = require(script.Parent.Hud.HudView)
local OwnerMarkers = require(script.Parent.OwnerMarkers)
local Tokens = require(script.Parent.Tokens)

local GameClient = {}

function GameClient.start(hooks: Tokens.TokenHooks?)
	local localPlayer = Players.LocalPlayer
	local localId = tostring(localPlayer.UserId)
	local remotes = ReplicatedStorage:WaitForChild(Protocol.REMOTES_FOLDER)
	local actionRemote = remotes:WaitForChild(Protocol.ACTION) :: RemoteEvent
	local lobbyRemote = remotes:WaitForChild(Protocol.LOBBY) :: RemoteEvent
	local updateRemote = remotes:WaitForChild(Protocol.UPDATE) :: RemoteEvent
	local readyRemote = remotes:WaitForChild(Protocol.READY) :: RemoteEvent

	local tokens = Tokens.new(workspace, hooks)
	local buildings = Buildings.new(workspace)
	local markers = OwnerMarkers.new(workspace)
	local hud = HudView.new(localPlayer:WaitForChild("PlayerGui"), {
		onAction = function(action)
			actionRemote:FireServer(action)
		end,
		onStart = function(seats, settings)
			lobbyRemote:FireServer({ type = "Start", seats = seats, timer = settings.timer, length = settings.length, map = settings.map })
		end,
		onReturnToLobby = function()
			lobbyRemote:FireServer({ type = "ReturnToLobby" })
		end,
	})

	local busyUntil = 0 -- os.clock time the updates already received finish playing
	local generation = 0 -- bumped when the game on screen is dropped, so its pending steps don't run

	-- Runs `step` at `time` (now, if that has passed), unless the lobby has cleared the stage since.
	local function at(time: number, step: () -> ())
		local wait = time - os.clock()
		if wait <= 0 then
			step()
			return
		end
		local scheduledFor = generation
		task.delay(wait, function()
			if generation == scheduledFor then
				step()
			end
		end)
	end

	local function show(snapshot: Protocol.Snapshot?)
		buildings:apply(snapshot)
		markers:apply(snapshot)
		hud:release()
		hud:render(snapshot, localId)
	end

	updateRemote.OnClientEvent:Connect(function(update: Protocol.Update)
		hud:unlock()
		if update.notice then
			hud:notice(update.notice)
		end
		local snapshot = update.snapshot
		if not snapshot then
			-- Back to the lobby: drop whatever was still playing.
			generation += 1
			busyUntil = 0
			tokens:apply(update)
			show(nil)
			return
		end
		Maps.use(snapshot.map) -- names and card text follow the game being shown

		local timeline = Pacing.timeline(update.events)
		local start = math.max(os.clock(), busyUntil) -- after anything still playing
		busyUntil = start + timeline.total
		local names = HudModel.names(snapshot)

		-- Tokens get this update's walks with the wait before each (the dice, a card being read).
		local staged = table.clone(update)
		staged.events = {}
		for _, item in timeline.items do
			local event = item.event
			if event.type == "Moved" then
				event = table.clone(event)
				event.pause = item.pause
			end
			table.insert(staged.events, event)
		end
		at(start, function()
			tokens:apply(staged)
			if timeline.total > 0 then
				hud:hold() -- nothing to click until the move has been seen
			end
		end)

		for _, item in timeline.items do
			local event = item.event
			local line = EventText.describe(event, names)
			local time = start + item.at
			if event.type == "CardDrawn" and Cards.byId[event.card] then
				-- The queue holds the card until its time (and until the card before it is done).
				hud:showCard(event.card, names[event.player] or event.player, time)
			end
			if event.type == "Rolled" or line then
				at(time, function()
					if event.type == "Rolled" then
						hud:rollDice(event.dice)
					end
					if line then
						hud:log({ line }, snapshot.players)
					end
				end)
			end
		end
		for _, jail in timeline.jails do
			-- Everyone is shown a player going to jail, before the token jumps there.
			hud:showJail(names[jail.player] or jail.player, jail.reason, start + jail.at)
		end
		for _, landing in timeline.landings do
			at(start + landing.at, function()
				local who = if landing.player == localId then "You" else names[landing.player] or landing.player
				hud:landed(`{who} landed on {Tiles.at(landing.position).name}`)
			end)
		end

		-- Everything has been seen: show where the game stands now.
		at(busyUntil, function()
			show(snapshot)
		end)
	end)

	-- Studio only: tooling previews a card reveal by setting the HUD's PreviewCard attribute to a card id.
	if RunService:IsStudio() then
		hud.gui:GetAttributeChangedSignal("PreviewCard"):Connect(function()
			local id = hud.gui:GetAttribute("PreviewCard")
			if typeof(id) == "string" then
				hud:showCard(id, localPlayer.Name, os.clock())
			end
		end)
	end

	hud:render(nil, localId)
	readyRemote:FireServer()
end

return GameClient
