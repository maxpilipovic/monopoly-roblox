# Speed Options Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A turn timer (Off / Relaxed 60 s / Fast 20 s) that plays a safe default move when a human runs out of time, and an optional game length (rounds or minutes) after which the highest net worth wins.

**Architecture:**
- **The engine stays free of clocks.** It only counts rounds, reads a `timeUp` flag, and ends the game at a turn change.
- **Pure server modules:**
  - `Timeouts` picks the safe default move;
  - `TurnClock` decides when a decision's deadline starts or resets.
- **`GameService` owns real time.** It runs one `task.delay` per deadline, tagged with a generation number, plus one delay for the minutes limit.
- **A shared `MatchSettings` module** holds the presets. The lobby and the server validate against it.

**Tech Stack:** Luau (`--!strict`), Rojo 7.7, in-Studio test runner, Studio MCP for playtests.

**Spec:** `docs/superpowers/specs/2026-09-29-speed-options-design.md` (read it; this plan implements it).

## Global Constraints

- **Timer presets:** `Off` = 0 s, `Relaxed` = 60 s, `Fast` = 20 s. Default `Relaxed`. An auction bid gets `math.ceil(timerSeconds / 3)`.
- **Length ids:** `Off`, `Rounds15`, `Rounds25`, `Rounds40`, `Minutes30`, `Minutes45`, `Minutes60`. Default `Off`. One limit at most.
- **Cycle order** is exactly as listed above, wrapping round.
- **Labels:** "Timer: Relaxed 60 s", "Timer: Fast 20 s", "Timer: Off", "Length: 25 rounds", "Length: 30 min", "Length: Off".
- **Timeout defaults:**

  | Phase | Default |
  |---|---|
  | Roll | `Roll` |
  | BuyDecision | `Decline` |
  | Auction | `PassBid` |
  | EndTurn | `EndTurn` |
  | Trade | `DeclineTrade` |
  | Debt | `PayDebt` if affordable, else `Bot.raiseCash`, else `Bankrupt` |

  In Debt, one timeout keeps going while the same player is the acting debtor, for at most `GameSession.MAX_TIMEOUT_STEPS = 100` moves. Anywhere else, one timeout is one move.
- **Timer rules:**
  - The deadline restarts when the key (`actor .. "|" .. phase`) changes, or when the acting player makes a successful move.
  - There is no deadline for bots, with the timer Off, or at GameOver.
- **Game length:**
  - Games end only in `endTurn`: the round limit (`round > roundLimit`) is checked first, then `timeUp`.
  - The winner is the highest net worth among non-bankrupt players, with ties to the earlier seat.
  - `GameOver.reason` is `"Bankruptcy" | "RoundLimit" | "TimeLimit"`, also stored as `state.winReason`.
- **Log and results text:** "Round limit reached — {name} wins!", "Time's up — {name} wins!"; a bankruptcy ending stays "{name} wins!". (The dash is an em dash, U+2014, with spaces.)
- **Countdown:** "m:ss", never below 0:00, urgent in the last 5 seconds. The status reads "{status} · {countdown}".
- **Match line:**
  - "Fast · Round 7 of 25", "Relaxed · 23:10 left", "Relaxed · Final turn", "Fast";
  - the timer part is omitted when Off; nil when both are Off.
- **Time source:** `workspace:GetServerTimeNow()` on the server (deadlines) and on the client (countdown).
- **Studio-only `workspace` attributes:** `TimerSeconds`, `LimitMinutes`, `RoundLimit`, beside the existing `StartingMoney`.
- Every new `.luau` file starts with `--!strict`. Tabs.

## Review Focus

1. **A tampered Start request:** a string for `seats`, a number for `timer`, "fast" in lower case, `length = "Rounds99"`, or no settings at all. It must start a normal game with the defaults. Pinned by MatchSettings.spec "validate keeps known ids and replaces anything else with the default".
2. **The minutes limit runs out while a trade offer is open, or while a debt is being paid.** The receiver still answers and the debtor still settles; the game ends only when the turn passes. Pinned by Limits.spec "time running out waits for a debt and an open trade".
3. **A human who leaves mid-countdown becomes a bot.** Their deadline must vanish, so the server never plays a timeout for a bot seat, and the bot moves at bot speed. Pinned by TurnClock.spec "a human replaced by a bot stops the clock".
4. **A timed-out human in debt with nothing left to sell or mortgage** goes bankrupt in that one timeout, and the game ends cleanly if they were the last human. Pinned by GameSession.spec "a timeout with nothing to raise goes bankrupt".
5. **The round display after the last round:** `round` is `roundLimit + 1` at GameOver. The match line must not say "Round 26 of 25". Pinned by HudModel.spec "the match line shows the timer and the limit".

## File Structure

```
src/shared/Rules/MatchSettings.luau   (create) presets, validate, cycle, labels, seconds, limits
src/server/Game/Types.luau            (modify) round, roundLimit, timeUp, winReason
src/server/Game/Engine.luau           (modify) roundLimit arg, round counting, finishGame, markTimeUp
src/server/Game/Bot.luau              (modify) raiseCash made public
src/server/Game/Timeouts.luau         (create) defaultAction
src/server/Game/GameSession.luau      (modify) settings/endsAt on Session, timeout, markTimeUp
src/server/Game/TurnClock.luau        (create) Clock, new, update
src/server/Game/Snapshot.luau         (modify) match view, winReason
src/shared/Net/Protocol.luau          (modify) MatchView, Snapshot.match/winReason
src/client/Hud/EventText.luau         (modify) WIN_PREFIX, GameOver lines by reason
src/client/Hud/HudModel.luau          (modify) countdown, matchLine, GameOver status by reason
src/client/Hud/HudView.luau           (modify) lobby setting buttons, countdown + match line on Heartbeat
src/client/GameClient.luau            (modify) send settings with Start
src/server/GameService.luau           (modify) validate settings, clock scheduling, minutes limit, Studio attributes
src/tests/GameFixtures.luau           (modify) new state fields in bareState
src/tests/MatchSettings.spec.luau, Limits.spec.luau, Timeouts.spec.luau, TurnClock.spec.luau (create)
src/tests/GameSession.spec.luau, Snapshot.spec.luau, HudModel.spec.luau, EventText.spec.luau (modify)
```

No project-file changes, so no Rojo restart.

## How to run the tests

Studio MCP:
1. `start_stop_play(true)`
2. `execute_luau(Server, 'return require(game.ServerStorage.Tests.TestRunner).run()')`. Pass a filter string for one group; it matches a substring of the spec module's name, e.g. `"Limits"`.
3. `start_stop_play(false)`

**Before every run**, check with `execute_luau(Edit, ...)` that each file edited since the last run has its newest snippet in `.Source`. Rojo sometimes misses a patch, or dies. If nothing is listening on port 34872, ask the user to restart `rojo serve`.

Baseline: 233 passed, 0 failed.

## Useful board facts

- 1 Mediterranean and 3 Baltic ($60 each, mortgage 30, house $50) form the brown set.
- 6 Oriental Avenue ($100).
- 10 is Jail / Just Visiting.
- 13 States Avenue ($140).
- 39 Boardwalk ($400).
- Net worth = cash + price per unmortgaged deed (mortgage value if mortgaged) + houses × house price.

---

### Task 1: MatchSettings

