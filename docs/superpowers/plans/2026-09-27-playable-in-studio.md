# Playable in Studio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Press Play, choose 2–6 seats, click Start, and play the rules-engine game against bots: tokens hop around the board, a HUD shows money and turn, buttons send actions.

**Architecture:** The server owns one `GameSession` (engine state + event cursor + bot stepping). After every accepted action it broadcasts `{ snapshot, events }` over a RemoteEvent; the snapshot is the public state in a network-safe shape (defined in shared `Protocol`). Bots choose actions with a pure `Bot.chooseAction` and are stepped by the server on a short delay. The client is a view: tokens are client-side parts positioned by a shared `TokenLayout`, animated from `Moved` events; the HUD is derived from the snapshot by a pure `HudModel`, and event text by a pure `EventText`. Player avatars are disabled (tokens are the only presence).

**Tech Stack:** Luau, Rojo 7.7, Roblox RemoteEvents/TweenService, in-Studio test runner, Studio MCP for playtests.

**Spec:** Design agreed in conversation on 2026-09-27 (Global Constraints). Milestone 2 of the core game. Builds on `docs/superpowers/plans/2026-09-27-rules-engine-core.md` (Engine API) and the board plan (Layout, BoardCamera).

## Global Constraints

- 2–6 seats; humans present when Start is pressed take seats in join order, bots fill the rest. If more humans than seats, seats grow to the number of humans (max 6); humans beyond 6 spectate. Late joiners spectate.
- Server-authoritative: clients only send action requests; the server passes the *sender's* id to the engine. Clients never change state.
- A human who leaves mid-game is replaced by a bot; if no humans remain, the game ends and the server returns to the lobby.
- No avatars: `Players.CharacterAutoLoads = false`.
- Player ids: humans `tostring(player.UserId)`, bots `bot1`..`bot5`.
- Out of scope: turn timer (milestone 5), jail/cards (3), buildings/mortgage/bankruptcy/win/trading (4), polished visuals (later).
- Every new `.luau` file starts with `--!strict`. Tabs.

## Review Focus

1. **A tampered client sends garbage to the remotes** (non-table lobby request, seats = 0/7/1.5/NaN, actions for another player) — expect it ignored, server unaffected. Lobby validation lives in `GameService`; action validation is the engine's (already tested). `GameSession.new` clamps seats — pinned by GameSession.spec "seats are clamped to 2-6 and never fewer than the humans".
2. **Bots deadlock or get an action rejected** — expect an all-bot game to keep going for hundreds of actions. Pinned by Bot.spec "an all-bot game keeps making legal moves".
3. **A player leaves while it is their turn or their bid** — expect a bot to take over and the game to continue. Pinned by GameSession.spec "a leaving player is replaced by a bot who then acts".
4. **Client joins/loads after the game started** — expect it to receive the current snapshot. Handled by the `ClientReady` remote; checked in the Task 6 playtest.
5. **Several tokens on one tile** — expect them side by side, not stacked. Pinned by TokenLayout.spec "seats on the same tile do not overlap".

## File Structure

```
src/shared/Net/Protocol.luau        (create) remote names + Snapshot type (shared by server and client)
src/shared/Board/TokenLayout.luau   (create) token spot per (tile, seat) + seat colors
src/server/Game/Engine.luau         (modify) add Engine.actingPlayer
src/server/Game/Bot.luau            (create) bot decision function
src/server/Game/Snapshot.luau       (create) GameState -> Protocol.Snapshot
src/server/Game/GameSession.luau    (create) one match: seats, events cursor, bot stepping, leavers
src/server/GameService.luau         (create) remotes, lobby, broadcasting, bot scheduling (Roblox wiring)
src/server/init.server.luau         (modify) disable avatars, start GameService
src/client/BoardCamera.luau         (modify) re-apply on CameraType change instead of CharacterAdded
src/client/Hud/EventText.luau       (create) event -> log line
src/client/Hud/HudModel.luau        (create) snapshot -> status text + buttons
src/client/Hud/HudView.luau         (create) builds/updates the ScreenGui
src/client/Tokens.luau              (create) token parts + hop animation
src/client/GameClient.luau          (create) connects remotes, tokens and HUD
src/client/init.client.luau         (modify) start GameClient
src/tests/Bot.spec.luau, Snapshot.spec.luau, GameSession.spec.luau, TokenLayout.spec.luau,
src/tests/EventText.spec.luau, HudModel.spec.luau                  (create)
src/tests/Engine.spec.luau          (modify) actingPlayer test
```

## How to run the tests

`start_stop_play(true)`, `execute_luau(Server, 'return require(game.ServerStorage.Tests.TestRunner).run()')`, `start_stop_play(false)`. Note: after Task 6 the server starts `GameService` on play; tests don't touch it.

---

### Task 1: Acting player and bots

**Files:**
- Modify: `src/server/Game/Engine.luau`, `src/tests/Engine.spec.luau`
- Create: `src/server/Game/Bot.luau`, `src/tests/Bot.spec.luau`

**Interfaces:**
- Consumes: `Engine.act/currentPlayer/currentBidder/getPlayer/new`, `Tiles.at`, `GameFixtures.newGame/own`.
- Produces:
  - `Engine.actingPlayer(state): string?` — the current bidder during an auction, nil when `GameOver`, otherwise the current player's id.
  - `Bot.CASH_RESERVE = 150`, `Bot.BID_STEP = 10`
  - `Bot.chooseAction(state, botId: string): Action?` — nil when the bot is not the acting player. Roll → `Roll`; BuyDecision → `Buy` if `money - price >= CASH_RESERVE` else `Decline`; Auction → `Bid highBid + BID_STEP` if that is `<= min(price, money - CASH_RESERVE)` else `PassBid`; EndTurn → `EndTurn`.

- [ ] **Step 1: Write the failing tests**

Append to `src/tests/Engine.spec.luau` before `return tests`:

```lua
tests["acting player is the current player, or the bidder during an auction"] = function()
	local state = GameFixtures.newGame(3, { { 2, 4 } })
	Expect.equal(Engine.actingPlayer(state), "p1", "roll phase")
	act(state, "p1", ROLL)
	act(state, "p1", { type = "Decline" })
	act(state, "p1", { type = "PassBid" })
	Expect.equal(Engine.actingPlayer(state), "p2", "auction")
	state.phase = "GameOver"
	Expect.equal(Engine.actingPlayer(state), nil, "game over")
end
```

