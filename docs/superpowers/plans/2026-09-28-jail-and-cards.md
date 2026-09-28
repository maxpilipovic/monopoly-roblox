# Jail, Doubles and Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Official jail rules (Go To Jail tile, three doubles, doubles/fine/card to get out, forced fine on the third failed roll) and the 16+16 Chance and Community Chest cards, playable in Studio with bots, tokens and HUD.

**Architecture:** The engine gains jail state per player (`inJail`, `jailAttempts`, `jailCards`), a per-turn doubles counter, a `rollAgain` flag that replaces "last roll was doubles", and two decks of card ids in `GameState`. Card definitions (text + effect data) live in a shared `Cards` module so the client can show card text from a `CardDrawn` event. Every move goes through one `moveTo(state, player, to, style)` that emits `Moved` with a `style` (`"Walk"`, `"Back"`, `"ToJail"`) so tokens can hop forward, hop backward, or jump into the jail cell. Card effects that move the player re-enter `resolveLanding`, so chains (Go Back 3 → Community Chest → another card) resolve naturally.

**Tech Stack:** Luau (`--!strict`), Rojo 7.7, in-Studio test runner, Studio MCP for playtests.

**Spec:** Design agreed 2026-09-27 (official Monopoly rules, no Free Parking jackpot). Milestone 3 of the roadmap. Builds on `docs/superpowers/plans/2026-09-27-rules-engine-core.md` (Engine API) and `2026-09-27-playable-in-studio.md` (Snapshot, HUD, Tokens). Closes the playable-in-studio follow-up "Backward/direct moves need a Moved kind".

## Global Constraints

- Official rules. Go To Jail (tile, card, or third doubles in one turn): token goes straight to Jail, no $200, turn ends even after doubles.
- In jail, on your turn, before rolling: pay $50 (only if you have it), or use a Get Out of Jail Free card, then roll and move normally (doubles after that earn another roll). Or roll: doubles → leave and move by that roll, **no** extra roll; otherwise stay. On the third failed roll you must pay $50 (even into debt) and move by that roll.
- Landing on Jail from a roll is "just visiting": nothing happens.
- Card decks: drawn from the top, returned to the bottom. A Get Out of Jail Free card stays with the player and goes back to the bottom of *its own* deck when used.
- "Nearest Railroad" card: if owned, pay twice the normal rent. "Nearest Utility" card: if owned, roll the dice again and pay ten times that roll (the new roll does not change `lastRoll` or doubles). If unowned, the normal buy/auction flow applies.
- Players can go into negative money (bankruptcy is milestone 4) — same as rent today.
- Card and tile names are the classic ones for now; IP-safe renaming happens before publishing (later milestone).
- Out of scope: houses/mortgages/bankruptcy/trading (4), turn timer (5), a modelled jail cell on the board (polish).
- Every new `.luau` file starts with `--!strict`. Tabs.

## Review Focus

1. **Card chains** — Go Back 3 from Chance (36) lands on Community Chest (33) and must draw and apply a second card exactly once. Pinned by CardEffects.spec "go back 3 hops backward and resolves the new tile, even another card".
2. **Doubles then jail** — rolling doubles onto Go To Jail, or onto a Chance that says Go to Jail, must end the turn (no extra roll). Pinned by Jail.spec "landing on Go To Jail…" (rolls 3+3) and CardEffects.spec "the go to jail card ends the turn even after doubles".
3. **Jailed with less than $50** — the Pay button is hidden, the engine refuses a voluntary payment, and the third failed roll still charges $50 into debt. Pinned by Jail.spec "can't pay the fine without $50", "the third failed roll forces the fine and moves you", HudModel.spec "jail buttons follow what the player can do".
4. **Bots stall in jail or on card-driven decisions** — an all-bot game with shuffled decks must keep making legal moves and actually visit jail and draw cards. Pinned by Bot.spec "an all-bot game keeps making legal moves" (extended in Task 3).
5. **Held Get Out of Jail Free cards** — the deck shrinks while held and the card returns to its own deck when used. Pinned by CardEffects.spec "a Get Out of Jail Free card is kept, then used and returned to its deck".

## File Structure

```
src/shared/Board/Cards.luau          (create) Chance/Community Chest card data: id, deck, text, effect
src/shared/Board/TokenLayout.luau    (modify) jailSpot(seat): spots inside the jail cell
src/server/Game/Types.luau           (modify) jail fields, doubles counter, rollAgain, decks, Shuffler
src/server/Game/Engine.luau          (modify) moveTo/styles, jail, doubles, cards, PayJailFine/UseJailCard
src/server/Game/Bot.luau             (modify) jail decisions
src/server/Game/Snapshot.luau        (modify) inJail + jailCards per player
src/server/Game/GameSession.luau     (modify) pass a deck shuffler to the engine
src/server/GameService.luau          (modify) real shuffler
src/shared/Net/Protocol.luau         (modify) PlayerView.inJail / jailCards
src/client/Hud/HudModel.luau         (modify) jail buttons + status
src/client/Hud/EventText.luau        (modify) jail/card log lines
src/client/Hud/HudView.luau          (modify) jail marker in player list, card popup
src/client/Tokens.luau               (modify) Tokens.path (Walk/Back/ToJail), jail spot
src/client/GameClient.luau           (modify) show drawn cards
src/tests/GameFixtures.luau          (modify) new state fields, stackDeck
src/tests/Jail.spec.luau             (create)
src/tests/Cards.spec.luau            (create) card data
src/tests/CardEffects.spec.luau      (create) card effects in the engine
src/tests/Engine.spec.luau, Bot.spec.luau, Snapshot.spec.luau, HudModel.spec.luau,
src/tests/EventText.spec.luau, Tokens.spec.luau, TokenLayout.spec.luau   (modify)
```

No `default.project.json` changes (all new files live in already-synced folders), so Rojo needs no restart.

## How to run the tests

Studio MCP: `start_stop_play(true)`, `execute_luau(Server, 'return require(game.ServerStorage.Tests.TestRunner).run()')`, `start_stop_play(false)`. Pass a filter to run one spec: `.run("Jail")`. Baseline before Task 1: 87 passed, 0 failed.

---

### Task 1: Jail and doubles in the engine

**Files:**
- Modify: `src/server/Game/Types.luau`, `src/server/Game/Engine.luau`, `src/tests/GameFixtures.luau`, `src/tests/Engine.spec.luau`
- Create: `src/tests/Jail.spec.luau`

**Interfaces:**
- Consumes: existing `Engine.act/new/getPlayer/currentPlayer`, `GameFixtures.newGame/own/eventsOfType`.
- Produces:
  - `Engine.JAIL_POSITION = 10`, `Engine.JAIL_FINE = 50`, `Engine.JAIL_MAX_ATTEMPTS = 3`, `Engine.MAX_DOUBLES = 3`
  - `Player.inJail: boolean`, `Player.jailAttempts: number` (failed doubles rolls this stay)
  - `GameState.doublesCount: number` (doubles rolled this turn), `GameState.rollAgain: boolean` (the current move earned another roll)
  - Action `{ type = "PayJailFine" }` (Roll phase, in jail, money ≥ 50)
  - Events: `Moved` gains `style: "Walk" | "Back" | "ToJail"`; `SentToJail { player, reason = "GoToJail" | "Doubles" | "Card" }`; `LeftJail { player, reason = "Doubles" | "Fine" | "Card" }`; `Paid` reason `"JailFine"`.
  - Internal (used by Task 2): `moveTo(state, player, to, style)`, `sendToJail(state, player, reason)`, `leaveJail(state, player, reason)`, `finishMove(state)`, `resolveLanding(state, player)`.

- [ ] **Step 1: Write the failing tests**

