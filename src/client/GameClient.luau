--!strict
-- Receives game updates and plays them out on the tokens and HUD; sends the local player's requests.
-- The server resolves a move at once; here it is shown in order (dice, walk, landing, card) and
-- only then does the HUD show what came of it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local DiceThrow = require(ReplicatedStorage.Shared.Dice.DiceThrow)
local Maps = require(ReplicatedStorage.Shared.Board.Maps)
local Pacing = require(ReplicatedStorage.Shared.Rules.Pacing)
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Buildings = require(script.Parent.Buildings)
local DiceView = require(script.Parent.DiceView)
local EventText = require(script.Parent.Hud.EventText)
local GameSounds = require(script.Parent.GameSounds)
local HudModel = require(script.Parent.Hud.HudModel)
local BoardView = require(script.Parent.BoardView)
local CameraDirector = require(script.Parent.CameraDirector)
local HudView = require(script.Parent.Hud.HudView)
local MoneyPops = require(script.Parent.MoneyPops)
local OwnerMarkers = require(script.Parent.OwnerMarkers)
local RentEffects = require(script.Parent.RentEffects)
local Sounds = require(script.Parent.Sounds)
local Tokens = require(script.Parent.Tokens)

local GameClient = {}

-- `onInGame` hears whether this player is at a board (true) or in the lobby (false).
function GameClient.start(hooks: Tokens.TokenHooks?, onInGame: ((boolean) -> ())?)
	local localPlayer = Players.LocalPlayer
	local localId = tostring(localPlayer.UserId)
	local remotes = ReplicatedStorage:WaitForChild(Protocol.REMOTES_FOLDER)
	local actionRemote = remotes:WaitForChild(Protocol.ACTION) :: RemoteEvent
	local lobbyRemote = remotes:WaitForChild(Protocol.LOBBY) :: RemoteEvent
	local updateRemote = remotes:WaitForChild(Protocol.UPDATE) :: RemoteEvent
	local readyRemote = remotes:WaitForChild(Protocol.READY) :: RemoteEvent

	local board = BoardView.new(workspace)
	local tokens = Tokens.new(workspace, hooks)
	local buildings = Buildings.new(workspace)
	local markers = OwnerMarkers.new(workspace)
	local diceView = DiceView.new(workspace)
	local hud = HudView.new(localPlayer:WaitForChild("PlayerGui"), {
		onAction = function(action)
			actionRemote:FireServer(action)
		end,
		onReturnToLobby = function()
			lobbyRemote:FireServer({ type = "ReturnToLobby" })
		end,
		onLeave = function()
			lobbyRemote:FireServer({ type = "Leave" })
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

	local shown: Protocol.Snapshot? = nil -- what the HUD is showing now (for the clock's last-seconds ticks)
	local function show(snapshot: Protocol.Snapshot?)
		shown = snapshot
		if not snapshot or snapshot.phase == "GameOver" then
			diceView:clear() -- nothing left to roll for
		end
		if snapshot then
			board:setPot(snapshot.rules.freeParking, snapshot.freeParkingPot)
		end
		buildings:apply(snapshot)
		markers:apply(snapshot)
		hud:release()
		hud:render(snapshot, localId)
	end

	-- The last five seconds of your own decision tick, once a second.
	local lastTick = -1
	RunService.Heartbeat:Connect(function()
		local snapshot = shown
		local deadline = if snapshot and snapshot.acting == localId then snapshot.match.turnDeadline else nil
		if not deadline then
			lastTick = -1
			return
		end
		local left = math.ceil(deadline - workspace:GetServerTimeNow())
		if left >= 1 and left <= 5 and left ~= lastTick then
			lastTick = left
			Sounds.play("Tick", { pitch = 1 + (5 - left) * 0.05 })
		end
	end)

	updateRemote.OnClientEvent:Connect(function(update: Protocol.Update)
		hud:unlock()
		if update.notice then
			hud:notice(update.notice)
			-- The end-of-game result pays coins; anything else here is a refusal.
			Sounds.play(if update.notice:find("coins", 1, true) then "Claim" else "Error")
		end
		local snapshot = update.snapshot
		if not snapshot then
			-- Back to the lobby: drop whatever was still playing, and the board with it.
			generation += 1
			busyUntil = 0
			tokens:apply(update)
			show(nil)
			board:clear()
			CameraDirector.setActive(false)
			if onInGame then
				onInGame(false)
			end
			return
		end
		if not board:model() then
			board:ensure(snapshot.scene)
			CameraDirector.setActive(true)
			if onInGame then
				onInGame(true)
			end
		end
		Maps.use(snapshot.map) -- names and card text follow the game being shown

		local rentEffects = {}
		for _, player in snapshot.players do
			if player.rentEffect then
				rentEffects[player.id] = player.rentEffect
			end
		end
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

		for index, item in timeline.items do
			local event = item.event
			local line = EventText.describe(event, names)
			local time = start + item.at
			for _, cue in GameSounds.forEvent(event, localId, rentEffects) do
				at(time + (cue.delay or 0), function()
					Sounds.play(cue.name, { volume = cue.volume })
				end)
			end
			if event.type == "CardDrawn" and Cards.byId[event.card] then
				-- The queue holds the card until its time (and until the card before it is done).
				hud:showCard(event.card, names[event.player] or event.player, time)
			end
			if event.type == "TurnOrder" then
				-- The draw for the seats: faces for people, a robot for bots.
				local order = {}
				for _, id in event.order do
					for _, player in snapshot.players do
						if player.id == id then
							table.insert(order, { name = player.name, userId = if player.isBot then nil else tonumber(id) })
						end
					end
				end
				at(time, function()
					hud:showTurnOrder(order)
					-- Meanwhile the camera tours the scene, landing overhead as the first turn begins.
					CameraDirector.playIntro(math.max(Pacing.turnOrderSeconds(#order) - CameraDirector.RETURN_SECONDS, 1))
				end)
			end
			if event.type == "Paid" then
				at(time, function()
					for _, pop in MoneyPops.fromEvent(event) do
						local part = tokens:partFor(pop.player)
						if part then
							MoneyPops.show(part, pop)
						end
					end
					-- The receiver's rent effect plays over whoever paid them.
					if event.reason == "Rent" and event.from and event.to then
						local effect
						for _, player in snapshot.players do
							if player.id == event.to then
								effect = player.rentEffect
							end
						end
						local payer = tokens:partFor(event.from)
						if effect and payer then
							RentEffects.play(effect, payer.Position)
						end
					end
					if MoneyPops.passedGo(event) then
						local board = workspace:FindFirstChild("Board")
						local tiles = board and board:FindFirstChild("Tiles")
						local go = tiles and tiles:FindFirstChild("Tile00")
						if go and go:IsA("BasePart") then
							MoneyPops.flashTile(go)
						end
					end
				end)
			end
			if event.type == "Rolled" or line then
				at(time, function()
					if event.type == "Rolled" then
						if diceView:ready() then
							local players = if snapshot then snapshot.players else {}
							local position = DiceThrow.rollerPosition(update.events, index, players)
							local skin = nil
							for _, player in players do
								if player.id == event.player then
									skin = player.dice
								end
							end
							diceView:roll(event.dice, DiceThrow.side(position), skin)
							hud:showRoll(event.dice)
						else
							hud:rollDice(event.dice) -- no model yet: the 2D dice take the stage
						end
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
		-- ...the Free Parking pot by setting PreviewPot to an amount...
		hud.gui:GetAttributeChangedSignal("PreviewPot"):Connect(function()
			local amount = hud.gui:GetAttribute("PreviewPot")
			if typeof(amount) == "number" then
				board:setPot(true, amount)
			end
		end)
		-- ...and any deed by setting PreviewDeed to a board position.
		hud.gui:GetAttributeChangedSignal("PreviewDeed"):Connect(function()
			local position = hud.gui:GetAttribute("PreviewDeed")
			hud:inspect(if typeof(position) == "number" then position else nil)
		end)
	end

	hud:render(nil, localId)
	readyRemote:FireServer()
end

return GameClient