`src/tests/Bot.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local Bot = require(ServerScriptService.Server.Game.Bot)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

tests["bot rolls on its turn and does nothing on others' turns"] = function()
	local state = GameFixtures.newGame(2)
	Expect.equal(Bot.chooseAction(state, "p1").type, "Roll")
	Expect.equal(Bot.chooseAction(state, "p2"), nil)
end

tests["bot buys when it keeps its cash reserve, otherwise declines"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 }, { 2, 4 } }) -- Oriental Avenue, $100
	act(state, "p1", { type = "Roll" })
	Expect.equal(Bot.chooseAction(state, "p1").type, "Buy", "rich bot")

	state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.getPlayer(state, "p1").money = 200
	act(state, "p1", { type = "Roll" })
	Expect.equal(Bot.chooseAction(state, "p1").type, "Decline", "poor bot")
end

tests["bot bids in steps up to the price and then passes"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	act(state, "p1", { type = "Roll" })
	act(state, "p1", { type = "Decline" })
	local action = Bot.chooseAction(state, "p1")
	Expect.equal(action.type, "Bid")
	Expect.equal(action.amount, 10)
	state.auction.highBid = 95
	Expect.equal(Bot.chooseAction(state, "p1").type, "PassBid", "next bid would exceed price")
	state.auction.highBid = 20
	Engine.getPlayer(state, "p1").money = 170
	Expect.equal(Bot.chooseAction(state, "p1").type, "PassBid", "next bid would break the reserve")
end

tests["bot ends its turn"] = function()
	local state = GameFixtures.newGame(2, { { 3, 4 } })
	act(state, "p1", { type = "Roll" })
	Expect.equal(Bot.chooseAction(state, "p1").type, "EndTurn")
end

tests["an all-bot game keeps making legal moves"] = function()
	local random = Random.new(1234)
	local state = Engine.new({
		{ id = "b1", name = "B1", isBot = true },
		{ id = "b2", name = "B2", isBot = true },
		{ id = "b3", name = "B3", isBot = true },
		{ id = "b4", name = "B4", isBot = true },
	}, function()
		return random:NextInteger(1, 6), random:NextInteger(1, 6)
	end)
	for step = 1, 1000 do
		local actor = assert(Engine.actingPlayer(state), `no acting player at step {step}`)
		local action = assert(Bot.chooseAction(state, actor), `bot {actor} had no action in {state.phase}`)
		local ok, err = Engine.act(state, actor, action)
		assert(ok, `step {step}: {actor} {action.type} rejected: {err}`)
	end
end

return tests
```

- [ ] **Step 2: Run tests to verify they fail**

Run all tests. Expected: `Engine.spec > acting player ...` fails with `attempt to call a nil value` (no `actingPlayer`), and `FAIL Bot.spec (load): ...`.

- [ ] **Step 3: Implement**

In `src/server/Game/Engine.luau`, add after `Engine.currentBidder`:

```lua
-- Whoever the game is waiting on: the bidder during an auction, otherwise the current player.
function Engine.actingPlayer(state: GameState): string?
	if state.phase == "GameOver" then
		return nil
	elseif state.phase == "Auction" then
		return Engine.currentBidder(state)
	end
	return Engine.currentPlayer(state).id
end
```

`src/server/Game/Bot.luau`:

```lua
--!strict
-- A simple bot: buys what it can afford while keeping a cash reserve, and bids up to face value.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Engine = require(script.Parent.Engine)
local Types = require(script.Parent.Types)

local Bot = {}

Bot.CASH_RESERVE = 150
Bot.BID_STEP = 10

function Bot.chooseAction(state: Types.GameState, botId: string): Types.Action?
	if Engine.actingPlayer(state) ~= botId then
		return nil
	end
	local me = Engine.getPlayer(state, botId) :: Types.Player

	if state.phase == "Roll" then
		return { type = "Roll" }
	elseif state.phase == "BuyDecision" then
		local price = Tiles.at(me.position).price :: number
		return if me.money - price >= Bot.CASH_RESERVE then { type = "Buy" } else { type = "Decline" }
	elseif state.phase == "Auction" then
		local auction = state.auction :: Types.Auction
		local limit = math.min(Tiles.at(auction.position).price :: number, me.money - Bot.CASH_RESERVE)
		local nextBid = auction.highBid + Bot.BID_STEP
		return if nextBid <= limit then { type = "Bid", amount = nextBid } else { type = "PassBid" }
	elseif state.phase == "EndTurn" then
		return { type = "EndTurn" }
	end
	return nil
end

return Bot
```

- [ ] **Step 4: Run tests to verify they pass**

Run all tests. Expected: all pass (previous total + 6).

- [ ] **Step 5: Commit**

```bash
git add src/server/Game/Engine.luau src/server/Game/Bot.luau src/tests/Engine.spec.luau src/tests/Bot.spec.luau
git commit -m "feat: acting player and bot decisions"
```

---

### Task 2: Protocol and snapshots

**Files:**
- Create: `src/shared/Net/Protocol.luau`, `src/server/Game/Snapshot.luau`, `src/tests/Snapshot.spec.luau`

**Interfaces:**
- Consumes: `Engine.currentPlayer/currentBidder`, `Types.GameState`.
- Produces:
  - `Protocol.REMOTES_FOLDER = "Remotes"`, `Protocol.ACTION = "GameAction"` (client→server, an engine action table), `Protocol.LOBBY = "LobbyRequest"` (client→server, `{ type = "Start", seats = number }`), `Protocol.UPDATE = "GameUpdate"` (server→client, `Update`), `Protocol.READY = "ClientReady"` (client→server, no args; server replies with an `UPDATE` to that client).
  - Types `Protocol.PlayerView`, `Protocol.PropertyView`, `Protocol.AuctionView`, `Protocol.Snapshot`, `Protocol.Update = { snapshot: Snapshot?, events: { { [string]: any } } }` (nil snapshot = lobby, no game running).
  - `Snapshot.fromState(state: GameState): Protocol.Snapshot` — no shared tables with `state`; properties as an array sorted by position.

- [ ] **Step 1: Write the protocol module**

`src/shared/Net/Protocol.luau`:

```lua
--!strict
-- The contract between server and clients: remote names and the shapes sent over them.

export type PlayerView = {
	id: string,
	name: string,
	isBot: boolean,
	money: number,
	position: number,
	bankrupt: boolean,
	seat: number, -- 1-based turn order; also picks the token spot and color
}

export type PropertyView = {
	position: number,
	owner: string,
	houses: number,
	mortgaged: boolean,
}

export type AuctionView = {
	position: number,
	highBid: number,
	highBidder: string?,
	currentBidder: string?,
}

-- Arrays only (RemoteEvents drop sparse numeric keys).
export type Snapshot = {
	phase: string,
	currentPlayer: string,
	players: { PlayerView },
	properties: { PropertyView },
	auction: AuctionView?,
	lastRoll: { number }?,
}

export type Update = {
	snapshot: Snapshot?, -- nil while no game is running (lobby)
	events: { { [string]: any } },
}

local Protocol = {}

Protocol.REMOTES_FOLDER = "Remotes"
Protocol.ACTION = "GameAction"
Protocol.LOBBY = "LobbyRequest"
Protocol.UPDATE = "GameUpdate"
Protocol.READY = "ClientReady"

return table.freeze(Protocol)
```

- [ ] **Step 2: Write the failing snapshot tests**

`src/tests/Snapshot.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local Snapshot = require(ServerScriptService.Server.Game.Snapshot)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["players keep their seat order and public fields"] = function()
	local state = GameFixtures.newGame(3)
	local snapshot = Snapshot.fromState(state)
	Expect.equal(#snapshot.players, 3)
	for seat, view in snapshot.players do
		Expect.equal(view.id, `p{seat}`, "id")
		Expect.equal(view.seat, seat, "seat")
		Expect.equal(view.money, 1500, "money")
	end
	Expect.equal(snapshot.phase, "Roll")
	Expect.equal(snapshot.currentPlayer, "p1")
	Expect.equal(snapshot.auction, nil)
end

tests["properties become an array sorted by position"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p2", 39)
	GameFixtures.own(state, "p1", 6)
	GameFixtures.own(state, "p1", 12)
	local snapshot = Snapshot.fromState(state)
	Expect.equal(#snapshot.properties, 3)
	Expect.equal(snapshot.properties[1].position, 6)
	Expect.equal(snapshot.properties[2].position, 12)
	Expect.equal(snapshot.properties[3].position, 39)
	Expect.equal(snapshot.properties[3].owner, "p2")
end

tests["auction view names who bids next"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.act(state, "p1", { type = "Roll" })
	Engine.act(state, "p1", { type = "Decline" })
	Engine.act(state, "p1", { type = "Bid", amount = 30 })
	local auction = Snapshot.fromState(state).auction :: any
	Expect.equal(auction.position, 6)
	Expect.equal(auction.highBid, 30)
	Expect.equal(auction.highBidder, "p1")
	Expect.equal(auction.currentBidder, "p2")
end

tests["snapshot shares no tables with the game state"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.act(state, "p1", { type = "Roll" })
	local snapshot = Snapshot.fromState(state)
	snapshot.players[1].money = 0;
	(snapshot.lastRoll :: { number })[1] = 99
	Expect.equal(state.players[1].money, 1500, "player money")
	Expect.equal((state.lastRoll :: { number })[1], 2, "last roll")
end

return tests
```