**Files:**
- Create: `src/shared/Rules/MatchSettings.luau`, `src/tests/MatchSettings.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `MatchSettings.Settings = { timer: string, length: string }`
  - `MatchSettings.DEFAULT: Settings` (frozen: `{ timer = "Relaxed", length = "Off" }`)
  - `MatchSettings.validate(raw: any): Settings` (always a fresh table)
  - `MatchSettings.nextTimer(id: string): string`, `MatchSettings.nextLength(id: string): string`
  - `MatchSettings.timerLabel(id: string): string`, `MatchSettings.lengthLabel(id: string): string`
  - `MatchSettings.timerSeconds(settings: Settings): number`, `MatchSettings.bidSeconds(timerSeconds: number): number`
  - `MatchSettings.roundLimit(settings: Settings): number?`, `MatchSettings.limitMinutes(settings: Settings): number?`

- [ ] **Step 1: Write the failing tests**

Create `src/tests/MatchSettings.spec.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["defaults are a relaxed timer and no length limit"] = function()
	Expect.equal(MatchSettings.DEFAULT.timer, "Relaxed")
	Expect.equal(MatchSettings.DEFAULT.length, "Off")
end

tests["validate keeps known ids and replaces anything else with the default"] = function()
	local chosen = MatchSettings.validate({ timer = "Fast", length = "Minutes30", seats = 4 })
	Expect.equal(chosen.timer, "Fast", "timer")
	Expect.equal(chosen.length, "Minutes30", "length")

	local fromNil = MatchSettings.validate(nil)
	Expect.equal(fromNil.timer, "Relaxed", "nil timer")
	Expect.equal(fromNil.length, "Off", "nil length")
	for i, raw in {
		5,
		"Fast",
		{},
		{ timer = 20, length = true },
		{ timer = "fast", length = "Rounds99" },
		{ timer = "__index", length = "" },
	} :: { any } do
		local settings = MatchSettings.validate(raw)
		Expect.equal(settings.timer, "Relaxed", `garbage #{i} timer`)
		Expect.equal(settings.length, "Off", `garbage #{i} length`)
	end
	assert(MatchSettings.validate(nil) ~= MatchSettings.DEFAULT, "must be a fresh table")
end