Create `src/tests/Jail.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local ROLL = { type = "Roll" }
local END_TURN = { type = "EndTurn" }
local PAY_FINE = { type = "PayJailFine" }

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function player(state, id: string): any
	return Engine.getPlayer(state, id) :: any
end

-- A 2-player game where p1 starts their turn in jail.
local function jailed(rolls: { { number } })
	local state = GameFixtures.newGame(2, rolls)
	local p1 = player(state, "p1")
	p1.position = Engine.JAIL_POSITION
	p1.inJail = true
	return state
end

tests["landing on Go To Jail sends you to jail without passing Go and ends the turn"] = function()
	local state = GameFixtures.newGame(2, { { 3, 3 } })
	player(state, "p1").position = 24 -- 24 + 6 = 30, Go To Jail
	act(state, "p1", ROLL)
	local p1 = player(state, "p1")
	Expect.equal(p1.position, 10, "position")
	assert(p1.inJail, "not in jail")
	Expect.equal(p1.money, 1500, "no Go salary")
	Expect.equal(state.phase, "EndTurn", "doubles give no extra roll")
	local moves = GameFixtures.eventsOfType(state, "Moved")
	Expect.equal(moves[1].style, "Walk", "dice move style")
	Expect.equal(moves[2].style, "ToJail", "jail move style")
	Expect.equal(moves[2].from, 30, "jail move from")
	Expect.equal(moves[2].passedGo, false, "jail move passedGo")
	Expect.equal(GameFixtures.eventsOfType(state, "SentToJail")[1].reason, "GoToJail")
end

tests["landing on Jail from a roll is just visiting"] = function()
	local state = GameFixtures.newGame(2, { { 3, 4 } })
	player(state, "p1").position = 3
	act(state, "p1", ROLL)
	Expect.equal(player(state, "p1").position, 10)
	assert(not player(state, "p1").inJail, "jailed while visiting")
	Expect.equal(state.phase, "EndTurn")
end

tests["three doubles in one turn send you to jail without moving the third time"] = function()
	local state = GameFixtures.newGame(2, { { 3, 3 }, { 1, 1 }, { 2, 2 } })
	GameFixtures.own(state, "p1", 6)
	GameFixtures.own(state, "p1", 8)
	act(state, "p1", ROLL) -- 6
	act(state, "p1", ROLL) -- 8
	act(state, "p1", ROLL) -- third doubles: jail instead of 12
	local p1 = player(state, "p1")
	Expect.equal(p1.position, 10, "position")
	assert(p1.inJail, "not in jail")
	Expect.equal(state.phase, "EndTurn")
	local moves = GameFixtures.eventsOfType(state, "Moved")
	Expect.equal(#moves, 3, "two walks and the jail move")
	Expect.equal(moves[3].from, 8, "jailed from where they stood")
	Expect.equal(GameFixtures.eventsOfType(state, "SentToJail")[1].reason, "Doubles")
end

tests["the doubles count starts over each turn"] = function()
	local state = GameFixtures.newGame(2, { { 3, 3 }, { 1, 1 }, { 1, 2 }, { 1, 2 }, { 2, 2 } })
	for _, position in { 3, 6, 8, 11, 15 } do
		GameFixtures.own(state, "p1", position)
	end
	act(state, "p1", ROLL) -- 6, doubles
	act(state, "p1", ROLL) -- 8, doubles
	act(state, "p1", ROLL) -- 11
	act(state, "p1", END_TURN)
	act(state, "p2", ROLL) -- 3, pays rent
	act(state, "p2", END_TURN)
	act(state, "p1", ROLL) -- 15, doubles: only the first this turn
	assert(not player(state, "p1").inJail, "jailed for doubles from an earlier turn")
	Expect.equal(state.phase, "Roll")
end

tests["rolling doubles in jail frees you and moves you, with no extra roll"] = function()
	local state = jailed({ { 3, 3 } })
	GameFixtures.own(state, "p1", 16)
	act(state, "p1", ROLL)
	local p1 = player(state, "p1")
	assert(not p1.inJail, "still in jail")
	Expect.equal(p1.position, 16, "moved by the roll")
	Expect.equal(state.phase, "EndTurn", "no extra roll")
	Expect.equal(GameFixtures.eventsOfType(state, "LeftJail")[1].reason, "Doubles")
end

tests["a failed roll keeps you in jail and ends the turn"] = function()
	local state = jailed({ { 1, 2 } })
	act(state, "p1", ROLL)
	local p1 = player(state, "p1")
	assert(p1.inJail, "left jail without doubles")
	Expect.equal(p1.position, 10, "did not move")
	Expect.equal(p1.jailAttempts, 1, "attempts")
	Expect.equal(state.phase, "EndTurn")
	Expect.equal(#GameFixtures.eventsOfType(state, "Moved"), 0, "no move")
end

tests["the third failed roll forces the fine and moves you"] = function()
	local state = jailed({ { 1, 2 } })
	GameFixtures.own(state, "p1", 13)
	local p1 = player(state, "p1")
	p1.jailAttempts = 2
	p1.money = 20
	act(state, "p1", ROLL)
	assert(not p1.inJail, "still in jail")
	Expect.equal(p1.money, -30, "fine charged even into debt")
	Expect.equal(p1.position, 13, "moved by the roll")
	Expect.equal(state.phase, "EndTurn")
	Expect.equal(GameFixtures.eventsOfType(state, "LeftJail")[1].reason, "Fine")
	Expect.equal(GameFixtures.eventsOfType(state, "Paid")[1].reason, "JailFine")
end

tests["paying the fine frees you, then you roll normally"] = function()
	local state = jailed({ { 1, 2 } })
	GameFixtures.own(state, "p1", 13)
	act(state, "p1", PAY_FINE)
	local p1 = player(state, "p1")
	assert(not p1.inJail, "still in jail")
	Expect.equal(p1.money, 1450, "fine paid")
	Expect.equal(state.phase, "Roll", "still has to roll")
	Expect.equal(GameFixtures.eventsOfType(state, "LeftJail")[1].reason, "Fine")
	act(state, "p1", ROLL)
	Expect.equal(p1.position, 13, "moved")
end

tests["can't pay the fine without $50"] = function()
	local state = jailed({})
	player(state, "p1").money = 40
	local ok, err = Engine.act(state, "p1", PAY_FINE)
	assert(not ok, "paid without the money")
	Expect.equal(err, "not enough money")
	assert(player(state, "p1").inJail, "left jail")
	Expect.equal(player(state, "p1").money, 40, "money unchanged")
end

tests["paying the fine is refused outside jail or after rolling"] = function()
	local state = GameFixtures.newGame(2, { { 1, 2 } })
	assert(not Engine.act(state, "p1", PAY_FINE), "paid while free")
	state = jailed({ { 1, 2 } })
	act(state, "p1", ROLL)
	assert(not Engine.act(state, "p1", PAY_FINE), "paid after rolling")
	Expect.equal(player(state, "p1").money, 1500, "money unchanged")
end

tests["a jailed player still collects rent"] = function()
	local state = jailed({ { 1, 2 }, { 2, 4 } })
	GameFixtures.own(state, "p1", 6)
	act(state, "p1", ROLL) -- no doubles, stays in jail
	act(state, "p1", END_TURN)
	act(state, "p2", ROLL) -- 6, p1's property
	local p1 = player(state, "p1")
	assert(p1.inJail, "p1 left jail")
	Expect.equal(p1.money, 1506, "rent while in jail")
end

return tests
```

In `src/tests/Engine.spec.luau`:

- In `"rolling moves the current player by the dice total"`, after `Expect.equal(moved.to, 6, "moved to")` add:

```lua
	Expect.equal(moved.style, "Walk", "moved style")
```

- Replace the test `"other tiles just end the move"` with (Chance now draws cards; use Free Parking):

```lua
tests["other tiles just end the move"] = function()
	local state = GameFixtures.newGame(2, { { 3, 4 } })
	Engine.getPlayer(state, "p1").position = 13 -- 13 + 7 = 20, Free Parking
	act(state, "p1", ROLL)
	Expect.equal(money(state, "p1"), 1500)
	Expect.equal(state.phase, "EndTurn")
end
```

- In `"doubles give the same player another roll"` change the dice to `{ { 2, 2 } } -- 4 -> Income Tax` (Community Chest will draw cards after Task 2).

- [ ] **Step 2: Run tests to verify they fail**

Run: `.run("Jail")` then the full suite.
Expected: Jail.spec failures such as `position: expected 10, got 30` and `jail move style: expected ToJail, got nil`; Engine.spec fails `moved style: expected Walk, got nil`.

- [ ] **Step 3: Implement**

`src/server/Game/Types.luau` — replace the `Player` and `GameState` types and the `Action` comment:

```lua
export type Player = {
	id: string,
	name: string,
	isBot: boolean,
	money: number,
	position: number,
	bankrupt: boolean,
	inJail: boolean,
	jailAttempts: number, -- failed doubles rolls during this jail stay
}
```

```lua
export type Action = { [string]: any } -- { type = "Roll" | "Buy" | "Decline" | "Bid" | "PassBid" | "EndTurn" | "PayJailFine", amount = number? }
```

```lua
export type GameState = {
	players: { Player },
	currentIndex: number,
	phase: Phase,
	properties: { [number]: Ownership }, -- keyed by board position; absent = owned by the bank
	lastRoll: { number }?,
	doublesCount: number, -- doubles rolled so far this turn
	rollAgain: boolean, -- the move being resolved earned another roll
	auction: Auction?,
	events: { Event },
	rollDice: DiceRoller,
}
```

Also update the `Event` comment example to `{ type = "Moved", player = "p1", from = 38, to = 3, passedGo = true, style = "Walk" }`.

`src/server/Game/Engine.luau` — add constants after `Engine.MAX_PLAYERS = 6`:

```lua
Engine.JAIL_POSITION = 10
Engine.JAIL_FINE = 50
Engine.JAIL_MAX_ATTEMPTS = 3 -- failed doubles rolls before the fine is forced
Engine.MAX_DOUBLES = 3 -- doubles in one turn that send you to jail
```

Delete `rolledDoubles`. Replace `finishMove`, `resolveLanding` and `roll` with:

```lua
-- Called once everything caused by landing is settled.
local function finishMove(state: GameState)
	state.phase = if state.rollAgain and not Engine.currentPlayer(state).inJail then "Roll" else "EndTurn"
end

-- style: "Walk" hops forward and collects Go when passing it, "Back" hops backward,
-- "ToJail" jumps straight into the jail cell.
local function moveTo(state: GameState, player: Player, to: number, style: string)
	local from = player.position
	local passedGo = style == "Walk" and to < from
	player.position = to
	emit(state, { type = "Moved", player = player.id, from = from, to = to, passedGo = passedGo, style = style })
	if passedGo then
		transfer(state, nil, player.id, Engine.GO_SALARY, "Go")
	end
end

local function sendToJail(state: GameState, player: Player, reason: string)
	moveTo(state, player, Engine.JAIL_POSITION, "ToJail")
	player.inJail = true
	player.jailAttempts = 0
	emit(state, { type = "SentToJail", player = player.id, reason = reason })
	finishMove(state)
end

local function leaveJail(state: GameState, player: Player, reason: string)
	player.inJail = false
	player.jailAttempts = 0
	emit(state, { type = "LeftJail", player = player.id, reason = reason })
end

local function resolveLanding(state: GameState, player: Player)
	local tile = Tiles.at(player.position)

	if PURCHASABLE[tile.kind] then
		local ownership = state.properties[tile.position]
		if not ownership then
			state.phase = "BuyDecision"
			emit(state, { type = "OfferedPurchase", player = player.id, position = tile.position })
			return
		end
		if ownership.owner ~= player.id then
			local roll = state.lastRoll :: { number }
			local rent = Rent.calculate(state, tile.position, roll[1] + roll[2])
			if rent > 0 then
				transfer(state, player.id, ownership.owner, rent, "Rent")
			end
		end
	elseif tile.kind == "Tax" then
		transfer(state, player.id, nil, tile.amount :: number, "Tax")
	elseif tile.kind == "GoToJail" then
		sendToJail(state, player, "GoToJail")
		return
	end

	finishMove(state)
end

local function roll(state: GameState, player: Player)
	local a, b = state.rollDice()
	state.lastRoll = { a, b }
	emit(state, { type = "Rolled", player = player.id, dice = { a, b } })
	local doubles = a == b

	if player.inJail then
		if doubles then
			leaveJail(state, player, "Doubles")
		else
			player.jailAttempts += 1
			if player.jailAttempts < Engine.JAIL_MAX_ATTEMPTS then
				finishMove(state)
				return
			end
			transfer(state, player.id, nil, Engine.JAIL_FINE, "JailFine")
			leaveJail(state, player, "Fine")
		end
		-- Getting out by the dice never earns another roll.
		state.rollAgain = false
	else
		if doubles then
			state.doublesCount += 1
			if state.doublesCount >= Engine.MAX_DOUBLES then
				sendToJail(state, player, "Doubles")
				return
			end
		end
		state.rollAgain = doubles
	end

	moveTo(state, player, (player.position + a + b) % Tiles.COUNT, "Walk")
	resolveLanding(state, player)
end

local function payJailFine(state: GameState, player: Player): (boolean, string?)
	if player.money < Engine.JAIL_FINE then
		return false, "not enough money"
	end
	transfer(state, player.id, nil, Engine.JAIL_FINE, "JailFine")
	leaveJail(state, player, "Fine")
	return true
end
```

In `endTurn`, after `state.lastRoll = nil` add:

```lua
	state.doublesCount = 0
	state.rollAgain = false
```

In `Engine.new`, add to each inserted player `inJail = false, jailAttempts = 0,` and to the `state` literal `doublesCount = 0, rollAgain = false,` (after `lastRoll = nil`).

In `Engine.act`, add before `elseif action.type == "EndTurn"`:

```lua
	elseif action.type == "PayJailFine" and state.phase == "Roll" and player.inJail then
		return payJailFine(state, player)
```

`src/tests/GameFixtures.luau` — in `bareState`, give each player `inJail = false, jailAttempts = 0` and the state `doublesCount = 0, rollAgain = false`.

- [ ] **Step 4: Run tests to verify they pass**

Run: full suite. Expected: all pass (87 + 11 new = 98).

- [ ] **Step 5: Commit**

```bash
git add src/server/Game/Types.luau src/server/Game/Engine.luau src/tests/GameFixtures.luau src/tests/Engine.spec.luau src/tests/Jail.spec.luau
git commit -m "feat: jail, Go To Jail and the three-doubles rule"
```

---

### Task 2: Chance and Community Chest

**Files:**
- Create: `src/shared/Board/Cards.luau`, `src/tests/Cards.spec.luau`, `src/tests/CardEffects.spec.luau`
- Modify: `src/server/Game/Types.luau`, `src/server/Game/Engine.luau`, `src/server/Game/GameSession.luau`, `src/server/GameService.luau`, `src/tests/GameFixtures.luau`

**Interfaces:**
- Consumes: Task 1's `moveTo`, `sendToJail`, `leaveJail`, `finishMove`, `resolveLanding`, `transfer`, `Engine.JAIL_POSITION`.
- Produces:
  - `Cards.DECKS = { "Chance", "CommunityChest" }`, `Cards.DECK_TITLES: { [string]: string }` (`"Chance"`, `"Community Chest"`), `Cards.list: { Card }`, `Cards.byId: { [string]: Card }`, `Cards.idsFor(deck): { string }` (fresh array in listed order). `Card = { id, deck, text, effect }`; `Effect = { kind, amount?, position?, tileKind?, spaces?, perHouse?, perHotel? }`.
  - `Player.jailCards: { string }` — ids of held Get Out of Jail Free cards.
  - `GameState.decks: { [string]: { string } }` — card ids, index 1 is the top.
  - `Types.Shuffler = (ids: { string }) -> ()` (shuffles in place). `Engine.new(players, rollDice, shuffle: Shuffler?)` — nil leaves decks in listed order. `GameSession.new(humans, seats, rollDice, shuffle: Shuffler?)`.
  - Action `{ type = "UseJailCard" }` (Roll phase, in jail, holding a card; error `"no Get Out of Jail Free card"` otherwise when jailed).
  - Events: `CardDrawn { player, deck, card }`; `Paid` reason `"Card"`; `Rolled` with `forCard = true` for the utility card's extra roll.
  - `GameFixtures.stackDeck(state, deck, ids)` — moves those ids to the top in the given order.

- [ ] **Step 1: Write the failing tests**

Create `src/tests/Cards.spec.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local Tiles = require(ReplicatedStorage.Shared.Board.Tiles)
local Expect = require(script.Parent.Expect)

local tests = {}

local KINDS = {
	Collect = true,
	Pay = true,
	PayEachPlayer = true,
	CollectFromEachPlayer = true,
	AdvanceTo = true,
	AdvanceToNearest = true,
	GoBack = true,
	GoToJail = true,
	JailFree = true,
	Repairs = true,
}

tests["each deck has 16 cards with unique ids and one Get Out of Jail Free"] = function()
	for _, deck in Cards.DECKS do
		local ids = Cards.idsFor(deck)
		Expect.equal(#ids, 16, `{deck} size`)
		local jailFree = 0
		for _, id in ids do
			Expect.equal(Cards.byId[id].deck, deck, `{id} deck`)
			if Cards.byId[id].effect.kind == "JailFree" then
				jailFree += 1
			end
		end
		Expect.equal(jailFree, 1, `{deck} jail cards`)
	end
	local seen = {}
	for _, card in Cards.list do
		assert(not seen[card.id], `duplicate id {card.id}`)
		seen[card.id] = true
	end
	Expect.equal(#Cards.list, 32, "total")
end

tests["every effect is well formed"] = function()
	for _, card in Cards.list do
		local effect = card.effect
		assert(KINDS[effect.kind], `{card.id}: unknown kind {effect.kind}`)
		assert(card.text ~= "", `{card.id}: no text`)
		if effect.kind == "AdvanceTo" then
			Tiles.at(effect.position :: number) -- errors on a bad position
		elseif effect.kind == "AdvanceToNearest" then
			assert(effect.tileKind == "Railroad" or effect.tileKind == "Utility", `{card.id}: tileKind`)
		elseif effect.kind == "Repairs" then
			assert(effect.perHouse and effect.perHotel, `{card.id}: repair costs`)
		elseif effect.kind == "GoBack" then
			assert(effect.spaces, `{card.id}: spaces`)
		elseif effect.kind ~= "GoToJail" and effect.kind ~= "JailFree" then
			assert(effect.amount and effect.amount > 0, `{card.id}: amount`)
		end
	end
end

-- Other specs roll onto Chance/Community Chest with unshuffled decks and expect nothing but money to change.
tests["unshuffled decks start with money-only cards"] = function()
	local chance = Cards.idsFor("Chance")
	for i = 1, 3 do
		local kind = Cards.byId[chance[i]].effect.kind
		assert(kind == "Collect" or kind == "Pay", `Chance card {i} is {kind}`)
	end
	Expect.equal(Cards.byId[Cards.idsFor("CommunityChest")[1]].effect.kind, "Collect", "first Community Chest card")
end

tests["idsFor returns a fresh list each time"] = function()
	local ids = Cards.idsFor("Chance")
	ids[1] = "tampered"
	assert(Cards.idsFor("Chance")[1] ~= "tampered", "shared list")
	Expect.equal(Cards.DECK_TITLES.CommunityChest, "Community Chest")
end

return tests
```