- [ ] **Step 3: Run tests to verify they fail**

Run `.run("Snapshot")`. Expected: `0 passed, 1 failed` — `FAIL Snapshot.spec (load): ...`.

- [ ] **Step 4: Implement**

`src/server/Game/Snapshot.luau`:

```lua
--!strict
-- The public view of a game, in a shape RemoteEvents can carry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local Engine = require(script.Parent.Engine)
local Types = require(script.Parent.Types)

local Snapshot = {}

function Snapshot.fromState(state: Types.GameState): Protocol.Snapshot
	local players = {}
	for seat, player in state.players do
		table.insert(players, {
			id = player.id,
			name = player.name,
			isBot = player.isBot,
			money = player.money,
			position = player.position,
			bankrupt = player.bankrupt,
			seat = seat,
		})
	end

	local properties = {}
	for position, ownership in state.properties do
		table.insert(properties, {
			position = position,
			owner = ownership.owner,
			houses = ownership.houses,
			mortgaged = ownership.mortgaged,
		})
	end
	table.sort(properties, function(a, b)
		return a.position < b.position
	end)

	local auction: Protocol.AuctionView? = nil
	if state.auction then
		auction = {
			position = state.auction.position,
			highBid = state.auction.highBid,
			highBidder = state.auction.highBidder,
			currentBidder = Engine.currentBidder(state),
		}
	end

	return {
		phase = state.phase,
		currentPlayer = Engine.currentPlayer(state).id,
		players = players,
		properties = properties,
		auction = auction,
		lastRoll = if state.lastRoll then table.clone(state.lastRoll) else nil,
	}
end

return Snapshot
```

- [ ] **Step 5: Run tests to verify they pass**

Run all tests. Expected: all pass (+4).

- [ ] **Step 6: Commit**

```bash
git add src/shared/Net src/server/Game/Snapshot.luau src/tests/Snapshot.spec.luau
git commit -m "feat: network protocol and game snapshots"
```

---

### Task 3: Game sessions

**Files:**
- Create: `src/server/Game/GameSession.luau`, `src/tests/GameSession.spec.luau`

**Interfaces:**
- Consumes: `Engine.new/act/actingPlayer/getPlayer/MIN_PLAYERS/MAX_PLAYERS`, `Bot.chooseAction`, `GameFixtures.scriptedDice`.
- Produces:
  - `type Human = { id: string, name: string }`
  - `type Session = { state: GameState, eventCursor: number }`
  - `GameSession.new(humans: { Human }, seats: number, rollDice: DiceRoller): Session` — seats clamped to `[max(#humans, 2), 6]`; only the first 6 humans play; bots `bot1..` named `Bot 1..` fill the rest.
  - `GameSession.act(session, playerId: string, action: any): (boolean, string?)` — pass-through to `Engine.act`.
  - `GameSession.takeNewEvents(session): { Event }` — events since the previous call.
  - `GameSession.stepBot(session): boolean` — if the acting player is a bot, performs its action; true if it acted.
  - `GameSession.replaceWithBot(session, playerId: string)` — marks the player as a bot (name gets " (bot)"), emits `PlayerReplaced {player}`.
  - `GameSession.hasHumans(session): boolean` — any non-bankrupt, non-bot player.

- [ ] **Step 1: Write the failing tests**

`src/tests/GameSession.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameSession = require(ServerScriptService.Server.Game.GameSession)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local function humans(count: number)
	local list = {}
	for i = 1, count do
		table.insert(list, { id = `h{i}`, name = `Human {i}` })
	end
	return list
end

local function ids(session): string
	local list = {}
	for _, player in session.state.players do
		table.insert(list, player.id)
	end
	return table.concat(list, ",")
end

tests["humans take the first seats and bots fill the rest"] = function()
	local session = GameSession.new(humans(2), 4, GameFixtures.scriptedDice({}))
	Expect.equal(ids(session), "h1,h2,bot1,bot2")
	Expect.equal(session.state.players[3].name, "Bot 1")
	assert(session.state.players[3].isBot and not session.state.players[1].isBot, "isBot flags")
end

tests["seats are clamped to 2-6 and never fewer than the humans"] = function()
	local dice = GameFixtures.scriptedDice({})
	Expect.equal(#GameSession.new(humans(1), 1, dice).state.players, 2, "min 2")
	Expect.equal(#GameSession.new(humans(1), 9, dice).state.players, 6, "max 6")
	Expect.equal(#GameSession.new(humans(3), 2, dice).state.players, 3, "grows to humans")
	Expect.equal(#GameSession.new(humans(8), 4, dice).state.players, 6, "extra humans spectate")
	Expect.equal(#GameSession.new(humans(1), 0 / 0, dice).state.players, 2, "NaN seats")
end

tests["takeNewEvents returns each event once"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({ { 3, 4 } }))
	Expect.equal(#GameSession.takeNewEvents(session), 1, "TurnStarted")
	Expect.equal(#GameSession.takeNewEvents(session), 0, "nothing new")
	assert(GameSession.act(session, "h1", { type = "Roll" }))
	local events = GameSession.takeNewEvents(session)
	Expect.equal(events[1].type, "Rolled")
end

tests["stepBot acts only for bots"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({ { 3, 4 }, { 3, 4 } }))
	assert(not GameSession.stepBot(session), "acted for the human")
	assert(GameSession.act(session, "h1", { type = "Roll" }))
	assert(GameSession.act(session, "h1", { type = "EndTurn" }))
	assert(GameSession.stepBot(session), "bot did not roll")
	Expect.equal(Engine.getPlayer(session.state, "bot1").position, 7)
end

tests["bots play until a human must act"] = function()
	local random = Random.new(42)
	local session = GameSession.new(humans(1), 4, function()
		return random:NextInteger(1, 6), random:NextInteger(1, 6)
	end)
	assert(GameSession.act(session, "h1", { type = "Roll" }))
	-- Whatever h1 landed on, settle it without buying so the bots take over.
	if session.state.phase == "BuyDecision" then
		assert(GameSession.act(session, "h1", { type = "Decline" }))
	end
	local guard = 0
	repeat
		if Engine.actingPlayer(session.state) == "h1" and session.state.phase ~= "Roll" then
			local action = if session.state.phase == "Auction" then { type = "PassBid" } else { type = "EndTurn" }
			assert(GameSession.act(session, "h1", action))
		end
		guard += 1
	until not GameSession.stepBot(session) and Engine.actingPlayer(session.state) == "h1" and session.state.phase == "Roll"
		or guard > 500
	assert(guard <= 500, "bots never handed the turn back")
	Expect.equal(Engine.currentPlayer(session.state).id, "h1")
end

tests["a leaving player is replaced by a bot who then acts"] = function()
	local session = GameSession.new(humans(2), 2, GameFixtures.scriptedDice({ { 3, 4 } }))
	GameSession.replaceWithBot(session, "h1")
	local h1 = Engine.getPlayer(session.state, "h1") :: any
	assert(h1.isBot, "not a bot")
	Expect.equal(h1.name, "Human 1 (bot)")
	Expect.equal(GameFixtures.eventsOfType(session.state, "PlayerReplaced")[1].player, "h1")
	assert(GameSession.hasHumans(session), "h2 is still human")
	assert(GameSession.stepBot(session), "replacement bot did not act")
	GameSession.replaceWithBot(session, "h2")
	assert(not GameSession.hasHumans(session), "no humans left")
end

return tests
```