tests["cycling goes through every option in order and wraps round"] = function()
	local timers = { "Off" }
	for _ = 1, 3 do
		table.insert(timers, MatchSettings.nextTimer(timers[#timers]))
	end
	Expect.equal(table.concat(timers, ","), "Off,Relaxed,Fast,Off")

	local lengths = { "Off" }
	for _ = 1, 7 do
		table.insert(lengths, MatchSettings.nextLength(lengths[#lengths]))
	end
	Expect.equal(table.concat(lengths, ","), "Off,Rounds15,Rounds25,Rounds40,Minutes30,Minutes45,Minutes60,Off")
end

tests["seconds, limits and labels"] = function()
	Expect.equal(MatchSettings.timerSeconds({ timer = "Relaxed", length = "Off" }), 60, "relaxed")
	Expect.equal(MatchSettings.timerSeconds({ timer = "Fast", length = "Off" }), 20, "fast")
	Expect.equal(MatchSettings.timerSeconds({ timer = "Off", length = "Off" }), 0, "off")
	Expect.equal(MatchSettings.bidSeconds(60), 20, "relaxed bid")
	Expect.equal(MatchSettings.bidSeconds(20), 7, "fast bid")

	Expect.equal(MatchSettings.roundLimit({ timer = "Off", length = "Rounds25" }), 25, "rounds")
	Expect.equal(MatchSettings.roundLimit({ timer = "Off", length = "Minutes30" }), nil, "minutes has no round limit")
	Expect.equal(MatchSettings.limitMinutes({ timer = "Off", length = "Minutes45" }), 45, "minutes")
	Expect.equal(MatchSettings.limitMinutes({ timer = "Off", length = "Off" }), nil, "no limit")

	Expect.equal(MatchSettings.timerLabel("Relaxed"), "Timer: Relaxed 60 s")
	Expect.equal(MatchSettings.timerLabel("Fast"), "Timer: Fast 20 s")
	Expect.equal(MatchSettings.timerLabel("Off"), "Timer: Off")
	Expect.equal(MatchSettings.lengthLabel("Rounds25"), "Length: 25 rounds")
	Expect.equal(MatchSettings.lengthLabel("Minutes30"), "Length: 30 min")
	Expect.equal(MatchSettings.lengthLabel("Off"), "Length: Off")
end

return tests
```

- [ ] **Step 2: Run tests to verify they fail**

Run with filter `"MatchSettings"`.
Expected: `FAIL MatchSettings.spec (load)` (module missing).

- [ ] **Step 3: Implement**

Create `src/shared/Rules/MatchSettings.luau`:

```lua
--!strict
-- The speed options picked in the lobby: a turn timer and an optional game length.
-- Shared so the lobby shows the same choices the server accepts.

export type Settings = {
	timer: string, -- "Off" | "Relaxed" | "Fast"
	length: string, -- "Off" | "Rounds15" | "Rounds25" | "Rounds40" | "Minutes30" | "Minutes45" | "Minutes60"
}

local MatchSettings = {}

local TIMERS = { "Off", "Relaxed", "Fast" }
local TIMER_SECONDS = { Off = 0, Relaxed = 60, Fast = 20 }
local LENGTHS = { "Off", "Rounds15", "Rounds25", "Rounds40", "Minutes30", "Minutes45", "Minutes60" }
local ROUNDS = { Rounds15 = 15, Rounds25 = 25, Rounds40 = 40 }
local MINUTES = { Minutes30 = 30, Minutes45 = 45, Minutes60 = 60 }

MatchSettings.DEFAULT = table.freeze({ timer = "Relaxed", length = "Off" }) :: Settings

local function isOneOf(value: any, options: { string }): boolean
	return typeof(value) == "string" and table.find(options, value) ~= nil
end

function MatchSettings.validate(raw: any): Settings
	local timer = if typeof(raw) == "table" and isOneOf(raw.timer, TIMERS) then raw.timer else MatchSettings.DEFAULT.timer
	local length = if typeof(raw) == "table" and isOneOf(raw.length, LENGTHS) then raw.length else MatchSettings.DEFAULT.length
	return { timer = timer, length = length }
end

local function nextIn(options: { string }, id: string): string
	local index = table.find(options, id) or 0
	return options[index % #options + 1]
end

function MatchSettings.nextTimer(id: string): string
	return nextIn(TIMERS, id)
end

function MatchSettings.nextLength(id: string): string
	return nextIn(LENGTHS, id)
end

function MatchSettings.timerLabel(id: string): string
	local seconds = TIMER_SECONDS[id]
	return if seconds and seconds > 0 then `Timer: {id} {seconds} s` else "Timer: Off"
end

function MatchSettings.lengthLabel(id: string): string
	if ROUNDS[id] then
		return `Length: {ROUNDS[id]} rounds`
	elseif MINUTES[id] then
		return `Length: {MINUTES[id]} min`
	end
	return "Length: Off"
end

function MatchSettings.timerSeconds(settings: Settings): number
	return TIMER_SECONDS[settings.timer] or 0
end

-- An auction bid gets a third of the timer, so a table of bidders doesn't take minutes.
function MatchSettings.bidSeconds(timerSeconds: number): number
	return math.ceil(timerSeconds / 3)
end

function MatchSettings.roundLimit(settings: Settings): number?
	return ROUNDS[settings.length]
end

function MatchSettings.limitMinutes(settings: Settings): number?
	return MINUTES[settings.length]
end

return MatchSettings
```

- [ ] **Step 4: Run the full suite (sync check first)**

Expected: all pass, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Rules/MatchSettings.luau src/tests/MatchSettings.spec.luau
git commit -m "feat: match settings for the turn timer and game length"
```

---

### Task 2: Game length in the engine

**Files:**
- Modify: `src/server/Game/Types.luau`, `src/server/Game/Engine.luau`, `src/tests/GameFixtures.luau`
- Create: `src/tests/Limits.spec.luau`

**Interfaces:**
- Consumes: the engine's `endTurn`, `endIfOver`, `emit`, `PropertyRules.netWorth`.
- Produces:
  - `GameState.round: number`, `GameState.roundLimit: number?`, `GameState.timeUp: boolean`, `GameState.winReason: string?`
  - `Engine.new(players, rollDice, shuffle: Types.Shuffler?, roundLimit: number?)`
  - `Engine.markTimeUp(state: GameState)`
  - event `GameOver { winner, reason }` with reason `"Bankruptcy" | "RoundLimit" | "TimeLimit"`

- [ ] **Step 1: Types and fixtures**

`Types.luau`, in `GameState` after `tradeOffers`:

```lua
	round: number, -- starts at 1; goes up each time play wraps back to an earlier seat
	roundLimit: number?, -- the game ends once round passes this
	timeUp: boolean, -- the minutes limit ran out; the game ends at the next turn change
	winReason: string?, -- how the game ended: "Bankruptcy" | "RoundLimit" | "TimeLimit"
```

`GameFixtures.luau`, in `bareState` after `tradeOffers = {},`:

```lua
		round = 1,
		roundLimit = nil,
		timeUp = false,
		winReason = nil,
```

`Engine.luau`, the `Engine.new` state literal after `tradeOffers = {},`:

```lua
		round = 1,
		roundLimit = roundLimit,
		timeUp = false,
		winReason = nil,
```

and change the signature to `function Engine.new(players: { PlayerInfo }, rollDice: Types.DiceRoller, shuffle: Types.Shuffler?, roundLimit: number?): GameState`.

- [ ] **Step 2: Write the failing tests**

Create `src/tests/Limits.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function player(state, id: string): any
	return Engine.getPlayer(state, id) :: any
end

-- Ends the current player's turn straight away (these tests don't need the roll).
local function pass(state)
	state.phase = "EndTurn"
	act(state, Engine.currentPlayer(state).id, { type = "EndTurn" })
end

tests["new games start in round 1 and take a round limit"] = function()
	local infos = { { id = "a", name = "A", isBot = false }, { id = "b", name = "B", isBot = false } }
	local state = Engine.new(infos, GameFixtures.scriptedDice({}), nil, 25)
	Expect.equal(state.round, 1, "round")
	Expect.equal(state.roundLimit, 25, "limit")
	Expect.equal(state.timeUp, false, "time")
	Expect.equal(Engine.new(infos, GameFixtures.scriptedDice({})).roundLimit, nil, "no limit by default")
end

tests["rounds count up when play wraps back to the first seat"] = function()
	local state = GameFixtures.newGame(3)
	pass(state)
	pass(state)
	Expect.equal(state.round, 1, "p3's turn is still round 1")
	pass(state)
	Expect.equal(state.round, 2, "back to p1")
end

tests["a wrap past bankrupt seats still counts one round"] = function()
	local state = GameFixtures.newGame(3)
	player(state, "p1").bankrupt = true
	state.currentIndex = 2
	pass(state) -- p2 -> p3
	Expect.equal(state.round, 1)
	pass(state) -- p3 -> (p1 skipped) -> p2
	Expect.equal(Engine.currentPlayer(state).id, "p2")
	Expect.equal(state.round, 2)
end

tests["the round limit ends the game after the last turn of the last round"] = function()
	local state = GameFixtures.newGame(2)
	state.roundLimit = 2
	GameFixtures.own(state, "p2", 39)
	pass(state) -- p1 -> p2
	pass(state) -- round 2
	pass(state) -- p1 -> p2
	Expect.equal(state.phase, "Roll", "p2 still plays round 2")
	pass(state)
	Expect.equal(state.phase, "GameOver")
	Expect.equal(state.winner, "p2", "Boardwalk makes p2 richer")
	Expect.equal(state.winReason, "RoundLimit")
	Expect.equal(GameFixtures.eventsOfType(state, "GameOver")[1].reason, "RoundLimit", "event")
	Expect.equal(#GameFixtures.eventsOfType(state, "TurnStarted"), 4, "no turn starts after the limit")
end

tests["at a limit, ties go to the earlier seat and bankrupt players can't win"] = function()
	local state = GameFixtures.newGame(3)
	player(state, "p1").bankrupt = true
	player(state, "p1").money = 5000
	state.currentIndex = 2
	Engine.markTimeUp(state)
	pass(state)
	Expect.equal(state.phase, "GameOver")
	Expect.equal(state.winner, "p2", "p2 and p3 tie on $1500")
	Expect.equal(state.winReason, "TimeLimit")
end

tests["time running out lets the current turn finish, doubles included"] = function()
	local state = GameFixtures.newGame(2, { { 5, 5 }, { 2, 1 } })
	Engine.markTimeUp(state)
	act(state, "p1", { type = "Roll" }) -- doubles: just visiting jail
	Expect.equal(state.phase, "Roll", "doubles roll again")
	act(state, "p1", { type = "Roll" }) -- States Avenue
	act(state, "p1", { type = "Buy" })
	Expect.equal(state.phase, "EndTurn", "still p1's turn")
	act(state, "p1", { type = "EndTurn" })
	Expect.equal(state.phase, "GameOver")
	Expect.equal(state.winner, "p1", "$1360 + States Avenue $140 ties p2's $1500; earlier seat wins")
end

tests["time running out waits for a debt and an open trade"] = function()
	local state = GameFixtures.newGame(2)
	state.phase = "EndTurn"
	GameFixtures.inDebt(state, "p1", 100)
	Engine.markTimeUp(state)
	act(state, "p1", { type = "PayDebt" })
	Expect.equal(state.phase, "EndTurn", "back to p1's turn")
	assert(GameFixtures.propose(state, "p1", "p2", GameFixtures.side(nil, 10), GameFixtures.side()))
	act(state, "p2", { type = "DeclineTrade" })
	Expect.equal(state.phase, "EndTurn", "the offer was answered")
	act(state, "p1", { type = "EndTurn" })
	Expect.equal(state.phase, "GameOver")
	Expect.equal(state.winReason, "TimeLimit")
end

tests["a bankruptcy ending says so"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.inDebt(state, "p1", 5000)
	act(state, "p1", { type = "Bankrupt" })
	Expect.equal(state.phase, "GameOver")
	Expect.equal(state.winReason, "Bankruptcy")
	Expect.equal(GameFixtures.eventsOfType(state, "GameOver")[1].reason, "Bankruptcy", "event")
end

tests["marking time up after the game is over changes nothing"] = function()
	local state = GameFixtures.newGame(2)
	state.roundLimit = 1
	pass(state)
	pass(state)
	Expect.equal(state.phase, "GameOver")
	Engine.markTimeUp(state)
	Expect.equal(state.timeUp, false)
	Expect.equal(state.winReason, "RoundLimit")
end

return tests
```

- [ ] **Step 3: Run tests to verify they fail**

Run with filter `"Limits"`.
Expected: failures such as `round: expected 1, got nil`, `attempt to call a nil value` (`markTimeUp`), and `phase: expected GameOver, got Roll`. "a bankruptcy ending says so" fails on `winReason`.

- [ ] **Step 4: Implement**

In `Engine.luau`:

a) Add `finishGame` directly above `local function endTurn`. `endTurn` needs it, and `endIfOver`, further down, can see it too:

```lua
-- Ends the game: the richest player still in wins (ties go to the earlier seat).
local function finishGame(state: GameState, reason: string)
	local winner: Player?, best = nil, -math.huge
	for _, other in state.players do
		if not other.bankrupt then
			local worth = PropertyRules.netWorth(state, other.id, other.money)
			if worth > best then -- strictly greater: ties go to the earlier seat
				winner, best = other, worth
			end
		end
	end
	state.phase = "GameOver"
	state.winner = (winner :: Player).id
	state.winReason = reason
	state.debts = {}
	state.auctionQueue = {}
	state.resumePhase = nil
	emit(state, { type = "GameOver", winner = state.winner, reason = reason })
end
```

and `endIfOver` keeps its solvency check and hands the ending to `finishGame`:

```lua
local function endIfOver(state: GameState, bankrupt: Player): boolean
	local solvent, humans = 0, 0
	for _, other in state.players do
		if not other.bankrupt then
			solvent += 1
			if not other.isBot then
				humans += 1
			end
		end
	end
	if solvent > 1 and (bankrupt.isBot or humans > 0) then
		return false
	end
	finishGame(state, "Bankruptcy")
	return true
end
```

b) `endTurn` becomes:

```lua
local function endTurn(state: GameState)
	state.lastRoll = nil
	state.doublesCount = 0
	state.rollAgain = false
	state.resumePhase = nil
	table.clear(state.tradeOffers)
	local previous = state.currentIndex
	for _ = 1, #state.players do
		state.currentIndex = state.currentIndex % #state.players + 1
		if not Engine.currentPlayer(state).bankrupt then
			break
		end
	end
	if state.currentIndex <= previous then
		state.round += 1
	end
	-- A game length limit ends the game here, between turns, so nobody is cut off mid-move.
	if state.roundLimit and state.round > state.roundLimit then
		finishGame(state, "RoundLimit")
		return
	elseif state.timeUp then
		finishGame(state, "TimeLimit")
		return
	end
	state.phase = "Roll"
	emit(state, { type = "TurnStarted", player = Engine.currentPlayer(state).id })
end
```

c) Add, next to `Engine.actingPlayer`:

```lua
-- The minutes limit ran out: the game ends at the next turn change.
function Engine.markTimeUp(state: GameState)
	if state.phase ~= "GameOver" then
		state.timeUp = true
	end
end
```

- [ ] **Step 5: Run the full suite (sync check first)**

Expected: all pass, 0 failed. The existing Bankruptcy specs still pass, because `finishGame` keeps the old winner rule.

- [ ] **Step 6: Commit**

```bash
git add src/server/Game/Types.luau src/server/Game/Engine.luau src/tests/GameFixtures.luau src/tests/Limits.spec.luau
git commit -m "feat: round and time limits end the game at a turn change"
```

---

### Task 3: Safe default moves and session timeouts

**Files:**
- Modify: `src/server/Game/Bot.luau`, `src/server/Game/GameSession.luau`
- Create: `src/server/Game/Timeouts.luau`, `src/tests/Timeouts.spec.luau`
- Test: `src/tests/GameSession.spec.luau`

**Interfaces:**
- Consumes: `Engine.actingPlayer/getPlayer/act/markTimeUp`, `Engine.new(..., roundLimit)`, `MatchSettings.DEFAULT/roundLimit/Settings`.
- Produces:
  - `Bot.raiseCash(state, me: Types.Player): Types.Action?` (was a local)
  - `Timeouts.defaultAction(state, playerId: string): Types.Action?`
  - `GameSession.Session` gains `settings: MatchSettings.Settings` and `endsAt: number?`
  - `GameSession.new(humans, seats, rollDice, shuffle?, settings?: MatchSettings.Settings)` (the round limit comes from `settings`)
  - `GameSession.MAX_TIMEOUT_STEPS = 100`
  - `GameSession.timeout(session, playerId: string): boolean`
  - `GameSession.markTimeUp(session)`

- [ ] **Step 1: Write the failing tests**

Create `src/tests/Timeouts.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local Timeouts = require(ServerScriptService.Server.Game.Timeouts)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function default(state, playerId: string): string?
	local action = Timeouts.defaultAction(state, playerId)
	return if action then action.type else nil
end

tests["the default move in each phase is the safe one"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Expect.equal(default(state, "p1"), "Roll", "roll")
	Expect.equal(default(state, "p2"), nil, "not the acting player")
	act(state, "p1", { type = "Roll" }) -- Oriental Avenue
	Expect.equal(default(state, "p1"), "Decline", "don't buy")
	act(state, "p1", { type = "Decline" })
	Expect.equal(default(state, "p1"), "PassBid", "auction")
	act(state, "p1", { type = "PassBid" })
	act(state, "p2", { type = "PassBid" })
	Expect.equal(default(state, "p1"), "EndTurn", "end turn")
	assert(GameFixtures.propose(state, "p1", "p2", GameFixtures.side(nil, 10), GameFixtures.side()))
	Expect.equal(default(state, "p2"), "DeclineTrade", "trade")

	local jailed = GameFixtures.newGame(2)
	local p1: any = Engine.getPlayer(jailed, "p1")
	p1.inJail = true
	Expect.equal(default(jailed, "p1"), "Roll", "in jail: try for doubles")

	jailed.phase = "GameOver"
	Expect.equal(default(jailed, "p1"), nil, "nothing after the game")
end

tests["in debt the default pays, else sells, else mortgages, else goes bankrupt"] = function()
	local state = GameFixtures.newGame(2)
	local p1: any = Engine.getPlayer(state, "p1")
	GameFixtures.own(state, "p1", 1)
	GameFixtures.own(state, "p1", 3, 1)
	p1.money = 0
	GameFixtures.inDebt(state, "p1", 80)

	local sell = Timeouts.defaultAction(state, "p1") :: any
	Expect.equal(sell.type, "SellBuilding", "sell first")
	Expect.equal(sell.position, 3, "the built lot")
	act(state, "p1", sell)

	local mortgage = Timeouts.defaultAction(state, "p1") :: any
	Expect.equal(mortgage.type, "Mortgage", "then mortgage")
	act(state, "p1", mortgage) -- $55, still short of $80
	act(state, "p1", Timeouts.defaultAction(state, "p1") :: any) -- the other brown lot
	Expect.equal(p1.money, 25 + 30 + 30, "house sold for $25, two lots mortgaged for $30 each")
	Expect.equal(default(state, "p1"), "PayDebt", "now it can pay")

	local broke = GameFixtures.newGame(2)
	local b1: any = Engine.getPlayer(broke, "p1")
	b1.money = 0
	GameFixtures.inDebt(broke, "p1", 50)
	Expect.equal(default(broke, "p1"), "Bankrupt", "nothing left to raise")
end

return tests
```

In `GameSession.spec.luau`, add:

```lua
tests["a timeout plays one safe move outside a debt"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({ { 2, 4 } }))
	assert(GameSession.timeout(session, "h1"), "roll")
	Expect.equal(session.state.phase, "BuyDecision", "rolled once, didn't buy yet")
	assert(GameSession.timeout(session, "h1"), "decline")
	Expect.equal(session.state.phase, "Auction")
	assert(not GameSession.timeout(session, "bot1"), "only the acting player times out")
end

tests["a timeout settles a whole debt in one go"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({}))
	local state = session.state
	GameFixtures.own(state, "h1", 1)
	GameFixtures.own(state, "h1", 3)
	local h1: any = Engine.getPlayer(state, "h1")
	h1.money = 0
	GameFixtures.inDebt(state, "h1", 50)
	assert(GameSession.timeout(session, "h1"))
	Expect.equal(state.properties[1].mortgaged, true, "Mediterranean")
	Expect.equal(state.properties[3].mortgaged, true, "Baltic")
	Expect.equal(h1.money, 10, "$60 raised, $50 paid")
	Expect.equal(state.phase, "Roll", "back to the turn")
end

tests["a timeout with nothing to raise goes bankrupt"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({}))
	local h1: any = Engine.getPlayer(session.state, "h1")
	h1.money = 0
	GameFixtures.inDebt(session.state, "h1", 50)
	assert(GameSession.timeout(session, "h1"))
	Expect.equal(h1.bankrupt, true)
	Expect.equal(session.state.phase, "GameOver", "the last human went bankrupt")
end

tests["sessions keep their settings and take the round limit from them"] = function()
	local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({}), nil, { timer = "Fast", length = "Rounds15" })
	Expect.equal(session.settings.timer, "Fast")
	Expect.equal(session.state.roundLimit, 15)
	Expect.equal(session.endsAt, nil)
	local plain = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({}))
	Expect.equal(plain.settings.timer, "Relaxed", "default settings")
	Expect.equal(plain.state.roundLimit, nil)
	GameSession.markTimeUp(plain)
	Expect.equal(plain.state.timeUp, true)
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run with filters `"Timeouts"` and `"GameSession"`.
Expected:
- `FAIL Timeouts.spec (load)` (module missing);
- the four GameSession tests FAIL with "attempt to call a nil value" (`timeout` / `markTimeUp`) or `settings` being nil.

- [ ] **Step 3: Implement**

`Bot.luau`: change `local function raiseCash(state: Types.GameState, me: Types.Player): Types.Action?` to `function Bot.raiseCash(state: Types.GameState, me: Types.Player): Types.Action?`. Change its caller in `Bot.chooseAction` to `return Bot.raiseCash(state, me) or { type = "Bankrupt" }`.

Create `src/server/Game/Timeouts.luau`:

```lua
--!strict
-- The safe move played for a human whose turn timer ran out. It never spends their money by
-- choice: no buying, bidding or building. In debt it raises cash the way a bot would.

local Bot = require(script.Parent.Bot)
local Engine = require(script.Parent.Engine)
local Types = require(script.Parent.Types)

local Timeouts = {}

local DEFAULTS = {
	Roll = "Roll", -- in jail this tries for doubles; the engine forces the fine after the third miss
	BuyDecision = "Decline",
	Auction = "PassBid",
	EndTurn = "EndTurn",
	Trade = "DeclineTrade",
}

function Timeouts.defaultAction(state: Types.GameState, playerId: string): Types.Action?
	if Engine.actingPlayer(state) ~= playerId then
		return nil
	end
	if state.phase == "Debt" then
		local me = Engine.getPlayer(state, playerId) :: Types.Player
		if me.money >= state.debts[1].amount then
			return { type = "PayDebt" }
		end
		return Bot.raiseCash(state, me) or { type = "Bankrupt" }
	end
	local default = DEFAULTS[state.phase]
	return if default then { type = default } else nil
end

return Timeouts
```

`GameSession.luau`:

a) Requires at the top:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local Bot = require(script.Parent.Bot)
local Engine = require(script.Parent.Engine)
local Timeouts = require(script.Parent.Timeouts)
local Types = require(script.Parent.Types)
```

b) `Session` type:

```lua
export type Session = {
	state: Types.GameState,
	eventCursor: number,
	settings: MatchSettings.Settings,
	endsAt: number?, -- server time the minutes limit runs out, if there is one
}
```

and `GameSession.MAX_TIMEOUT_STEPS = 100` after `local GameSession = {}`.

c) `GameSession.new` gains `settings: MatchSettings.Settings?` as its fifth parameter. Its return becomes:

```lua
	local chosen = settings or MatchSettings.validate(nil)
	return {
		state = Engine.new(infos, rollDice, shuffle, MatchSettings.roundLimit(chosen)),
		eventCursor = 0,
		settings = chosen,
		endsAt = nil,
	}
```

d) After `GameSession.stepBot`, add:

```lua
local function playDefault(state: Types.GameState, playerId: string): boolean
	local action = Timeouts.defaultAction(state, playerId)
	if action and Engine.act(state, playerId, action) then
		return true
	end
	for _, fallback in FALLBACK_ACTIONS do
		if Engine.act(state, playerId, fallback) then
			return true
		end
	end
	return false
end

-- A human's timer ran out: play their safe default. A debt is settled in one go, so an absent
-- player doesn't cost everyone a full timer per mortgage; anywhere else it's one move.
function GameSession.timeout(session: Session, playerId: string): boolean
	local state = session.state
	if Engine.actingPlayer(state) ~= playerId then
		return false
	end
	local inDebt = state.phase == "Debt"
	if not playDefault(state, playerId) then
		return false
	end
	local steps = 1
	while
		inDebt
		and state.phase == "Debt"
		and Engine.actingPlayer(state) == playerId
		and steps < GameSession.MAX_TIMEOUT_STEPS
	do
		if not playDefault(state, playerId) then
			break
		end
		steps += 1
	end
	return true
end

function GameSession.markTimeUp(session: Session)
	Engine.markTimeUp(session.state)
end
```

`Bot` stays required, because `stepBot` uses it.

- [ ] **Step 4: Run the full suite (sync check first)**

Expected: all pass, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add src/server/Game/Bot.luau src/server/Game/Timeouts.luau src/server/Game/GameSession.luau src/tests/Timeouts.spec.luau src/tests/GameSession.spec.luau
git commit -m "feat: safe default moves for humans who run out of time"
```

---

### Task 4: Turn clock and the match in the snapshot

**Files:**
- Modify: `src/shared/Net/Protocol.luau`, `src/server/Game/Snapshot.luau`
- Create: `src/server/Game/TurnClock.luau`, `src/tests/TurnClock.spec.luau`
- Test: `src/tests/Snapshot.spec.luau`

**Interfaces:**
- Consumes: `Engine.actingPlayer/getPlayer`, `MatchSettings.bidSeconds`, `state.round/roundLimit/winReason`.
- Produces:
  - `TurnClock.Clock = { key: string?, actor: string?, deadline: number? }`
  - `TurnClock.new(): Clock`
  - `TurnClock.update(clock, state, timerSeconds: number, now: number, actedBy: string?)`
  - `Protocol.MatchView = { timer: string, length: string, round: number, roundLimit: number?, endsAt: number?, turnDeadline: number? }`
  - `Protocol.Snapshot.match: MatchView`, `Protocol.Snapshot.winReason: string?`
  - `Snapshot.MatchInfo = { timer: string, length: string, endsAt: number?, turnDeadline: number? }`
  - `Snapshot.fromState(state, info: MatchInfo?)`

- [ ] **Step 1: Write the failing tests**

Create `src/tests/TurnClock.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local TurnClock = require(ServerScriptService.Server.Game.TurnClock)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

tests["a human's decision gets a deadline that resets on their move or a new decision"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	local clock = TurnClock.new()
	TurnClock.update(clock, state, 60, 1000, nil)
	Expect.equal(clock.actor, "p1", "actor")
	Expect.equal(clock.deadline, 1060, "started")
	TurnClock.update(clock, state, 60, 1010, nil)
	Expect.equal(clock.deadline, 1060, "same decision keeps its deadline")
	TurnClock.update(clock, state, 60, 1015, "p2")
	Expect.equal(clock.deadline, 1060, "someone else's move doesn't reset it")
	TurnClock.update(clock, state, 60, 1020, "p1")
	Expect.equal(clock.deadline, 1080, "their own move restarts it")
	Engine.act(state, "p1", { type = "Roll" }) -- BuyDecision on Oriental
	TurnClock.update(clock, state, 60, 1030, nil)
	Expect.equal(clock.deadline, 1090, "a new phase restarts it")
end

tests["auction bids get a third of the timer"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	Engine.act(state, "p1", { type = "Roll" })
	Engine.act(state, "p1", { type = "Decline" })
	local clock = TurnClock.new()
	TurnClock.update(clock, state, 20, 2000, "p1")
	Expect.equal(clock.deadline, 2007, "p1 bids")
	Engine.act(state, "p1", { type = "Bid", amount = 10 })
	TurnClock.update(clock, state, 20, 2001, "p1")
	Expect.equal(clock.actor, "p2", "next bidder")
	Expect.equal(clock.deadline, 2008, "fresh deadline for p2")
end

tests["bots, a timer set to Off and a finished game get no deadline"] = function()
	local state = GameFixtures.newGame(2)
	local clock = TurnClock.new()
	TurnClock.update(clock, state, 0, 1000, nil)
	Expect.equal(clock.deadline, nil, "timer off")

	local p1: any = Engine.getPlayer(state, "p1")
	p1.isBot = true
	TurnClock.update(clock, state, 60, 1000, nil)
	Expect.equal(clock.deadline, nil, "bot")

	state.phase = "GameOver"
	TurnClock.update(clock, state, 60, 1000, nil)
	Expect.equal(clock.deadline, nil, "game over")
	Expect.equal(clock.actor, nil, "nobody acting")
end

tests["a human replaced by a bot stops the clock"] = function()
	local state = GameFixtures.newGame(2)
	local clock = TurnClock.new()
	TurnClock.update(clock, state, 60, 1000, nil)
	Expect.equal(clock.deadline, 1060)
	local p1: any = Engine.getPlayer(state, "p1")
	p1.isBot = true -- same phase, same player id: only isBot changed
	TurnClock.update(clock, state, 60, 1005, nil)
	Expect.equal(clock.deadline, nil)
end

return tests
```

`Snapshot.spec.luau`, add:

```lua
tests["snapshot carries the match settings, round and deadlines"] = function()
	local state = GameFixtures.newGame(2)
	state.roundLimit = 25
	local snapshot = Snapshot.fromState(state, { timer = "Fast", length = "Rounds25", endsAt = nil, turnDeadline = 123 })
	Expect.equal(snapshot.match.timer, "Fast", "timer")
	Expect.equal(snapshot.match.length, "Rounds25", "length")
	Expect.equal(snapshot.match.round, 1, "round")
	Expect.equal(snapshot.match.roundLimit, 25, "limit")
	Expect.equal(snapshot.match.turnDeadline, 123, "deadline")
	Expect.equal(snapshot.match.endsAt, nil, "no minutes limit")

	local plain = Snapshot.fromState(state)
	Expect.equal(plain.match.timer, "Off", "no match info")
	Expect.equal(plain.match.length, "Off")
	Expect.equal(plain.match.turnDeadline, nil)
	Expect.equal(plain.winReason, nil, "no winner yet")
	state.winReason = "TimeLimit"
	Expect.equal(Snapshot.fromState(state).winReason, "TimeLimit", "reason")
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run with filters `"TurnClock"` and `"Snapshot"`.
Expected:
- `FAIL TurnClock.spec (load)`;
- the snapshot test FAILS with "attempt to index nil with 'timer'".

- [ ] **Step 3: Implement**

Create `src/server/Game/TurnClock.luau`:

```lua
--!strict
-- When the acting human's decision times out. Pure: the caller passes the time, so it tests
-- without a real clock. A decision is one player in one phase; it gets a fresh deadline when it
-- starts, and again whenever that player makes a move (so raising cash in steps isn't rushed).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local Engine = require(script.Parent.Engine)
local Types = require(script.Parent.Types)

export type Clock = {
	key: string?, -- actor .. "|" .. phase of the decision being timed
	actor: string?, -- who the game is waiting on
	deadline: number?, -- nil = not timed (bot, timer off, game over)
}

local TurnClock = {}

function TurnClock.new(): Clock
	return { key = nil, actor = nil, deadline = nil }
end

function TurnClock.update(clock: Clock, state: Types.GameState, timerSeconds: number, now: number, actedBy: string?)
	local actor = Engine.actingPlayer(state)
	local key = if actor then `{actor}|{state.phase}` else nil
	local changed = key ~= clock.key
	clock.key = key
	clock.actor = actor
	local player = if actor then Engine.getPlayer(state, actor) else nil
	if timerSeconds <= 0 or not player or player.isBot then
		clock.deadline = nil
		return
	end
	if changed or actedBy == actor or clock.deadline == nil then
		local seconds = if state.phase == "Auction" then MatchSettings.bidSeconds(timerSeconds) else timerSeconds
		clock.deadline = now + seconds
	end
end

return TurnClock
```

`Protocol.luau`, add before the `Snapshot` type:

```lua
export type MatchView = {
	timer: string, -- MatchSettings timer id
	length: string, -- MatchSettings length id
	round: number,
	roundLimit: number?,
	endsAt: number?, -- server time the minutes limit runs out
	turnDeadline: number?, -- server time the acting human's decision times out
}
```

and add to `Snapshot`, after `tradeOffersLeft`:

```lua
	match: MatchView,
	winReason: string?, -- "Bankruptcy" | "RoundLimit" | "TimeLimit", once the game is over
```

`Snapshot.luau`:

a) After `local Snapshot = {}`:

```lua
-- What the session knows about the match beyond the engine state.
export type MatchInfo = {
	timer: string,
	length: string,
	endsAt: number?,
	turnDeadline: number?,
}

local NO_MATCH: MatchInfo = { timer = "Off", length = "Off" }
```

b) Change the signature to `function Snapshot.fromState(state: Types.GameState, info: MatchInfo?): Protocol.Snapshot`. Add to the returned table, after `tradeOffersLeft = offersLeft,`:

```lua
		match = {
			timer = (info or NO_MATCH).timer,
			length = (info or NO_MATCH).length,
			round = state.round,
			roundLimit = state.roundLimit,
			endsAt = (info or NO_MATCH).endsAt,
			turnDeadline = (info or NO_MATCH).turnDeadline,
		},
		winReason = state.winReason,
```

- [ ] **Step 4: Run the full suite (sync check first)**

Expected: all pass, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add src/server/Game/TurnClock.luau src/shared/Net/Protocol.luau src/server/Game/Snapshot.luau src/tests/TurnClock.spec.luau src/tests/Snapshot.spec.luau
git commit -m "feat: turn clock deadlines and the match in the snapshot"
```

---

### Task 5: Countdown, match line and game-over text

**Files:**
- Modify: `src/client/Hud/EventText.luau`, `src/client/Hud/HudModel.luau`
- Test: `src/tests/EventText.spec.luau`, `src/tests/HudModel.spec.luau`

**Interfaces:**
- Consumes: `Snapshot.match/winReason`, `Snapshot.fromState(state, info)`.
- Produces:
  - `EventText.WIN_PREFIX: { [string]: string }` (`RoundLimit` → "Round limit reached — ", `TimeLimit` → "Time's up — ")
  - `HudModel.countdown(snapshot, now: number): (string?, boolean)`
  - `HudModel.matchLine(snapshot, now: number): string?`
  - `HudModel.status` at GameOver reads "{prefix}{winner} wins!"

- [ ] **Step 1: Write the failing tests**

`EventText.spec.luau`, add to `cases` next to the existing GameOver case:

```lua
		{ { type = "GameOver", winner = "p1", reason = "Bankruptcy" }, "Ana wins!" },
		{ { type = "GameOver", winner = "p1", reason = "RoundLimit" }, "Round limit reached — Ana wins!" },
		{ { type = "GameOver", winner = "p1", reason = "TimeLimit" }, "Time's up — Ana wins!" },
```

`HudModel.spec.luau`, add:

```lua
local function snapshotWith(info)
	return Snapshot.fromState(GameFixtures.newGame(2), info)
end

tests["the countdown shows minutes and seconds and turns urgent in the last five"] = function()
	local snapshot = snapshotWith({ timer = "Fast", length = "Off", turnDeadline = 100 })
	local text, urgent = HudModel.countdown(snapshot, 58.5)
	Expect.equal(text, "0:42", "rounds up")
	Expect.equal(urgent, false)
	text, urgent = HudModel.countdown(snapshot, 95.2)
	Expect.equal(text, "0:05", "five left")
	Expect.equal(urgent, true)
	text, urgent = HudModel.countdown(snapshot, 130)
	Expect.equal(text, "0:00", "never below zero")
	Expect.equal(urgent, true)
	text = HudModel.countdown(snapshotWith({ timer = "Relaxed", length = "Off", turnDeadline = 100 }), 30)
	Expect.equal(text, "1:10", "over a minute")
	text, urgent = HudModel.countdown(snapshotWith({ timer = "Fast", length = "Off" }), 30)
	Expect.equal(text, nil, "no deadline")
	Expect.equal(urgent, false)
end

tests["the match line shows the timer and the limit"] = function()
	local state = GameFixtures.newGame(2)
	state.roundLimit = 25
	state.round = 7
	Expect.equal(HudModel.matchLine(Snapshot.fromState(state, { timer = "Fast", length = "Rounds25" }), 0), "Fast · Round 7 of 25")
	state.round = 26 -- at GameOver after the last round
	Expect.equal(HudModel.matchLine(Snapshot.fromState(state, { timer = "Off", length = "Rounds25" }), 0), "Round 25 of 25", "clamped")

	local timed = snapshotWith({ timer = "Relaxed", length = "Minutes30", endsAt = 2000 })
	Expect.equal(HudModel.matchLine(timed, 2000 - 1390), "Relaxed · 23:10 left", "time left")
	Expect.equal(HudModel.matchLine(timed, 2001), "Relaxed · Final turn", "time's up")
	Expect.equal(HudModel.matchLine(snapshotWith({ timer = "Fast", length = "Off" }), 0), "Fast", "timer only")
	Expect.equal(HudModel.matchLine(snapshotWith({ timer = "Off", length = "Off" }), 0), nil, "nothing to show")
end

tests["the results title says how the game ended"] = function()
	local state = GameFixtures.newGame(2)
	state.phase = "GameOver"
	state.winner = "p2"
	state.winReason = "TimeLimit"
	Expect.equal(HudModel.status(Snapshot.fromState(state), "p1"), "Time's up — Player 2 wins!")
	state.winReason = "RoundLimit"
	Expect.equal(HudModel.status(Snapshot.fromState(state), "p1"), "Round limit reached — Player 2 wins!")
	state.winReason = "Bankruptcy"
	Expect.equal(HudModel.status(Snapshot.fromState(state), "p1"), "Player 2 wins!")
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run with filters `"EventText"` and `"HudModel"`.
Expected:
- the EventText RoundLimit and TimeLimit cases FAIL, getting "Ana wins!";
- the HudModel countdown and match-line tests FAIL with "attempt to call a nil value";
- the results-title test FAILS, getting "Player 2 wins!".

- [ ] **Step 3: Implement**

`EventText.luau`: after `local EventText = {}`:

```lua
-- How a game-over line starts, by the way the game ended; a bankruptcy ending has no prefix.
EventText.WIN_PREFIX = table.freeze({
	RoundLimit = "Round limit reached — ",
	TimeLimit = "Time's up — ",
}) :: { [string]: string }
```

and the GameOver branch becomes:

```lua
	elseif kind == "GameOver" then
		return `{EventText.WIN_PREFIX[event.reason] or ""}{name(event.winner)} wins!`
```

`HudModel.luau`:

a) In `HudModel.status`, the GameOver branch becomes:

```lua
	if snapshot.phase == "GameOver" then
		local winner = snapshot.winner
		local prefix = EventText.WIN_PREFIX[snapshot.winReason or ""] or ""
		return `{prefix}{if winner then names[winner] or winner else "Nobody"} wins!`
	end
```

b) Add after `HudModel.status`:

```lua
HudModel.URGENT_SECONDS = 5

local function clockText(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Time left on the acting human's decision, e.g. "0:14", and whether it's nearly up.
function HudModel.countdown(snapshot: Protocol.Snapshot, now: number): (string?, boolean)
	local deadline = snapshot.match.turnDeadline
	if not deadline then
		return nil, false
	end
	local left = math.max(0, math.ceil(deadline - now))
	return clockText(left), left <= HudModel.URGENT_SECONDS
end

-- The speed options in play, e.g. "Fast · Round 7 of 25" or "Relaxed · 23:10 left".
function HudModel.matchLine(snapshot: Protocol.Snapshot, now: number): string?
	local match = snapshot.match
	local parts = {}
	if match.timer ~= "Off" then
		table.insert(parts, match.timer)
	end
	if match.roundLimit then
		table.insert(parts, `Round {math.min(match.round, match.roundLimit)} of {match.roundLimit}`)
	elseif match.endsAt then
		local left = math.ceil(match.endsAt - now)
		table.insert(parts, if left > 0 then `{clockText(left)} left` else "Final turn")
	end
	return if #parts > 0 then table.concat(parts, " · ") else nil
end
```