Create `src/tests/CardEffects.spec.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Cards = require(ReplicatedStorage.Shared.Board.Cards)
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local ROLL = { type = "Roll" }

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function player(state, id: string): any
	return Engine.getPlayer(state, id) :: any
end

-- p1 starts on `from` and rolls onto a card tile whose deck has `cardId` on top.
-- Chance is at 7, 22, 36; Community Chest at 2, 17, 33.
local function drawAt(from: number, rolls: { { number } }, deck: string, cardId: string, playerCount: number?)
	local state = GameFixtures.newGame(playerCount or 2, rolls)
	player(state, "p1").position = from
	GameFixtures.stackDeck(state, deck, { cardId })
	act(state, "p1", ROLL)
	return state
end

tests["a drawn card is announced and goes to the bottom of its deck"] = function()
	local state = drawAt(4, { { 1, 2 } }, "Chance", "chance.loan")
	local drawn = GameFixtures.eventsOfType(state, "CardDrawn")[1]
	Expect.equal(drawn.card, "chance.loan", "card")
	Expect.equal(drawn.deck, "Chance", "deck")
	Expect.equal(drawn.player, "p1", "player")
	Expect.equal(player(state, "p1").money, 1650, "collected")
	Expect.equal(state.decks.Chance[#state.decks.Chance], "chance.loan", "bottom of the deck")
	Expect.equal(#state.decks.Chance, 16, "deck size")
	Expect.equal(state.phase, "EndTurn")
end

tests["pay cards charge the bank"] = function()
	local state = drawAt(14, { { 1, 2 } }, "CommunityChest", "chest.doctor")
	Expect.equal(player(state, "p1").money, 1450)
	Expect.equal(GameFixtures.eventsOfType(state, "Paid")[1].reason, "Card")
end

tests["advancing past Go collects $200 and resolves the new tile"] = function()
	local state = drawAt(33, { { 1, 2 } }, "Chance", "chance.stCharles") -- 36 -> 11
	local p1 = player(state, "p1")
	Expect.equal(p1.position, 11, "position")
	Expect.equal(p1.money, 1700, "Go salary")
	Expect.equal(state.phase, "BuyDecision", "offered St. Charles Place")
	local moved = GameFixtures.eventsOfType(state, "Moved")[2]
	Expect.equal(moved.style, "Walk", "style")
	assert(moved.passedGo, "passedGo")
end

tests["advancing without passing Go collects nothing"] = function()
	local state = drawAt(4, { { 1, 2 } }, "Chance", "chance.illinois") -- 7 -> 24
	Expect.equal(player(state, "p1").position, 24)
	Expect.equal(player(state, "p1").money, 1500)
	Expect.equal(state.phase, "BuyDecision")
end

tests["go back 3 hops backward and resolves the new tile, even another card"] = function()
	local state = GameFixtures.newGame(2, { { 1, 2 } })
	player(state, "p1").position = 33
	GameFixtures.stackDeck(state, "Chance", { "chance.back3" })
	GameFixtures.stackDeck(state, "CommunityChest", { "chest.bankError" })
	act(state, "p1", ROLL) -- 36 Chance -> back to 33 Community Chest
	local p1 = player(state, "p1")
	Expect.equal(p1.position, 33, "position")
	Expect.equal(p1.money, 1700, "bank error collected once")
	local moved = GameFixtures.eventsOfType(state, "Moved")[2]
	Expect.equal(moved.style, "Back", "style")
	Expect.equal(moved.passedGo, false, "no Go going backwards")
	Expect.equal(#GameFixtures.eventsOfType(state, "CardDrawn"), 2, "two cards")
	Expect.equal(state.phase, "EndTurn")
end

tests["the go to jail card ends the turn even after doubles"] = function()
	local state = drawAt(5, { { 1, 1 } }, "Chance", "chance.jail")
	local p1 = player(state, "p1")
	assert(p1.inJail, "not in jail")
	Expect.equal(p1.position, 10, "position")
	Expect.equal(p1.money, 1500, "no Go salary")
	Expect.equal(GameFixtures.eventsOfType(state, "SentToJail")[1].reason, "Card")
	Expect.equal(state.phase, "EndTurn")
end

tests["doubles still earn another roll after a card that doesn't jail"] = function()
	local state = drawAt(5, { { 1, 1 } }, "Chance", "chance.dividend")
	Expect.equal(state.phase, "Roll")
end

tests["nearest railroad: pay twice the rent, passing Go if needed"] = function()
	local state = GameFixtures.newGame(2, { { 1, 2 } })
	player(state, "p1").position = 4
	GameFixtures.own(state, "p2", 15)
	GameFixtures.stackDeck(state, "Chance", { "chance.railroad1" })
	act(state, "p1", ROLL) -- 7 -> Pennsylvania Railroad (15)
	Expect.equal(player(state, "p1").position, 15, "position")
	Expect.equal(player(state, "p1").money, 1450, "paid 2 x 25")
	Expect.equal(player(state, "p2").money, 1550, "owner paid")

	state = drawAt(33, { { 1, 2 } }, "Chance", "chance.railroad2") -- 36 -> Reading Railroad (5)
	Expect.equal(player(state, "p1").position, 5, "wrapped position")
	Expect.equal(player(state, "p1").money, 1700, "Go salary")
	Expect.equal(state.phase, "BuyDecision", "unowned: offered as usual")
end

tests["nearest utility: roll again and pay ten times the roll"] = function()
	local state = GameFixtures.newGame(2, { { 1, 2 }, { 4, 5 } })
	player(state, "p1").position = 19
	GameFixtures.own(state, "p2", 28)
	GameFixtures.stackDeck(state, "Chance", { "chance.utility" })
	act(state, "p1", ROLL) -- 22 -> Water Works (28)
	Expect.equal(player(state, "p1").position, 28, "position")
	Expect.equal(player(state, "p1").money, 1410, "paid 10 x 9")
	local rolls = GameFixtures.eventsOfType(state, "Rolled")
	Expect.equal(#rolls, 2, "rolled for the card")
	assert(rolls[2].forCard, "second roll is for the card")
	Expect.equal((state.lastRoll :: { number })[1], 1, "lastRoll untouched")
end

tests["pay each player skips bankrupt players"] = function()
	local state = GameFixtures.newGame(3, { { 1, 2 } })
	player(state, "p3").bankrupt = true
	player(state, "p1").position = 4
	GameFixtures.stackDeck(state, "Chance", { "chance.chairman" })
	act(state, "p1", ROLL)
	Expect.equal(player(state, "p1").money, 1450, "paid one player")
	Expect.equal(player(state, "p2").money, 1550, "p2")
	Expect.equal(player(state, "p3").money, 1500, "bankrupt p3")
end

tests["collect from each player"] = function()
	local state = drawAt(14, { { 1, 2 } }, "CommunityChest", "chest.birthday", 3)
	Expect.equal(player(state, "p1").money, 1520, "p1")
	Expect.equal(player(state, "p2").money, 1490, "p2")
	Expect.equal(player(state, "p3").money, 1490, "p3")
end

tests["repairs charge per house and per hotel"] = function()
	local state = GameFixtures.newGame(2, { { 1, 2 } })
	player(state, "p1").position = 14
	GameFixtures.own(state, "p1", 1, 2) -- 2 houses
	GameFixtures.own(state, "p1", 3, 5) -- hotel
	GameFixtures.own(state, "p2", 6, 4) -- someone else's houses
	GameFixtures.stackDeck(state, "CommunityChest", { "chest.streetRepairs" })
	act(state, "p1", ROLL)
	Expect.equal(player(state, "p1").money, 1500 - (2 * 40 + 115))
end

tests["a Get Out of Jail Free card is kept, then used and returned to its deck"] = function()
	local state = drawAt(4, { { 1, 2 } }, "Chance", "chance.jailFree")
	local p1 = player(state, "p1")
	Expect.equal(p1.jailCards[1], "chance.jailFree", "held")
	Expect.equal(#state.decks.Chance, 15, "out of the deck")
	assert(not table.find(state.decks.Chance, "chance.jailFree"), "still in the deck")

	-- Next turn p1 starts in jail.
	p1.inJail = true
	p1.position = Engine.JAIL_POSITION
	state.phase = "Roll"
	act(state, "p1", { type = "UseJailCard" })
	assert(not p1.inJail, "still in jail")
	Expect.equal(#p1.jailCards, 0, "card used")
	Expect.equal(state.decks.Chance[16], "chance.jailFree", "back at the bottom of Chance")
	Expect.equal(GameFixtures.eventsOfType(state, "LeftJail")[1].reason, "Card")
	Expect.equal(state.phase, "Roll", "still has to roll")
end

tests["using a jail card needs one, and needs to be in jail"] = function()
	local state = GameFixtures.newGame(2)
	assert(not Engine.act(state, "p1", { type = "UseJailCard" }), "used while free")
	player(state, "p1").inJail = true
	local ok, err = Engine.act(state, "p1", { type = "UseJailCard" })
	assert(not ok, "used without a card")
	Expect.equal(err, "no Get Out of Jail Free card")
end

tests["new games shuffle each deck with the given shuffler"] = function()
	local shuffled = {}
	local state = Engine.new({
		{ id = "a", name = "A", isBot = false },
		{ id = "b", name = "B", isBot = false },
	}, GameFixtures.scriptedDice({}), function(ids)
		table.insert(shuffled, #ids)
		table.clear(ids)
		table.insert(ids, "chance.dividend")
	end)
	Expect.equal(#shuffled, 2, "both decks shuffled")
	Expect.equal(state.decks.Chance[1], "chance.dividend", "shuffler's order kept")
	local unshuffled = GameFixtures.newGame(2)
	Expect.equal(unshuffled.decks.Chance[1], Cards.idsFor("Chance")[1], "no shuffler: listed order")
end

return tests
```