- [ ] **Step 2: Run tests to verify they fail**

Run `.run("GameSession")`. Expected: `0 passed, 1 failed` — `FAIL GameSession.spec (load): ...`.

- [ ] **Step 3: Implement**

`src/server/Game/GameSession.luau`:

```lua
--!strict
-- One match: the engine state, which events clients have already been sent, and bot turn-taking.

local Bot = require(script.Parent.Bot)
local Engine = require(script.Parent.Engine)
local Types = require(script.Parent.Types)

export type Human = {
	id: string,
	name: string,
}

export type Session = {
	state: Types.GameState,
	eventCursor: number,
}

local GameSession = {}

function GameSession.new(humans: { Human }, seats: number, rollDice: Types.DiceRoller): Session
	local playing = math.min(#humans, Engine.MAX_PLAYERS)
	if seats ~= seats then -- NaN
		seats = Engine.MIN_PLAYERS
	end
	seats = math.clamp(math.floor(seats), math.max(playing, Engine.MIN_PLAYERS), Engine.MAX_PLAYERS)

	local infos = {}
	for i = 1, playing do
		table.insert(infos, { id = humans[i].id, name = humans[i].name, isBot = false })
	end
	local botNumber = 0
	while #infos < seats do
		botNumber += 1
		table.insert(infos, { id = `bot{botNumber}`, name = `Bot {botNumber}`, isBot = true })
	end

	return { state = Engine.new(infos, rollDice), eventCursor = 0 }
end

function GameSession.act(session: Session, playerId: string, action: any): (boolean, string?)
	return Engine.act(session.state, playerId, action)
end

function GameSession.takeNewEvents(session: Session): { Types.Event }
	local events = session.state.events
	local new = table.move(events, session.eventCursor + 1, #events, 1, {})
	session.eventCursor = #events
	return new
end

function GameSession.stepBot(session: Session): boolean
	local actor = Engine.actingPlayer(session.state)
	local player = actor and Engine.getPlayer(session.state, actor)
	if not player or not player.isBot then
		return false
	end
	local action = Bot.chooseAction(session.state, player.id)
	if not action then
		return false
	end
	local ok, err = Engine.act(session.state, player.id, action)
	if not ok then
		warn(`bot {player.id} could not {action.type}: {err}`)
	end
	return ok
end

function GameSession.replaceWithBot(session: Session, playerId: string)
	local player = Engine.getPlayer(session.state, playerId)
	if not player or player.isBot then
		return
	end
	player.isBot = true
	player.name = `{player.name} (bot)`
	table.insert(session.state.events, { type = "PlayerReplaced", player = playerId })
end

function GameSession.hasHumans(session: Session): boolean
	for _, player in session.state.players do
		if not player.isBot and not player.bankrupt then
			return true
		end
	end
	return false
end

return GameSession
```

- [ ] **Step 4: Run tests to verify they pass**

Run all tests. Expected: all pass (+6).

- [ ] **Step 5: Commit**

```bash
git add src/server/Game/GameSession.luau src/tests/GameSession.spec.luau
git commit -m "feat: game sessions with bot seats"
```

---

### Task 4: Token layout

**Files:**
- Create: `src/shared/Board/TokenLayout.luau`, `src/tests/TokenLayout.spec.luau`

**Interfaces:**
- Consumes: `Layout.getTilePlacement`, `Layout.ORIGIN`.
- Produces:
  - `TokenLayout.MAX_SEATS = 6`, `TokenLayout.TOKEN_DIAMETER = 1.4`
  - `TokenLayout.SEAT_COLORS: { Color3 }` (6 entries)
  - `TokenLayout.spot(position: number, seat: number): Vector3` — world point on the tile's top surface where that seat's token stands; errors for seat outside 1–6.

Spots are a 3×2 grid in the tile's outer part (tile-local +Z is the outer edge; the color band occupies the inner 2.5 studs).

- [ ] **Step 1: Write the failing tests**

`src/tests/TokenLayout.spec.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage.Shared.Board.Layout)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local Expect = require(script.Parent.Expect)

local tests = {}

local STRIP_DEPTH = 2.5

tests["every spot is on its tile's top surface, clear of the color band"] = function()
	for position = 0, 39 do
		local placement = Layout.getTilePlacement(position)
		local tileTop = Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2, 0)
		for seat = 1, TokenLayout.MAX_SEATS do
			local localSpot = tileTop:PointToObjectSpace(TokenLayout.spot(position, seat))
			local radius = TokenLayout.TOKEN_DIAMETER / 2
			Expect.near(localSpot.Y, 0, `tile {position} seat {seat} height`)
			assert(math.abs(localSpot.X) + radius <= placement.size.X / 2, `tile {position} seat {seat} off the side`)
			assert(localSpot.Z + radius <= placement.size.Z / 2, `tile {position} seat {seat} off the outer edge`)
			assert(localSpot.Z - radius >= -placement.size.Z / 2 + STRIP_DEPTH, `tile {position} seat {seat} on the band`)
		end
	end
end

tests["seats on the same tile do not overlap"] = function()
	for _, position in { 0, 1, 10, 25 } do
		for a = 1, TokenLayout.MAX_SEATS do
			for b = a + 1, TokenLayout.MAX_SEATS do
				local gap = (TokenLayout.spot(position, a) - TokenLayout.spot(position, b)).Magnitude
				assert(gap >= TokenLayout.TOKEN_DIAMETER, `tile {position}: seats {a} and {b} overlap`)
			end
		end
	end
end

tests["six distinct seat colors"] = function()
	Expect.equal(#TokenLayout.SEAT_COLORS, 6)
	for a = 1, 6 do
		for b = a + 1, 6 do
			assert(TokenLayout.SEAT_COLORS[a] ~= TokenLayout.SEAT_COLORS[b], `colors {a} and {b} match`)
		end
	end
end

tests["rejects invalid seats"] = function()
	for _, bad in { 0, 7, 1.5 } do
		assert(not pcall(TokenLayout.spot, 0, bad), `seat {bad} accepted`)
	end
end

return tests
```

- [ ] **Step 2: Run tests to verify they fail**

Run `.run("TokenLayout")`. Expected: `0 passed, 1 failed` — load failure.

- [ ] **Step 3: Implement**

`src/shared/Board/TokenLayout.luau`:

```lua
--!strict
-- Where each seat's token stands on a tile, and each seat's color.

local Layout = require(script.Parent.Layout)

local TokenLayout = {}

TokenLayout.MAX_SEATS = 6
TokenLayout.TOKEN_DIAMETER = 1.4

TokenLayout.SEAT_COLORS = table.freeze({
	Color3.fromRGB(220, 50, 47), -- red
	Color3.fromRGB(38, 139, 210), -- blue
	Color3.fromRGB(133, 153, 0), -- green
	Color3.fromRGB(181, 137, 0), -- gold
	Color3.fromRGB(108, 113, 196), -- violet
	Color3.fromRGB(42, 161, 152), -- teal
})

-- Tile-local offsets (X along the edge, +Z toward the outer edge), a 3x2 grid clear of the color band.
local SPOTS = {
	Vector3.new(-1.8, 0, 0.6),
	Vector3.new(0, 0, 0.6),
	Vector3.new(1.8, 0, 0.6),
	Vector3.new(-1.8, 0, 2.8),
	Vector3.new(0, 0, 2.8),
	Vector3.new(1.8, 0, 2.8),
}

function TokenLayout.spot(position: number, seat: number): Vector3
	assert(seat % 1 == 0 and seat >= 1 and seat <= TokenLayout.MAX_SEATS, `invalid seat {seat}`)
	local placement = Layout.getTilePlacement(position)
	local tileTop = Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2, 0)
	return tileTop:PointToWorldSpace(SPOTS[seat])
end

return TokenLayout
```

- [ ] **Step 4: Run tests to verify they pass**

Run all tests. Expected: all pass (+4).

- [ ] **Step 5: Commit**

```bash
git add src/shared/Board/TokenLayout.luau src/tests/TokenLayout.spec.luau
git commit -m "feat: token spots and seat colors"
```

---

### Task 5: HUD model and event text

**Files:**
- Create: `src/client/Hud/EventText.luau`, `src/client/Hud/HudModel.luau`
- Create: `src/tests/EventText.spec.luau`, `src/tests/HudModel.spec.luau`

**Interfaces:**
- Consumes: `Tiles.at`, `Protocol.Snapshot` (type), `Snapshot.fromState` + `GameFixtures` (tests only, to build realistic snapshots).
- Produces:
  - `EventText.describe(event: { [string]: any }, names: { [string]: string }): string?` — nil for events not worth a log line (`Moved`, `OfferedPurchase`, `Paid` with reason `Purchase`/`Auction`, unknown).
  - `type Button = { label: string, action: { [string]: any } }`
  - `HudModel.BID_STEPS = { 10, 50, 100 }`
  - `HudModel.buttons(snapshot: Snapshot, localId: string): { Button }` — empty unless the local player is the acting player. Roll → "Roll dice"; BuyDecision → "Buy for $<price>" (only if affordable) + "Don't buy" (`Decline`); Auction → "Bid $<highBid+step>" for each affordable step + "Pass" (`PassBid`); EndTurn → "End turn".
  - `HudModel.status(snapshot: Snapshot, localId: string): string` — "Your turn", "Waiting for <name>", or during an auction "Auction: <tile> — high bid $<n> (<name>)" / "Auction: <tile> — no bids yet".
  - `HudModel.names(snapshot): { [string]: string }` — id → display name.

Modules under `src/client/Hud` are `StarterPlayer.StarterPlayerScripts.Client.Hud.*`; tests require them from there (the server can read StarterPlayerScripts).

- [ ] **Step 1: Write the failing tests**

`src/tests/EventText.spec.luau`:

```lua
--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local EventText = require(StarterPlayer.StarterPlayerScripts.Client.Hud.EventText)
local Expect = require(script.Parent.Expect)

local tests = {}

local NAMES = { p1 = "Ana", p2 = "Bot 1" }

tests["describes the events players care about"] = function()
	local cases = {
		{ { type = "TurnStarted", player = "p1" }, "Ana's turn" },
		{ { type = "Rolled", player = "p1", dice = { 3, 4 } }, "Ana rolled 3 + 4" },
		{ { type = "Paid", from = nil, to = "p1", amount = 200, reason = "Go" }, "Ana collected $200 for passing Go" },
		{ { type = "Paid", from = "p1", to = "p2", amount = 6, reason = "Rent" }, "Ana paid $6 rent to Bot 1" },
		{ { type = "Paid", from = "p1", to = nil, amount = 200, reason = "Tax" }, "Ana paid $200 tax" },
		{ { type = "Bought", player = "p1", position = 6, price = 100 }, "Ana bought Oriental Avenue for $100" },
		{ { type = "AuctionStarted", position = 6, bidders = { "p1", "p2" } }, "Auction for Oriental Avenue" },
		{ { type = "BidPlaced", player = "p2", amount = 30 }, "Bot 1 bid $30" },
		{ { type = "BidPassed", player = "p2" }, "Bot 1 passed" },
		{ { type = "AuctionEnded", position = 6, winner = "p2", amount = 30 }, "Bot 1 won Oriental Avenue for $30" },
		{ { type = "AuctionEnded", position = 6, winner = nil, amount = 0 }, "Nobody bought Oriental Avenue" },
		{ { type = "PlayerReplaced", player = "p1" }, "Ana left; a bot takes over" },
	}
	for _, case in cases do
		Expect.equal(EventText.describe(case[1], NAMES), case[2], case[1].type)
	end
end

tests["skips events that have no log line"] = function()
	for _, event in {
		{ type = "Moved", player = "p1", from = 0, to = 6, passedGo = false },
		{ type = "OfferedPurchase", player = "p1", position = 6 },
		{ type = "Paid", from = "p1", to = nil, amount = 100, reason = "Purchase" },
		{ type = "Paid", from = "p1", to = nil, amount = 30, reason = "Auction" },
		{ type = "Mystery" },
	} do
		Expect.equal(EventText.describe(event, NAMES), nil, event.type)
	end
end

tests["unknown player ids fall back to the id"] = function()
	Expect.equal(EventText.describe({ type = "TurnStarted", player = "ghost" }, NAMES), "ghost's turn")
end

return tests
```

`src/tests/HudModel.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Engine = require(ServerScriptService.Server.Game.Engine)
local Snapshot = require(ServerScriptService.Server.Game.Snapshot)
local HudModel = require(StarterPlayer.StarterPlayerScripts.Client.Hud.HudModel)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local function labels(buttons): string
	local list = {}
	for _, button in buttons do
		table.insert(list, button.label)
	end
	return table.concat(list, "|")
end

tests["no buttons when it is someone else's move"] = function()
	local snapshot = Snapshot.fromState(GameFixtures.newGame(2))
	Expect.equal(#HudModel.buttons(snapshot, "p2"), 0)
	Expect.equal(HudModel.status(snapshot, "p2"), "Waiting for Player 1")
end

tests["roll, buy, and end turn buttons follow the phase"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	local snapshot = Snapshot.fromState(state)
	Expect.equal(labels(HudModel.buttons(snapshot, "p1")), "Roll dice")
	Expect.equal(HudModel.buttons(snapshot, "p1")[1].action.type, "Roll")
	Expect.equal(HudModel.status(snapshot, "p1"), "Your turn")

	Engine.act(state, "p1", { type = "Roll" })
	Expect.equal(labels(HudModel.buttons(Snapshot.fromState(state), "p1")), "Buy for $100|Don't buy")

	Engine.act(state, "p1", { type = "Buy" })
	Expect.equal(labels(HudModel.buttons(Snapshot.fromState(state), "p1")), "End turn")
end

tests["buy is hidden when the player cannot afford it"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.getPlayer(state, "p1").money = 50
	Engine.act(state, "p1", { type = "Roll" })
	Expect.equal(labels(HudModel.buttons(Snapshot.fromState(state), "p1")), "Don't buy")
end

tests["auction offers affordable bid steps and pass to the bidder only"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.act(state, "p1", { type = "Roll" })
	Engine.act(state, "p1", { type = "Decline" })
	Engine.act(state, "p1", { type = "Bid", amount = 20 })
	Engine.getPlayer(state, "p2").money = 80
	local snapshot = Snapshot.fromState(state)
	local buttons = HudModel.buttons(snapshot, "p2")
	Expect.equal(labels(buttons), "Bid $30|Bid $70|Pass")
	Expect.equal(buttons[2].action.amount, 70)
	Expect.equal(#HudModel.buttons(snapshot, "p1"), 0, "p1 is not bidding now")
	Expect.equal(HudModel.status(snapshot, "p1"), "Auction: Oriental Avenue — high bid $20 (Player 1)")
end

tests["names maps ids to display names"] = function()
	local names = HudModel.names(Snapshot.fromState(GameFixtures.newGame(2)))
	Expect.equal(names.p1, "Player 1")
	Expect.equal(names.p2, "Player 2")
end

return tests
```