- [ ] **Step 4: Run the full suite (sync check first)**

Expected: all pass, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add src/client/Hud/EventText.luau src/client/Hud/HudModel.luau src/tests/EventText.spec.luau src/tests/HudModel.spec.luau
git commit -m "feat: countdown, match line and game-over text by reason"
```

---

### Task 6: Wire it up: lobby, server clock and HUD

**Files:**
- Modify: `src/server/GameService.luau`, `src/client/GameClient.luau`, `src/client/Hud/HudView.luau`

**Interfaces:**
- Consumes: all of `MatchSettings`, `TurnClock.new/update/Clock`, `GameSession.new(..., settings)/timeout/markTimeUp/Session.settings/endsAt`, `Snapshot.fromState(state, info)`, `HudModel.countdown/matchLine`.
- Produces: the playable feature. There are no new modules; this is wiring, verified by playtest.

- [ ] **Step 1: Server**

`GameService.luau`:

a) Requires, after `Snapshot`:

```lua
local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)
local TurnClock = require(script.Parent.Game.TurnClock)
```

b) Module state, after `local scheduleLobbyReturn: () -> ()`:

```lua
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
```

c) `currentUpdate` becomes:

```lua
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
```

d) In `scheduleBots`, the success branch becomes:

```lua
		if session and GameSession.stepBot(session) then
			refreshClock(nil)
			broadcast()
			scheduleBots()
		end