- [ ] **Step 2: Run tests to verify they fail**

Run: full suite. Expected: `Cards.spec (load)` fails (module missing), CardEffects.spec load fails too (requires Cards).

- [ ] **Step 3: Implement**

Create `src/shared/Board/Cards.luau`:

```lua
--!strict
-- The Chance and Community Chest cards. A new game's decks start in the order listed here and are
-- then shuffled. Each list starts with money-only cards (Chance: three, Community Chest: one):
-- tests that roll onto a card tile with unshuffled decks rely on that, so keep them first.

export type DeckName = "Chance" | "CommunityChest"

-- kind: Collect / Pay / PayEachPlayer / CollectFromEachPlayer (amount), AdvanceTo (position),
-- AdvanceToNearest (tileKind: "Railroad" | "Utility"), GoBack (spaces), GoToJail, JailFree,
-- Repairs (perHouse, perHotel).
export type Effect = {
	kind: string,
	amount: number?,
	position: number?,
	tileKind: string?,
	spaces: number?,
	perHouse: number?,
	perHotel: number?,
}

export type Card = {
	id: string,
	deck: DeckName,
	text: string,
	effect: Effect,
}

type Entry = { id: string, text: string, effect: Effect }

local CHANCE: { Entry } = {
	{ id = "chance.dividend", text = "Bank pays you a dividend of $50.", effect = { kind = "Collect", amount = 50 } },
	{ id = "chance.loan", text = "Your building loan matures. Collect $150.", effect = { kind = "Collect", amount = 150 } },
	{ id = "chance.speeding", text = "Speeding fine: pay $15.", effect = { kind = "Pay", amount = 15 } },
	{ id = "chance.boardwalk", text = "Advance to Boardwalk.", effect = { kind = "AdvanceTo", position = 39 } },
	{ id = "chance.go", text = "Advance to Go. Collect $200.", effect = { kind = "AdvanceTo", position = 0 } },
	{
		id = "chance.illinois",
		text = "Advance to Illinois Avenue. If you pass Go, collect $200.",
		effect = { kind = "AdvanceTo", position = 24 },
	},
	{
		id = "chance.stCharles",
		text = "Advance to St. Charles Place. If you pass Go, collect $200.",
		effect = { kind = "AdvanceTo", position = 11 },
	},
	{
		id = "chance.reading",
		text = "Take a trip to Reading Railroad. If you pass Go, collect $200.",
		effect = { kind = "AdvanceTo", position = 5 },
	},
	{
		id = "chance.railroad1",
		text = "Advance to the nearest Railroad. If it is owned, pay the owner twice the rent.",
		effect = { kind = "AdvanceToNearest", tileKind = "Railroad" },
	},
	{
		id = "chance.railroad2",
		text = "Advance to the nearest Railroad. If it is owned, pay the owner twice the rent.",
		effect = { kind = "AdvanceToNearest", tileKind = "Railroad" },
	},
	{
		id = "chance.utility",
		text = "Advance to the nearest Utility. If it is owned, roll the dice and pay the owner ten times the roll.",
		effect = { kind = "AdvanceToNearest", tileKind = "Utility" },
	},
	{ id = "chance.jailFree", text = "Get Out of Jail Free. Keep this card until needed.", effect = { kind = "JailFree" } },
	{ id = "chance.back3", text = "Go back 3 spaces.", effect = { kind = "GoBack", spaces = 3 } },
	{ id = "chance.jail", text = "Go to Jail. Do not pass Go, do not collect $200.", effect = { kind = "GoToJail" } },
	{
		id = "chance.repairs",
		text = "Make general repairs on all your property: pay $25 per house and $100 per hotel.",
		effect = { kind = "Repairs", perHouse = 25, perHotel = 100 },
	},
	{
		id = "chance.chairman",
		text = "You have been elected Chairman of the Board. Pay each player $50.",
		effect = { kind = "PayEachPlayer", amount = 50 },
	},
}

local COMMUNITY_CHEST: { Entry } = {
	{ id = "chest.taxRefund", text = "Income tax refund. Collect $20.", effect = { kind = "Collect", amount = 20 } },
	{ id = "chest.bankError", text = "Bank error in your favor. Collect $200.", effect = { kind = "Collect", amount = 200 } },
	{ id = "chest.doctor", text = "Doctor's fee. Pay $50.", effect = { kind = "Pay", amount = 50 } },
	{ id = "chest.stock", text = "From sale of stock you get $50.", effect = { kind = "Collect", amount = 50 } },
	{ id = "chest.go", text = "Advance to Go. Collect $200.", effect = { kind = "AdvanceTo", position = 0 } },
	{ id = "chest.jailFree", text = "Get Out of Jail Free. Keep this card until needed.", effect = { kind = "JailFree" } },
	{ id = "chest.jail", text = "Go to Jail. Do not pass Go, do not collect $200.", effect = { kind = "GoToJail" } },
	{ id = "chest.holiday", text = "Holiday fund matures. Collect $100.", effect = { kind = "Collect", amount = 100 } },
	{
		id = "chest.birthday",
		text = "It is your birthday. Collect $10 from every player.",
		effect = { kind = "CollectFromEachPlayer", amount = 10 },
	},
	{ id = "chest.lifeInsurance", text = "Life insurance matures. Collect $100.", effect = { kind = "Collect", amount = 100 } },
	{ id = "chest.hospital", text = "Pay hospital fees of $100.", effect = { kind = "Pay", amount = 100 } },
	{ id = "chest.school", text = "Pay school fees of $50.", effect = { kind = "Pay", amount = 50 } },
	{ id = "chest.consultancy", text = "Receive a $25 consultancy fee.", effect = { kind = "Collect", amount = 25 } },
	{
		id = "chest.streetRepairs",
		text = "You are assessed for street repairs: pay $40 per house and $115 per hotel.",
		effect = { kind = "Repairs", perHouse = 40, perHotel = 115 },
	},
	{
		id = "chest.beautyContest",
		text = "You have won second prize in a beauty contest. Collect $10.",
		effect = { kind = "Collect", amount = 10 },
	},
	{ id = "chest.inherit", text = "You inherit $100.", effect = { kind = "Collect", amount = 100 } },
}

local Cards = {}

Cards.DECKS = table.freeze({ "Chance", "CommunityChest" } :: { DeckName })
Cards.DECK_TITLES = table.freeze({ Chance = "Chance", CommunityChest = "Community Chest" })

local list: { Card } = {}
local byId: { [string]: Card } = {}
local idsByDeck: { [string]: { string } } = {}

local function addDeck(deck: DeckName, entries: { Entry })
	local ids = {}
	for _, entry in entries do
		local card: Card = { id = entry.id, deck = deck, text = entry.text, effect = table.freeze(entry.effect) }
		table.freeze(card)
		table.insert(list, card)
		byId[card.id] = card
		table.insert(ids, card.id)
	end
	idsByDeck[deck] = table.freeze(ids)
end

addDeck("Chance", CHANCE)
addDeck("CommunityChest", COMMUNITY_CHEST)

Cards.list = table.freeze(list)
Cards.byId = table.freeze(byId)

-- A new array of the deck's card ids in listed order (callers may shuffle it).
function Cards.idsFor(deck: string): { string }
	return table.clone(assert(idsByDeck[deck], `unknown deck {deck}`))
end

return Cards
```

`src/server/Game/Types.luau` — add to `Player` after `jailAttempts`:

```lua
	jailCards: { string }, -- ids of held Get Out of Jail Free cards
```

add to `GameState` after `rollAgain`:

```lua
	decks: { [string]: { string } }, -- card ids per deck; index 1 is the top
```

add after `DiceRoller`:

```lua
export type Shuffler = (ids: { string }) -> () -- shuffles in place
```

and extend the `Action` comment with `| "UseJailCard"`.

`src/server/Game/Engine.luau`:

1. Require Cards after Tiles: `local Cards = require(ReplicatedStorage.Shared.Board.Cards)`.

2. `resolveLanding` becomes forward-declared because card effects call it and it calls `drawCard`. Replace the Task 1 `resolveLanding` with this block (place it where `resolveLanding` was, after `leaveJail`):