- [ ] **Step 2: Run tests to verify they fail**

Run all tests. Expected: `FAIL EventText.spec (load)` and `FAIL HudModel.spec (load)`.

- [ ] **Step 3: Implement**

`src/client/Hud/EventText.luau`:

```lua
--!strict
-- One log line per game event worth showing; nil for the rest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

local EventText = {}

function EventText.describe(event: { [string]: any }, names: { [string]: string }): string?
	local function name(id: string?): string
		return if id then names[id] or id else "The bank"
	end
	local function tileName(position: number): string
		return Tiles.at(position).name
	end

	local kind = event.type
	if kind == "TurnStarted" then
		return `{name(event.player)}'s turn`
	elseif kind == "Rolled" then
		return `{name(event.player)} rolled {event.dice[1]} + {event.dice[2]}`
	elseif kind == "Paid" then
		if event.reason == "Go" then
			return `{name(event.to)} collected ${event.amount} for passing Go`
		elseif event.reason == "Rent" then
			return `{name(event.from)} paid ${event.amount} rent to {name(event.to)}`
		elseif event.reason == "Tax" then
			return `{name(event.from)} paid ${event.amount} tax`
		end
		return nil
	elseif kind == "Bought" then
		return `{name(event.player)} bought {tileName(event.position)} for ${event.price}`
	elseif kind == "AuctionStarted" then
		return `Auction for {tileName(event.position)}`
	elseif kind == "BidPlaced" then
		return `{name(event.player)} bid ${event.amount}`
	elseif kind == "BidPassed" then
		return `{name(event.player)} passed`
	elseif kind == "AuctionEnded" then
		if event.winner then
			return `{name(event.winner)} won {tileName(event.position)} for ${event.amount}`
		end
		return `Nobody bought {tileName(event.position)}`
	elseif kind == "PlayerReplaced" then
		return `{name(event.player)} left; a bot takes over`
	end
	return nil
end

return EventText
```

`src/client/Hud/HudModel.luau`:

```lua
--!strict
-- What the HUD should show for a snapshot: a status line and the buttons the local player may press.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

export type Button = {
	label: string,
	action: { [string]: any },
}

local HudModel = {}

HudModel.BID_STEPS = { 10, 50, 100 }

function HudModel.names(snapshot: Protocol.Snapshot): { [string]: string }
	local names = {}
	for _, player in snapshot.players do
		names[player.id] = player.name
	end
	return names
end

local function findPlayer(snapshot: Protocol.Snapshot, id: string): Protocol.PlayerView?
	for _, player in snapshot.players do
		if player.id == id then
			return player
		end
	end
	return nil
end

local function actingPlayer(snapshot: Protocol.Snapshot): string?
	if snapshot.phase == "GameOver" then
		return nil
	elseif snapshot.auction then
		return snapshot.auction.currentBidder
	end
	return snapshot.currentPlayer
end

function HudModel.buttons(snapshot: Protocol.Snapshot, localId: string): { Button }
	local me = findPlayer(snapshot, localId)
	if not me or actingPlayer(snapshot) ~= localId then
		return {}
	end

	local phase = snapshot.phase
	if phase == "Roll" then
		return { { label = "Roll dice", action = { type = "Roll" } } }
	elseif phase == "BuyDecision" then
		local buttons = {}
		local price = Tiles.at(me.position).price :: number
		if me.money >= price then
			table.insert(buttons, { label = `Buy for ${price}`, action = { type = "Buy" } })
		end
		table.insert(buttons, { label = "Don't buy", action = { type = "Decline" } })
		return buttons
	elseif phase == "Auction" and snapshot.auction then
		local buttons = {}
		for _, step in HudModel.BID_STEPS do
			local amount = snapshot.auction.highBid + step
			if amount <= me.money then
				table.insert(buttons, { label = `Bid ${amount}`, action = { type = "Bid", amount = amount } })
			end
		end
		table.insert(buttons, { label = "Pass", action = { type = "PassBid" } })
		return buttons
	elseif phase == "EndTurn" then
		return { { label = "End turn", action = { type = "EndTurn" } } }
	end
	return {}
end

function HudModel.status(snapshot: Protocol.Snapshot, localId: string): string
	local names = HudModel.names(snapshot)
	local auction = snapshot.auction
	if auction then
		local tile = Tiles.at(auction.position).name
		if auction.highBidder then
			return `Auction: {tile} — high bid ${auction.highBid} ({names[auction.highBidder]})`
		end
		return `Auction: {tile} — no bids yet`
	end
	if snapshot.currentPlayer == localId then
		return "Your turn"
	end
	return `Waiting for {names[snapshot.currentPlayer] or snapshot.currentPlayer}`
end

return HudModel
```

- [ ] **Step 4: Run tests to verify they pass**

Run all tests. Expected: all pass (+8).

- [ ] **Step 5: Commit**

```bash
git add src/client/Hud src/tests/EventText.spec.luau src/tests/HudModel.spec.luau
git commit -m "feat: HUD model and event log text"
```

---

### Task 6: Wire it up and play

**Files:**
- Create: `src/server/GameService.luau`, `src/client/Tokens.luau`, `src/client/Hud/HudView.luau`, `src/client/GameClient.luau`
- Modify: `src/server/init.server.luau`, `src/client/init.client.luau`, `src/client/BoardCamera.luau`

**Interfaces:**
- Consumes: everything above; `BoardBuilder.build`; `Protocol`; `TokenLayout`.
- Produces:
  - `GameService.start()`, `GameService.BOT_DELAY = 0.8`
  - `Tokens.new(parent: Instance): TokensView` with `:apply(update: Protocol.Update)`
  - `HudView.new(playerGui: Instance, callbacks: { onAction: (action) -> (), onStart: (seats: number) -> () }): HudView` with `:render(snapshot: Snapshot?, localId: string)` and `:log(lines: { string })`
  - `GameClient.start()`

This task is Roblox wiring with no pure logic left to unit-test; it is verified by the existing suite staying green plus a scripted playtest (Step 8).

- [ ] **Step 1: Server wiring**

`src/server/GameService.luau`:

```lua
--!strict
-- Connects players to the game: remotes, lobby, broadcasting state, and pacing bot moves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local GameSession = require(script.Parent.Game.GameSession)
local Snapshot = require(script.Parent.Game.Snapshot)

local GameService = {}

GameService.BOT_DELAY = 0.8

local session: GameSession.Session? = nil
local updateRemote: RemoteEvent
local random = Random.new()
local botScheduled = false