```

e) After `scheduleBots`, add:

```lua
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
	local deadline, actor = clock.deadline, clock.actor
	if not deadline or not actor then
		return
	end
	local generation = clockGeneration
	task.delay(math.max(deadline - now, 0), function()
		if session ~= current or generation ~= clockGeneration then
			return
		end
		if GameSession.timeout(current, actor) then
			refreshClock(actor)
			broadcast()
			scheduleBots()
		else
			warn(`timeout for {actor} in phase {current.state.phase} did nothing`)
		end
	end)
end
```

f) `onAction` becomes:

```lua
local function onAction(player: Player, action: any)
	local playerId = tostring(player.UserId)
	if session and GameSession.act(session, playerId, action) then
		refreshClock(playerId)
		broadcast()
		scheduleBots()
	end
end
```

g) In `onLobbyRequest`, the start path becomes (the humans list and the `StartingMoney` block stay as they are):

```lua
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
```

h) In `onPlayerRemoving`, call `refreshClock(nil)` right before `broadcast()`. The new bot seat then loses its deadline; if the session ended, the generation bump cancels any check.

- [ ] **Step 2: Client**

`GameClient.luau`, `onStart` becomes:

```lua
		onStart = function(seats, settings)
			lobbyRemote:FireServer({ type = "Start", seats = seats, timer = settings.timer, length = settings.length })
		end,