```lua
local resolveLanding: (state: GameState, player: Player, rentRule: string?) -> ()

local function nearestAhead(from: number, kind: string): number
	for step = 1, Tiles.COUNT do
		local position = (from + step) % Tiles.COUNT
		if Tiles.at(position).kind == kind then
			return position
		end
	end
	error(`no {kind} tile on the board`)
end

local function repairCost(state: GameState, player: Player, effect: Cards.Effect): number
	local cost = 0
	for _, ownership in state.properties do
		if ownership.owner == player.id then
			cost += if ownership.houses == 5
				then effect.perHotel :: number
				else ownership.houses * (effect.perHouse :: number)
		end
	end
	return cost
end

local function applyCard(state: GameState, player: Player, effect: Cards.Effect)
	local kind = effect.kind
	if kind == "Collect" then
		transfer(state, nil, player.id, effect.amount :: number, "Card")
	elseif kind == "Pay" then
		transfer(state, player.id, nil, effect.amount :: number, "Card")
	elseif kind == "PayEachPlayer" or kind == "CollectFromEachPlayer" then
		for _, other in state.players do
			if other ~= player and not other.bankrupt then
				if kind == "PayEachPlayer" then
					transfer(state, player.id, other.id, effect.amount :: number, "Card")
				else
					transfer(state, other.id, player.id, effect.amount :: number, "Card")
				end
			end
		end
	elseif kind == "Repairs" then
		local cost = repairCost(state, player, effect)
		if cost > 0 then
			transfer(state, player.id, nil, cost, "Card")
		end
	elseif kind == "GoToJail" then
		sendToJail(state, player, "Card")
		return
	elseif kind == "AdvanceTo" then
		moveTo(state, player, effect.position :: number, "Walk")
		resolveLanding(state, player)
		return
	elseif kind == "AdvanceToNearest" then
		local tileKind = effect.tileKind :: string
		moveTo(state, player, nearestAhead(player.position, tileKind), "Walk")
		resolveLanding(state, player, if tileKind == "Railroad" then "DoubleRailroad" else "UtilityTenTimes")
		return
	elseif kind == "GoBack" then
		moveTo(state, player, (player.position - (effect.spaces :: number)) % Tiles.COUNT, "Back")
		resolveLanding(state, player)
		return
	end
	-- JailFree needs nothing more: drawCard already handed the card to the player.
	finishMove(state)
end

local function drawCard(state: GameState, player: Player, deck: string)
	local cards = state.decks[deck]
	local id = table.remove(cards, 1) :: string
	emit(state, { type = "CardDrawn", player = player.id, deck = deck, card = id })
	local card = Cards.byId[id]
	if card.effect.kind == "JailFree" then
		table.insert(player.jailCards, id) -- returns to the deck when used
	else
		table.insert(cards, id)
	end
	applyCard(state, player, card.effect)
end

-- rentRule comes from the "nearest Railroad/Utility" cards.
local function rentOwed(state: GameState, player: Player, position: number, rentRule: string?): number
	if rentRule == "UtilityTenTimes" then
		if (state.properties[position] :: Types.Ownership).mortgaged then
			return 0
		end
		local a, b = state.rollDice()
		emit(state, { type = "Rolled", player = player.id, dice = { a, b }, forCard = true })
		return (a + b) * 10
	end
	local roll = state.lastRoll :: { number }
	local rent = Rent.calculate(state, position, roll[1] + roll[2])
	return if rentRule == "DoubleRailroad" then rent * 2 else rent
end

function resolveLanding(state: GameState, player: Player, rentRule: string?)
	local tile = Tiles.at(player.position)

	if PURCHASABLE[tile.kind] then
		local ownership = state.properties[tile.position]
		if not ownership then
			state.phase = "BuyDecision"
			emit(state, { type = "OfferedPurchase", player = player.id, position = tile.position })
			return
		end
		if ownership.owner ~= player.id then
			local rent = rentOwed(state, player, tile.position, rentRule)
			if rent > 0 then
				transfer(state, player.id, ownership.owner, rent, "Rent")
			end
		end
	elseif tile.kind == "Tax" then
		transfer(state, player.id, nil, tile.amount :: number, "Tax")
	elseif tile.kind == "Chance" or tile.kind == "CommunityChest" then
		drawCard(state, player, tile.kind)
		return
	elseif tile.kind == "GoToJail" then
		sendToJail(state, player, "GoToJail")
		return
	end

	finishMove(state)
end
```

Note: `function resolveLanding(...)` assigns the forward-declared local (Luau allows `function name()` for an existing local). If the type checker objects, write `resolveLanding = function(state: GameState, player: Player, rentRule: string?) ... end`.

3. After `payJailFine`, add:

```lua
local function useJailCard(state: GameState, player: Player): (boolean, string?)
	local id = table.remove(player.jailCards, 1)
	if not id then
		return false, "no Get Out of Jail Free card"
	end
	table.insert(state.decks[Cards.byId[id].deck], id)
	leaveJail(state, player, "Card")
	return true
end
```

4. `Engine.new(players: { PlayerInfo }, rollDice: Types.DiceRoller, shuffle: Types.Shuffler?): GameState` — add `jailCards = {},` to each player, and before building `state`:

```lua
	local decks = {}
	for _, deck in Cards.DECKS do
		local ids = Cards.idsFor(deck)
		if shuffle then
			shuffle(ids)
		end
		decks[deck] = ids
	end
```

with `decks = decks,` in the state literal.

5. In `Engine.act`, after the `PayJailFine` branch:

```lua
	elseif action.type == "UseJailCard" and state.phase == "Roll" and player.inJail then
		return useJailCard(state, player)
```

`src/server/Game/GameSession.luau` — `GameSession.new(humans: { Human }, seats: number, rollDice: Types.DiceRoller, shuffle: Types.Shuffler?): Session` and `Engine.new(infos, rollDice, shuffle)`.

`src/server/GameService.luau` — add after `rollDice`:

```lua
local function shuffle(ids: { string })
	for i = #ids, 2, -1 do
		local j = random:NextInteger(1, i)
		ids[i], ids[j] = ids[j], ids[i]
	end
end
```

and call `GameSession.new(humans, request.seats, rollDice, shuffle)`.

`src/tests/GameFixtures.luau` — require `local Cards = require(game:GetService("ReplicatedStorage").Shared.Board.Cards)`; in `bareState` give each player `jailCards = {}` and the state `decks = { Chance = Cards.idsFor("Chance"), CommunityChest = Cards.idsFor("CommunityChest") }`. Add:

```lua
-- Puts these card ids on top of the deck, first id drawn first.
function GameFixtures.stackDeck(state: Types.GameState, deck: string, ids: { string })
	local cards = state.decks[deck]
	for i = #ids, 1, -1 do
		local index = table.find(cards, ids[i])
		assert(index, `{ids[i]} is not in the {deck} deck`)
		table.remove(cards, index)
		table.insert(cards, 1, ids[i])
	end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: full suite. Expected: all pass (98 + 4 + 15 = 117). If an older spec that rolls onto 7 now fails, check the unshuffled Chance order first — the first three cards must stay money-only.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Board/Cards.luau src/server src/tests
git commit -m "feat: Chance and Community Chest cards"
```

---

### Task 3: Bots, snapshot, HUD model and log text for jail and cards

**Files:**
- Modify: `src/server/Game/Bot.luau`, `src/server/Game/Snapshot.luau`, `src/shared/Net/Protocol.luau`, `src/client/Hud/HudModel.luau`, `src/client/Hud/EventText.luau`
- Modify tests: `src/tests/Bot.spec.luau`, `src/tests/Snapshot.spec.luau`, `src/tests/HudModel.spec.luau`, `src/tests/EventText.spec.luau`

**Interfaces:**
- Consumes: Task 1/2 player fields, actions, events; `Cards.byId`, `Cards.DECK_TITLES`.
- Produces:
  - `Protocol.PlayerView.inJail: boolean`, `Protocol.PlayerView.jailCards: number` (count held).
  - `HudModel.JAIL_FINE = 50` (must equal `Engine.JAIL_FINE`; a test pins it).
  - `HudModel.buttons` in the Roll phase while jailed: `"Try for doubles"` (Roll), `"Pay $50 fine"` (PayJailFine, only if money ≥ 50), `"Use jail card"` (UseJailCard, only if jailCards > 0). `HudModel.status` → `"Your turn — you're in jail"` when the local player is jailed and must roll.
  - Bot in jail at Roll: `UseJailCard` if holding one, else `PayJailFine` if `money - JAIL_FINE >= CASH_RESERVE`, else `Roll`.

- [ ] **Step 1: Write the failing tests**

`src/tests/Bot.spec.luau` — add before `return tests`:

```lua
tests["a jailed bot uses its card, else pays if it can spare it, else rolls"] = function()
	local state = GameFixtures.newGame(2)
	local me = Engine.getPlayer(state, "p1") :: any
	me.inJail = true
	me.jailCards = { "chance.jailFree" }
	Expect.equal(Bot.chooseAction(state, "p1").type, "UseJailCard", "has a card")
	me.jailCards = {}
	Expect.equal(Bot.chooseAction(state, "p1").type, "PayJailFine", "rich")
	me.money = Bot.CASH_RESERVE + 49
	Expect.equal(Bot.chooseAction(state, "p1").type, "Roll", "poor")
end
```

Replace `"an all-bot game keeps making legal moves"` with a shuffled, longer run that proves jail and cards were exercised:

```lua
tests["an all-bot game keeps making legal moves"] = function()
	local random = Random.new(1234)
	local state = Engine.new({
		{ id = "b1", name = "B1", isBot = true },
		{ id = "b2", name = "B2", isBot = true },
		{ id = "b3", name = "B3", isBot = true },
		{ id = "b4", name = "B4", isBot = true },
	}, function()
		return random:NextInteger(1, 6), random:NextInteger(1, 6)
	end, function(ids)
		for i = #ids, 2, -1 do
			local j = random:NextInteger(1, i)
			ids[i], ids[j] = ids[j], ids[i]
		end
	end)
	for step = 1, 2000 do
		local actor = assert(Engine.actingPlayer(state), `no acting player at step {step}`)
		local action = assert(Bot.chooseAction(state, actor), `bot {actor} had no action in {state.phase}`)
		local ok, err = Engine.act(state, actor, action)
		assert(ok, `step {step}: {actor} {action.type} rejected: {err}`)
	end
	for _, eventType in { "SentToJail", "LeftJail", "CardDrawn" } do
		assert(#GameFixtures.eventsOfType(state, eventType) > 0, `no {eventType} in 2000 steps`)
	end
end
```