local function rollDice(): (number, number)
	return random:NextInteger(1, 6), random:NextInteger(1, 6)
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
	if session or typeof(request) ~= "table" or request.type ~= "Start" or typeof(request.seats) ~= "number" then
		return
	end
	local humans = {}
	for _, player in Players:GetPlayers() do
		table.insert(humans, { id = tostring(player.UserId), name = player.DisplayName })
	end
	session = GameSession.new(humans, request.seats, rollDice)
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
end

return GameService
```

Replace `src/server/init.server.luau` with:

```lua
--!strict
local Players = game:GetService("Players")

local BoardBuilder = require(script.BoardBuilder)
local GameService = require(script.GameService)

-- Tokens are the only thing on the board; no avatars.
Players.CharacterAutoLoads = false

BoardBuilder.build(workspace)
GameService.start()
```

- [ ] **Step 2: Camera without characters**

In `src/client/BoardCamera.luau`, replace the end of `BoardCamera.start`:

```lua
	apply()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	-- The default camera scripts reset the camera when a character spawns; re-apply after them.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.defer(apply)
	end)
end
```

with:

```lua
	apply()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	-- If anything (e.g. the default camera scripts) takes the camera over, take it back.
	camera:GetPropertyChangedSignal("CameraType"):Connect(function()
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			task.defer(apply)
		end
	end)
end
```

and remove the now-unused `local Players = game:GetService("Players")` line.

- [ ] **Step 3: Tokens**

`src/client/Tokens.luau`:

```lua
--!strict
-- Client-side token pieces: one per seat, hopping tile to tile when their player moves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)

local HOP_TIME = 0.18
local HOP_HEIGHT = 1.5
local TOKEN_HEIGHT = 0.8

type Token = {
	part: BasePart,
	seat: number,
	position: number, -- board position the token is shown at (or heading to)
	queue: { { from: number, to: number } },
	moving: boolean,
}

local Tokens = {}
Tokens.__index = Tokens

export type TokensView = typeof(setmetatable({} :: { folder: Folder, tokens: { [string]: Token } }, Tokens))

function Tokens.new(parent: Instance): TokensView
	local folder = Instance.new("Folder")
	folder.Name = "Tokens"
	folder.Parent = parent
	return setmetatable({ folder = folder, tokens = {} }, Tokens)
end

local function standingCFrame(position: number, seat: number): CFrame
	-- Cylinders lie along X; rotate so the token stands upright.
	return CFrame.new(TokenLayout.spot(position, seat) + Vector3.new(0, TOKEN_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
end

local function makePart(seat: number, name: string, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(TOKEN_HEIGHT, TokenLayout.TOKEN_DIAMETER, TokenLayout.TOKEN_DIAMETER)
	part.Color = TokenLayout.SEAT_COLORS[seat]
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = true
	part.Parent = parent
	return part
end

local function hop(token: Token, to: number)
	local goal = standingCFrame(to, token.seat)
	local up = TweenService:Create(token.part, TweenInfo.new(HOP_TIME / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = token.part.CFrame:Lerp(goal, 0.5) + Vector3.new(0, HOP_HEIGHT, 0),
	})
	up:Play()
	up.Completed:Wait()
	local down = TweenService:Create(token.part, TweenInfo.new(HOP_TIME / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = goal,
	})
	down:Play()
	down.Completed:Wait()
end

-- Plays queued moves one after another, one hop per tile.
local function runQueue(token: Token)
	if token.moving then
		return
	end
	token.moving = true
	task.spawn(function()
		while #token.queue > 0 do
			local move = table.remove(token.queue, 1) :: { from: number, to: number }
			local steps = (move.to - move.from) % Tiles.COUNT
			for step = 1, steps do
				hop(token, (move.from + step) % Tiles.COUNT)
			end
		end
		token.moving = false
	end)
end

function Tokens.apply(self: TokensView, update: Protocol.Update)
	local snapshot = update.snapshot
	local seen = {}

	if snapshot then
		for _, player in snapshot.players do
			seen[player.id] = true
			local token = self.tokens[player.id]
			if not token then
				local part = makePart(player.seat, player.name, self.folder)
				part.CFrame = standingCFrame(player.position, player.seat)
				token = { part = part, seat = player.seat, position = player.position, queue = {}, moving = false }
				self.tokens[player.id] = token
			end
			token.part.Transparency = if player.bankrupt then 0.7 else 0
		end
	end

	for id, token in self.tokens do
		if not seen[id] then
			token.part:Destroy()
			self.tokens[id] = nil
		end
	end

	for _, event in update.events do
		local token = event.type == "Moved" and self.tokens[event.player]
		if token then
			table.insert(token.queue, { from = event.from, to = event.to })
			token.position = event.to
			runQueue(token)
		end
	end
end

return Tokens
```

- [ ] **Step 4: HUD view**

`src/client/Hud/HudView.luau`:

```lua
--!strict
-- The on-screen HUD: lobby panel, player list, status + action buttons, and event log.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local TokenLayout = require(ReplicatedStorage.Shared.Board.TokenLayout)
local HudModel = require(script.Parent.HudModel)

local LOG_LINES = 8
local FONT = Font.fromEnum(Enum.Font.GothamBold)
local PANEL_COLOR = Color3.fromRGB(25, 27, 32)
local BUTTON_COLOR = Color3.fromRGB(46, 160, 67)
local TEXT_COLOR = Color3.new(1, 1, 1)

export type Callbacks = {
	onAction: (action: { [string]: any }) -> (),
	onStart: (seats: number) -> (),
}

local HudView = {}
HudView.__index = HudView

export type HudView = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		callbacks: Callbacks,
		lobby: Frame,
		seatsLabel: TextLabel,
		seats: number,
		playerList: Frame,
		status: TextLabel,
		buttonRow: Frame,
		logLabel: TextLabel,
		logLines: { string },
	},
	HudView
))