```

`HudView.luau`:

a) Require `local MatchSettings = require(ReplicatedStorage.Shared.Rules.MatchSettings)`. Add the constant `local URGENT_COLOR = Color3.fromRGB(255, 90, 90)` next to the other colours.

b) `Callbacks.onStart` becomes `onStart: (seats: number, settings: MatchSettings.Settings) -> (),`.

c) The `HudView` type gains:

```lua
		settings: MatchSettings.Settings,
		statusText: string,
		statusColor: Color3,
		matchLabel: TextLabel?,
```

and `new` initialises them with `settings = MatchSettings.validate(nil), statusText = "", statusColor = TEXT_COLOR, matchLabel = nil,`.

d) Lobby: change the lobby panel size to `UDim2.fromOffset(320, 250)`. Give `seatsLabel` `LayoutOrder = 1` and `seatRow` `LayoutOrder = 2`. The Start button sends the settings:

```lua
	button("Start game", seatRow, function()
		callbacks.onStart(self.seats, table.clone(self.settings))
	end)
```

and after `changeSeats(0)`, add:

```lua
	-- Speed options: each button cycles through its choices.
	local function settingButton(order: number, label: () -> string, cycle: () -> ())
		local b: TextButton
		b = button(label(), lobby, function()
			cycle()
			b.Text = label()
		end)
		b.Size = UDim2.fromOffset(260, 40)
		b.LayoutOrder = order
		b.BackgroundColor3 = TOGGLE_COLOR
	end
	settingButton(3, function()
		return MatchSettings.timerLabel(self.settings.timer)
	end, function()
		self.settings.timer = MatchSettings.nextTimer(self.settings.timer)
	end)
	settingButton(4, function()
		return MatchSettings.lengthLabel(self.settings.length)
	end, function()
		self.settings.length = MatchSettings.nextLength(self.settings.length)
	end)