`src/tests/Snapshot.spec.luau` — add:

```lua
tests["players show jail status and how many jail cards they hold"] = function()
	local state = GameFixtures.newGame(2)
	local p1 = Engine.getPlayer(state, "p1") :: any
	p1.inJail = true
	p1.jailCards = { "chance.jailFree", "chest.jailFree" }
	local view = Snapshot.fromState(state).players[1]
	Expect.equal(view.inJail, true, "inJail")
	Expect.equal(view.jailCards, 2, "jailCards")
	Expect.equal(Snapshot.fromState(state).players[2].inJail, false, "p2")
end
```

`src/tests/HudModel.spec.luau` — add:

```lua
tests["jail buttons follow what the player can do"] = function()
	Expect.equal(HudModel.JAIL_FINE, Engine.JAIL_FINE, "fine matches the engine")
	local state = GameFixtures.newGame(2)
	local p1 = Engine.getPlayer(state, "p1") :: any
	p1.inJail = true
	local snapshot = Snapshot.fromState(state)
	Expect.equal(labels(HudModel.buttons(snapshot, "p1")), "Try for doubles|Pay $50 fine")
	Expect.equal(HudModel.status(snapshot, "p1"), "Your turn — you're in jail")

	p1.jailCards = { "chance.jailFree" }
	p1.money = 40
	local buttons = HudModel.buttons(Snapshot.fromState(state), "p1")
	Expect.equal(labels(buttons), "Try for doubles|Use jail card", "broke, with a card")
	Expect.equal(buttons[1].action.type, "Roll")
	Expect.equal(buttons[2].action.type, "UseJailCard")
end
```

`src/tests/EventText.spec.luau` — add to the `cases` list in `"describes the events players care about"`:

```lua
		{ { type = "SentToJail", player = "p1", reason = "GoToJail" }, "Ana went to jail" },
		{ { type = "SentToJail", player = "p1", reason = "Card" }, "Ana went to jail" },
		{ { type = "SentToJail", player = "p1", reason = "Doubles" }, "Ana rolled doubles three times and went to jail" },
		{ { type = "LeftJail", player = "p1", reason = "Doubles" }, "Ana rolled doubles and got out of jail" },
		{ { type = "LeftJail", player = "p1", reason = "Fine" }, "Ana paid $50 and got out of jail" },
		{ { type = "LeftJail", player = "p1", reason = "Card" }, "Ana used a Get Out of Jail Free card" },
		{ { type = "CardDrawn", player = "p1", deck = "CommunityChest", card = "chest.doctor" }, "Ana drew Community Chest: Doctor's fee. Pay $50." },
		{ { type = "Paid", from = "p1", to = "p2", amount = 50, reason = "Card" }, "Ana paid $50 to Bot 1" },
```

and to the skipped list in `"skips events that have no log line"`:

```lua
		{ type = "Paid", from = "p1", to = nil, amount = 50, reason = "JailFine" },
		{ type = "Paid", from = nil, to = "p1", amount = 50, reason = "Card" },
		{ type = "CardDrawn", player = "p1", deck = "Chance", card = "no.such.card" },
```

- [ ] **Step 2: Run tests to verify they fail**

Run: full suite. Expected: Bot jail test fails (`has a card: expected UseJailCard, got Roll`); Snapshot `inJail: expected true, got nil`; HudModel `JAIL_FINE` nil; EventText `SentToJail: expected Ana went to jail, got nil`.

- [ ] **Step 3: Implement**

`src/server/Game/Bot.luau` — replace the Roll branch:

```lua
	if state.phase == "Roll" then
		if me.inJail then
			if #me.jailCards > 0 then
				return { type = "UseJailCard" }
			elseif me.money - Engine.JAIL_FINE >= Bot.CASH_RESERVE then
				return { type = "PayJailFine" }
			end
		end
		return { type = "Roll" }
```

Update the header comment: `-- A simple bot: buys what it can afford while keeping a cash reserve, bids up to face value, and leaves jail as soon as it can spare the fine.`

`src/shared/Net/Protocol.luau` — add to `PlayerView`:

```lua
	inJail: boolean,
	jailCards: number, -- Get Out of Jail Free cards held
```

`src/server/Game/Snapshot.luau` — add to each player view: `inJail = player.inJail, jailCards = #player.jailCards,`.

`src/client/Hud/HudModel.luau` — add `HudModel.JAIL_FINE = 50 -- mirrors Engine.JAIL_FINE (server-only)` after `BID_STEPS`, and replace the Roll branch in `buttons`:

```lua
	if phase == "Roll" then
		local buttons = {}
		if me.inJail then
			table.insert(buttons, { label = "Try for doubles", action = { type = "Roll" } })
			if me.money >= HudModel.JAIL_FINE then
				table.insert(buttons, { label = `Pay ${HudModel.JAIL_FINE} fine`, action = { type = "PayJailFine" } })
			end
			if me.jailCards > 0 then
				table.insert(buttons, { label = "Use jail card", action = { type = "UseJailCard" } })
			end
		else
			table.insert(buttons, { label = "Roll dice", action = { type = "Roll" } })
		end
		return buttons
```

In `status`, replace the `if snapshot.currentPlayer == localId then return "Your turn" end` block with:

```lua
	if snapshot.currentPlayer == localId then
		local me = findPlayer(snapshot, localId)
		if me and me.inJail and snapshot.phase == "Roll" then
			return "Your turn — you're in jail"
		end
		return "Your turn"
	end
```

`src/client/Hud/EventText.luau` — require `local Cards = require(ReplicatedStorage.Shared.Board.Cards)`. In the `Paid` branch add before `return nil`:

```lua
		elseif event.reason == "Card" and event.from and event.to then
			return `{name(event.from)} paid ${event.amount} to {name(event.to)}`
```

(`JailFine` and bank card payments stay nil: `LeftJail`/`CardDrawn` already say it.) Add branches before `PlayerReplaced`:

```lua
	elseif kind == "SentToJail" then
		if event.reason == "Doubles" then
			return `{name(event.player)} rolled doubles three times and went to jail`
		end
		return `{name(event.player)} went to jail`
	elseif kind == "LeftJail" then
		if event.reason == "Doubles" then
			return `{name(event.player)} rolled doubles and got out of jail`
		elseif event.reason == "Fine" then
			return `{name(event.player)} paid $50 and got out of jail`
		end
		return `{name(event.player)} used a Get Out of Jail Free card`
	elseif kind == "CardDrawn" then
		local card = Cards.byId[event.card]
		if not card then
			return nil
		end
		return `{name(event.player)} drew {Cards.DECK_TITLES[card.deck]}: {card.text}`
```

- [ ] **Step 4: Run tests to verify they pass**

Run: full suite. Expected: all pass (117 + 3 = 120; the all-bot test is replaced, not added).

- [ ] **Step 5: Commit**

```bash
git add src/server/Game/Bot.luau src/server/Game/Snapshot.luau src/shared/Net/Protocol.luau src/client/Hud src/tests
git commit -m "feat: bots, HUD and log handle jail and cards"
```

---

### Task 4: Tokens, jail cell, card popup — and playtest

**Files:**
- Modify: `src/shared/Board/TokenLayout.luau`, `src/client/Tokens.luau`, `src/client/Hud/HudView.luau`, `src/client/GameClient.luau`
- Modify tests: `src/tests/TokenLayout.spec.luau`, `src/tests/Tokens.spec.luau`

**Interfaces:**
- Consumes: `Moved.style`, `PlayerView.inJail`, `CardDrawn` event, `Cards.byId`, `Cards.DECK_TITLES`.
- Produces:
  - `TokenLayout.JAIL_POSITION = 10`, `TokenLayout.jailSpot(seat): Vector3` — spots on the inner half of the Jail corner, clear of the just-visiting spots.
  - `Tokens.path(move: { from: number, to: number, style: string? }): { number }` — tiles hopped through: Walk (or nil) forward, Back backward, ToJail `{ to }`.
  - `HudView.showCard(self, deck: string, text: string)` — popup for a few seconds; the latest card wins.

- [ ] **Step 1: Write the failing tests**

`src/tests/TokenLayout.spec.luau` — add:

```lua
tests["jail spots sit in the inner half of the Jail tile, apart from each other and from visitors"] = function()
	local placement = Layout.getTilePlacement(TokenLayout.JAIL_POSITION)
	local tileTop = Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2, 0)
	local radius = TokenLayout.TOKEN_DIAMETER / 2
	for seat = 1, TokenLayout.MAX_SEATS do
		local spot = TokenLayout.jailSpot(seat)
		local localSpot = tileTop:PointToObjectSpace(spot)
		Expect.near(localSpot.Y, 0, `seat {seat} height`)
		assert(math.abs(localSpot.X) + radius <= placement.size.X / 2, `seat {seat} off the side`)
		assert(localSpot.Z - radius >= -placement.size.Z / 2, `seat {seat} off the inner edge`)
		assert(localSpot.Z < 0, `seat {seat} not in the inner half`)
		for other = 1, TokenLayout.MAX_SEATS do
			if other ~= seat then
				local gap = (spot - TokenLayout.jailSpot(other)).Magnitude
				assert(gap >= TokenLayout.TOKEN_DIAMETER, `jail seats {seat} and {other} overlap`)
			end
			local visitorGap = (spot - TokenLayout.spot(TokenLayout.JAIL_POSITION, other)).Magnitude
			assert(visitorGap >= TokenLayout.TOKEN_DIAMETER, `jail seat {seat} overlaps visitor {other}`)
		end
	end
	assert(not pcall(TokenLayout.jailSpot, 7), "seat 7 accepted")
end
```