local function corner(parent: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = parent
end

local function panel(name: string, size: UDim2, position: UDim2, anchor: Vector2, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor
	frame.BackgroundColor3 = PANEL_COLOR
	frame.BackgroundTransparency = 0.15
	frame.Parent = parent
	corner(frame)
	return frame
end

local function text(name: string, parent: Instance, size: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextSize = textSize
	label.TextColor3 = TEXT_COLOR
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function button(label: string, parent: Instance, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = label
	b.Size = UDim2.fromOffset(150, 44)
	b.BackgroundColor3 = BUTTON_COLOR
	b.FontFace = FONT
	b.TextSize = 18
	b.TextColor3 = TEXT_COLOR
	b.Text = label
	b.Parent = parent
	corner(b)
	b.Activated:Connect(onClick)
	return b
end

local function list(parent: Instance, direction: Enum.FillDirection, padding: number)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, padding)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
end

function HudView.new(playerGui: Instance, callbacks: Callbacks): HudView
	local gui = Instance.new("ScreenGui")
	gui.Name = "MonopolyHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = playerGui

	-- Lobby: pick seats, start.
	local lobby = panel("Lobby", UDim2.fromOffset(320, 150), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), gui)
	list(lobby, Enum.FillDirection.Vertical, 10)
	local seatsLabel = text("Seats", lobby, UDim2.new(1, 0, 0, 30), 22)
	local seatRow = Instance.new("Frame")
	seatRow.Size = UDim2.new(1, 0, 0, 44)
	seatRow.BackgroundTransparency = 1
	seatRow.Parent = lobby
	list(seatRow, Enum.FillDirection.Horizontal, 10)

	local self = setmetatable({
		gui = gui,
		callbacks = callbacks,
		lobby = lobby,
		seatsLabel = seatsLabel,
		seats = 4,
		playerList = panel("Players", UDim2.fromOffset(230, 0), UDim2.fromOffset(12, 12), Vector2.zero, gui),
		status = nil :: any,
		buttonRow = nil :: any,
		logLabel = nil :: any,
		logLines = {},
	}, HudView)

	local function changeSeats(delta: number)
		self.seats = math.clamp(self.seats + delta, 2, 6)
		self.seatsLabel.Text = `Players: {self.seats} (bots fill empty seats)`
	end
	local minus = button("-", seatRow, function()
		changeSeats(-1)
	end)
	minus.Size = UDim2.fromOffset(44, 44)
	button("Start game", seatRow, function()
		callbacks.onStart(self.seats)
	end)
	local plus = button("+", seatRow, function()
		changeSeats(1)
	end)
	plus.Size = UDim2.fromOffset(44, 44)
	changeSeats(0)

	self.playerList.AutomaticSize = Enum.AutomaticSize.Y
	list(self.playerList, Enum.FillDirection.Vertical, 4)

	-- Bottom bar: status line over action buttons.
	local bar = panel("ActionBar", UDim2.fromOffset(560, 100), UDim2.new(0.5, 0, 1, -12), Vector2.new(0.5, 1), gui)
	list(bar, Enum.FillDirection.Vertical, 6)
	self.status = text("Status", bar, UDim2.new(1, -16, 0, 28), 20)
	local buttonRow = Instance.new("Frame")
	buttonRow.Name = "Buttons"
	buttonRow.Size = UDim2.new(1, 0, 0, 44)
	buttonRow.BackgroundTransparency = 1
	buttonRow.Parent = bar
	list(buttonRow, Enum.FillDirection.Horizontal, 8)
	self.buttonRow = buttonRow

	-- Event log, top right.
	local logPanel = panel("Log", UDim2.fromOffset(300, 200), UDim2.new(1, -12, 0, 12), Vector2.new(1, 0), gui)
	self.logLabel = text("Lines", logPanel, UDim2.new(1, -16, 1, -12), 15)
	self.logLabel.Position = UDim2.fromOffset(8, 6)
	self.logLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.logLabel.TextYAlignment = Enum.TextYAlignment.Bottom

	return self
end

function HudView.log(self: HudView, lines: { string })
	for _, line in lines do
		table.insert(self.logLines, line)
	end
	while #self.logLines > LOG_LINES do
		table.remove(self.logLines, 1)
	end
	self.logLabel.Text = table.concat(self.logLines, "\n")
end

function HudView.render(self: HudView, snapshot: Protocol.Snapshot?, localId: string)
	self.lobby.Visible = snapshot == nil
	self.playerList.Visible = snapshot ~= nil
	self.buttonRow.Parent.Visible = snapshot ~= nil

	for _, child in self.playerList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for _, child in self.buttonRow:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	if not snapshot then
		return
	end

	for _, player in snapshot.players do
		local row = text(player.id, self.playerList, UDim2.new(1, -12, 0, 26), 17)
		row.LayoutOrder = player.seat
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = TokenLayout.SEAT_COLORS[player.seat]
		local marker = if player.id == snapshot.currentPlayer then "▶ " else "   "
		local you = if player.id == localId then " (you)" else ""
		row.Text = `{marker}{player.name}{you}   ${player.money}`
	end

	local roll = snapshot.lastRoll
	local dice = if roll then `   🎲 {roll[1]} + {roll[2]}` else ""
	self.status.Text = HudModel.status(snapshot, localId) .. dice

	for order, entry in HudModel.buttons(snapshot, localId) do
		local b = button(entry.label, self.buttonRow, function()
			self.callbacks.onAction(entry.action)
		end)
		b.LayoutOrder = order
	end
end

return HudView
```

- [ ] **Step 5: Client glue**

`src/client/GameClient.luau`:

```lua
--!strict
-- Receives game updates and drives the tokens and HUD; sends the local player's requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage.Shared.Net.Protocol)
local EventText = require(script.Parent.Hud.EventText)
local HudModel = require(script.Parent.Hud.HudModel)
local HudView = require(script.Parent.Hud.HudView)
local Tokens = require(script.Parent.Tokens)

local GameClient = {}

function GameClient.start()
	local localPlayer = Players.LocalPlayer
	local localId = tostring(localPlayer.UserId)
	local remotes = ReplicatedStorage:WaitForChild(Protocol.REMOTES_FOLDER)
	local actionRemote = remotes:WaitForChild(Protocol.ACTION) :: RemoteEvent
	local lobbyRemote = remotes:WaitForChild(Protocol.LOBBY) :: RemoteEvent
	local updateRemote = remotes:WaitForChild(Protocol.UPDATE) :: RemoteEvent
	local readyRemote = remotes:WaitForChild(Protocol.READY) :: RemoteEvent

	local tokens = Tokens.new(workspace)
	local hud = HudView.new(localPlayer:WaitForChild("PlayerGui"), {
		onAction = function(action)
			actionRemote:FireServer(action)
		end,
		onStart = function(seats)
			lobbyRemote:FireServer({ type = "Start", seats = seats })
		end,
	})

	updateRemote.OnClientEvent:Connect(function(update: Protocol.Update)
		tokens:apply(update)
		if update.snapshot then
			local names = HudModel.names(update.snapshot)
			local lines = {}
			for _, event in update.events do
				local line = EventText.describe(event, names)
				if line then
					table.insert(lines, line)
				end
			end
			hud:log(lines)
		end
		hud:render(update.snapshot, localId)
	end)

	hud:render(nil, localId)
	readyRemote:FireServer()
end

return GameClient
```

Replace `src/client/init.client.luau` with:

```lua
--!strict
local BoardCamera = require(script.BoardCamera)
local GameClient = require(script.GameClient)

BoardCamera.start()
GameClient.start()
```

- [ ] **Step 6: Run the suite**

Run all tests. Expected: all pass (same count as after Task 5).

- [ ] **Step 7: Commit**

```bash
git add src/server src/client
git commit -m "feat: play the game in Studio with bots, tokens and HUD"
```

- [ ] **Step 8: Scripted playtest**

1. `start_stop_play(true)`; `get_console_output` — no errors.
2. `screen_capture` — lobby panel visible over the board, no avatar on the board.
3. Start a 4-seat game from the client: `execute_luau(Client, 'game.ReplicatedStorage.Remotes.LobbyRequest:FireServer({type="Start", seats=4}) task.wait(1) return "ok"')`.
4. `screen_capture` — player list with you + 3 bots, "Roll dice" button, 4 tokens on Go.
5. Roll: `execute_luau(Client, 'game.ReplicatedStorage.Remotes.GameAction:FireServer({type="Roll"}) task.wait(3) return "ok"')`, `screen_capture` — token moved, log shows the roll, buttons match the landing (Buy/Don't buy or End turn).
6. Finish the turn with the matching action(s) (Decline → Pass, or End turn), wait ~15 s, `screen_capture` — bots have taken turns (log lines, tokens moved), it is your turn again.
7. Tamper check: `execute_luau(Client, 'local r = game.ReplicatedStorage.Remotes r.LobbyRequest:FireServer("junk") r.LobbyRequest:FireServer({type="Start", seats=0/0}) r.GameAction:FireServer(nil) r.GameAction:FireServer({type="Bid", amount=math.huge}) task.wait(1) return "ok"')`; `get_console_output` — no server errors.
8. `start_stop_play(false)`.
9. If any step shows a problem, fix it (with a failing test first when the cause is in pure code), re-run the suite and repeat the playtest; commit fixes separately.