```

e) Add a local function above `HudView.new`:

```lua
-- The countdown and match line change every second between server updates.
local function refreshTimers(self: HudView)
	local snapshot = self.snapshot
	if not snapshot then
		return
	end
	local now = workspace:GetServerTimeNow()
	local countdown, urgent = HudModel.countdown(snapshot, now)
	self.status.Text = if countdown then `{self.statusText} · {countdown}` else self.statusText
	self.status.TextColor3 = if urgent then URGENT_COLOR else self.statusColor
	local matchLabel = self.matchLabel
	if matchLabel then
		local line = HudModel.matchLine(snapshot, now)
		matchLabel.Visible = line ~= nil
		matchLabel.Text = line or ""
	end
end
```

and in `new`, the Heartbeat connection calls both:

```lua
	RunService.Heartbeat:Connect(function()
		updateCard(self)
		refreshTimers(self)
	end)
```

f) In `render`:
- right after the loop that destroys the player-list `TextLabel`s, add `self.matchLabel = nil`;
- after the loop that creates the player rows, add:

```lua
	local matchLabel = text("Match", self.playerList, UDim2.new(1, -12, 0, 22), 15)
	matchLabel.LayoutOrder = 100
	matchLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.matchLabel = matchLabel
```

- replace the three status lines (`self.status.Text = ...`, `local debtor = ...`, `self.status.TextColor3 = ...`) with:

```lua
	self.statusText = HudModel.status(snapshot, localId) .. dice
	local debtor = HudModel.isDebtor(snapshot, localId)
	self.statusColor = if debtor then DEBT_TEXT_COLOR else TEXT_COLOR
	refreshTimers(self)
```

(`debtor` is still used just below for opening the properties panel.)

- [ ] **Step 3: Run the full suite (sync check first)**

Expected: all pass, 0 failed. Also check the client loaded: `execute_luau(Client, ...)` finds `PlayerGui.MonopolyHud.Lobby` with four children buttons/labels and no console errors.

- [ ] **Step 4: Playtest in Studio**

1. **Lobby.** Start play. Screenshot the lobby. Click the timer button and check it cycles "Timer: Relaxed 60 s" → "Fast 20 s" → "Off" → "Relaxed 60 s". Do the same for length.
2. **Timeouts.** In Edit, set `workspace:SetAttribute("TimerSeconds", 5)`, start play, pick Timer Fast, and start a 2-seat game. Don't touch anything. Check the log shows the human's turns playing themselves: rolled, no purchase (an auction where the human passes), end of turn. Check the status shows "· 0:0x" counting down, turning red. Screenshot.
3. **Timeouts in a trade and a debt.** With `StartingMoney` 150, the tax or rent debt should settle itself (mortgages, or bankruptcy) in one timeout. A trade offer made from the client is covered by the bot answering, so the Trade timeout is covered by Timeouts.spec; mark it "Not observed" unless it can be seen.
4. **Round limit.** Set `RoundLimit` to 2 and `TimerSeconds` to 3, start, and wait. Check the match line reads "Fast · Round 1 of 2" and then "Round 2 of 2", and that the results screen reads "Round limit reached — … wins!"
5. **Time limit.** Set `LimitMinutes` to 0.5, clear `RoundLimit`, start, and wait. Check the match line counts "0:2x left", then "Final turn", and that the results read "Time's up — … wins!" after the turn in progress ends.
6. Clear every attribute afterwards (`TimerSeconds`, `RoundLimit`, `LimitMinutes`, `StartingMoney`).

Record anything not observed as "Not observed" in the ledger, with the covering unit tests.

- [ ] **Step 5: Commit**

```bash
git add src/server/GameService.luau src/client/GameClient.luau src/client/Hud/HudView.luau
git commit -m "feat: speed options in the lobby, server turn clock and HUD countdown"
```