`src/tests/Tokens.spec.luau` — add:

```lua
tests["walks hop forward through every tile, wrapping past Go"] = function()
	Expect.equal(table.concat(Tokens.path({ from = 38, to = 3, style = "Walk" }), ","), "39,0,1,2,3")
	Expect.equal(table.concat(Tokens.path({ from = 0, to = 2 }), ","), "1,2", "no style means walk")
end

tests["backward moves hop backward"] = function()
	Expect.equal(table.concat(Tokens.path({ from = 7, to = 4, style = "Back" }), ","), "6,5,4")
	Expect.equal(table.concat(Tokens.path({ from = 1, to = 38, style = "Back" }), ","), "0,39,38")
end

tests["going to jail is a single jump"] = function()
	Expect.equal(table.concat(Tokens.path({ from = 30, to = 10, style = "ToJail" }), ","), "10")
	Expect.equal(table.concat(Tokens.path({ from = 10, to = 10, style = "ToJail" }), ","), "10", "from just visiting")
end
```

Also add `inJail = false, jailCards = 0` to the `PLAYER` literal at the top of `Tokens.spec.luau` (PlayerView grew in Task 3).

- [ ] **Step 2: Run tests to verify they fail**

Run: `.run("Token")`. Expected: `attempt to call a nil value` for `jailSpot` / `path`.

- [ ] **Step 3: Implement**

`src/shared/Board/TokenLayout.luau` — add `TokenLayout.JAIL_POSITION = 10` after `TOKEN_DIAMETER`, refactor the tile-top math into a helper, and add jail spots:

```lua
-- Inside the jail cell: the inner half of the Jail corner (-Z, toward the board centre),
-- clear of the just-visiting spots on the outer half.
local JAIL_SPOTS = {
	Vector3.new(-2.2, 0, -2.0),
	Vector3.new(0, 0, -2.0),
	Vector3.new(2.2, 0, -2.0),
	Vector3.new(-2.2, 0, -3.9),
	Vector3.new(0, 0, -3.9),
	Vector3.new(2.2, 0, -3.9),
}

local function tileTop(position: number): CFrame
	local placement = Layout.getTilePlacement(position)
	return Layout.ORIGIN * placement.cframe * CFrame.new(0, placement.size.Y / 2, 0)
end

local function checkSeat(seat: number)
	assert(seat % 1 == 0 and seat >= 1 and seat <= TokenLayout.MAX_SEATS, `invalid seat {seat}`)
end

function TokenLayout.spot(position: number, seat: number): Vector3
	checkSeat(seat)
	return tileTop(position):PointToWorldSpace(SPOTS[seat])
end

function TokenLayout.jailSpot(seat: number): Vector3
	checkSeat(seat)
	return tileTop(TokenLayout.JAIL_POSITION):PointToWorldSpace(JAIL_SPOTS[seat])
end
```

`src/client/Tokens.luau`:

- `Token` type: add `inJail: boolean`; the queue element type becomes `{ from: number, to: number, style: string? }`.
- `standingCFrame(position: number, seat: number, jailed: boolean?)`:

```lua
local function standingCFrame(position: number, seat: number, jailed: boolean?): CFrame
	local spot = if jailed then TokenLayout.jailSpot(seat) else TokenLayout.spot(position, seat)
	-- Cylinders lie along X; rotate so the token stands upright.
	return CFrame.new(spot + Vector3.new(0, TOKEN_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
end
```

- `hop(token: Token, goal: CFrame)` — take the goal CFrame instead of a position (drop its first line).
- Add the pure path function above `runQueue`:

```lua
-- The tiles a token hops through to play out a Moved event.
function Tokens.path(move: { from: number, to: number, style: string? }): { number }
	if move.style == "ToJail" then
		return { move.to }
	end
	local direction = if move.style == "Back" then -1 else 1
	local steps = (direction * (move.to - move.from)) % Tiles.COUNT
	local path = {}
	for step = 1, steps do
		table.insert(path, (move.from + direction * step) % Tiles.COUNT)
	end
	return path
end
```

- `runQueue` loop body:

```lua
			local move = table.remove(token.queue, 1) :: { from: number, to: number, style: string? }
			for _, position in Tokens.path(move) do
				hop(token, standingCFrame(position, token.seat, move.style == "ToJail"))
			end
```

and the settle line becomes `token.part.CFrame = standingCFrame(token.position, token.seat, token.inJail)`.

- In `apply`: a new token is created exactly as today (at `Tokens.startPosition`, not jailed) with `inJail = player.inJail` in its table; the idle snap / settle moves a jailed token into the cell. Every update sets `token.inJail = player.inJail`. Queue insert: `{ from = event.from, to = event.to, style = event.style }`. The idle snap uses `standingCFrame(token.position, token.seat, token.inJail)`.

`src/client/Hud/HudView.luau`:

- Require `local Cards = require(ReplicatedStorage.Shared.Board.Cards)`. Constants:

```lua
local CARD_SECONDS = 5
local CARD_COLORS = {
	Chance = Color3.fromRGB(247, 148, 29),
	CommunityChest = Color3.fromRGB(125, 190, 230),
}
local CARD_TEXT_COLOR = Color3.fromRGB(20, 20, 20)
```

- Add fields to the type: `card: Frame, cardTitle: TextLabel, cardText: TextLabel, cardShown: number`.
- In `new`, before `return self`:

```lua
	-- Drawn card popup, under the top edge.
	local card = panel("Card", UDim2.fromOffset(360, 130), UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0), gui)
	card.BackgroundTransparency = 0
	card.Visible = false
	self.cardTitle = text("Title", card, UDim2.new(1, -16, 0, 30), 22)
	self.cardTitle.Position = UDim2.fromOffset(8, 8)
	self.cardTitle.TextColor3 = CARD_TEXT_COLOR
	self.cardText = text("Text", card, UDim2.new(1, -16, 1, -48), 17)
	self.cardText.Position = UDim2.fromOffset(8, 40)
	self.cardText.TextColor3 = CARD_TEXT_COLOR
	self.card = card
```

(initialise `card = nil :: any, cardTitle = nil :: any, cardText = nil :: any, cardShown = 0` in the `setmetatable` literal).

- Method:

```lua
function HudView.showCard(self: HudView, deck: string, body: string)
	self.cardShown += 1
	local shown = self.cardShown
	self.card.BackgroundColor3 = CARD_COLORS[deck] or PANEL_COLOR
	self.cardTitle.Text = Cards.DECK_TITLES[deck] or deck
	self.cardText.Text = body
	self.card.Visible = true
	task.delay(CARD_SECONDS, function()
		if self.cardShown == shown then
			self.card.Visible = false
		end
	end)
end
```

- In `render`, when `snapshot` is nil also hide the card: `self.card.Visible = self.card.Visible and snapshot ~= nil`.
- Player rows: `local jail = if player.inJail then " 🔒" else ""` and `row.Text = `{marker}{player.name}{you}{jail}   ${player.money}``.

`src/client/GameClient.luau` — require `local Cards = require(ReplicatedStorage.Shared.Board.Cards)`; inside the `if update.snapshot then` block, in the events loop, add:

```lua
				if event.type == "CardDrawn" and Cards.byId[event.card] then
					hud:showCard(event.deck, Cards.byId[event.card].text)
				end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: full suite. Expected: all pass (120 + 4 = 124).

- [ ] **Step 5: Playtest**

With Rojo connected: `start_stop_play(true)`, click Start with 4 seats (3 bots). Let bots play ~3 minutes (take the human's turns: Roll / Don't buy / End turn). Check via `screen_capture` and the log panel:
- a Chance/Community Chest landing shows the colored card popup and a "drew …" log line;
- a jailed token jumps (no hopping around the board) into the inner half of the Jail corner and the player row shows 🔒;
- a token leaving jail hops out along the board;
- if the human is jailed: buttons "Try for doubles" / "Pay $50 fine" (and "Use jail card" when held); status says "Your turn — you're in jail".
- no errors in `get_console_output`.

Jail and "go back 3" may not come up naturally; if not seen in 3 minutes, note it in the follow-ups file as "not observed in playtest" rather than forcing state.

`start_stop_play(false)`.

- [ ] **Step 6: Commit**

```bash
git add src/shared/Board/TokenLayout.luau src/client src/tests
git commit -m "feat: jail cell, backward and jail token moves, card popup"
```

---

## After the tasks

- Record rulings and deferred minors in `docs/superpowers/plans/2026-09-28-jail-and-cards.followups.txt` (same format as earlier follow-up files).
- Whole-branch review (opus reviewer), fix Important findings, fast-forward `main` without checkout (`git branch -f main feat/jail-and-cards`), push.
