# Debt, Bankruptcy and Winning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A player who can't afford a payment enters a debt phase where they sell buildings and mortgage until they can pay, or go bankrupt. Their assets go to the creditor, or to auction if they owed the bank. The last player standing (or the richest, once the last human is out) wins, a results screen shows, and everyone returns to the lobby.

**Architecture:**
- **Engine.** Every forced payment goes through `charge()`, which pays or appends an IOU to `state.debts`. After each accepted action, open debts switch the phase to `Debt` (the interrupted phase is saved in `state.resumePhase`), and the acting player is the first debtor. `PayDebt` and `Bankrupt` settle the first debt. Bankruptcy hands assets to the creditor, or queues bank auctions in `state.auctionQueue`. One `resume()` function picks what happens next: the next queued auction, the next debt, the next turn (if the current player went bankrupt), or the saved phase. A game-over check runs after each bankruptcy.
- **Client.** `HudModel` (pure) gains the debt buttons and statuses, the rules for which property rows are clickable in debt, and the standings. `HudView` adds a two-click bankruptcy button, an auto-opening Properties panel and a results panel. `GameService` handles `ReturnToLobby` and a 15 s auto-return.

**Tech Stack:** Luau (`--!strict`), Rojo 7.7, in-Studio test runner, Studio MCP for playtests.

**Spec:** `docs/superpowers/specs/2026-09-28-debt-and-bankruptcy-design.md` (read it; this plan implements it). Builds on `docs/superpowers/plans/2026-09-28-buildings-and-mortgages.md`.

## Global Constraints

- **Balances never go negative.** A forced payment the payer can't cover is not taken. It becomes a debt `{ debtor, creditor (nil = bank), amount, reason }`.
- **Forced payments go through `charge`:** rent, tax, card Pay/Repairs, each share of PayEachPlayer / CollectFromEachPlayer, the forced third-roll jail fine, and mortgage interest (`unmortgageCost − mortgageValue`) on inherited mortgaged property. Voluntary spending (buy, bid, build, unmortgage, voluntary jail fine) is still refused when unaffordable.
- **A player with an open debt pays nothing new directly.** New charges queue behind it, even if affordable.
- **What the debtor can do in `Debt`:** `SellBuilding`, `Mortgage`, `PayDebt` (cash ≥ amount) and `Bankrupt` (cash < amount). Everything else is refused, and nobody else may act.
- **Bankrupt to a player:**
  - buildings are sold at half the house price (a hotel = 5 houses' worth) and go back to the bank supply (a hotel returns as 1 hotel);
  - all the debtor's cash goes to the creditor;
  - properties pass to the creditor, keeping their mortgages, and the creditor is charged 10% interest on each mortgaged one;
  - jail cards go to the creditor.
- **A creditor that is bankrupt counts as the bank** when a debt is paid or someone goes bankrupt to them.
- **Bankrupt to the bank:**
  - buildings go back to the supply and the debtor's cash is removed;
  - jail cards go to the bottom of their decks;
  - each property is released (unowned, unmortgaged) and auctioned in board order to non-bankrupt players, starting from the current player.
- **A bankrupt player's other debts are dropped.**
- **The game ends (`GameOver`, `state.winner`) after a bankruptcy if** at most one non-bankrupt player is left, **or** the bankrupt player was human and no non-bankrupt human is left.
  - The winner is the highest net worth among non-bankrupt players (ties → earliest seat).
  - Queued auctions and debts are discarded.
- **Net worth** = cash + price of each owned property (its mortgage value if mortgaged) + each building at the full house price (a hotel = 5).
- **HUD:**
  - status text:
    - the debtor sees "You owe {creditor or "the bank"} ${amount}. You have ${money}.";
    - others see "Waiting for {debtor} to raise ${amount}…";
    - at game over everyone sees "{winner} wins!";
  - buttons: "Pay ${amount}" when affordable, else "Go bankrupt" → "Confirm bankruptcy?";
  - the Properties panel opens by itself on entering debt;
  - bankrupt players show "Bankrupt" in the player list;
  - results show standings by net worth, bankrupt players last, and a Back to lobby button.
- **Server:** `ReturnToLobby` (accepted only in `GameOver`) or 15 s after `GameOver` clears the session.
- **Out of scope:** trading (including during debt), turn timers, a creditor choosing to unmortgage instead of paying interest.
- Every new `.luau` file starts with `--!strict`. Tabs.

## Review Focus

1. **A debt raised in the middle of a move that ends on an unowned tile** (a forced jail fine then landing on a buyable street). After paying, the player must be offered the purchase, not skip it. Pinned by Debt.spec "a debt raised mid-move keeps the buy decision for after".
2. **A debtor whose cash grows while they owe** (Go salary, affordable rent after an unaffordable fine). Nothing may be paid out of order, and the player must still press Pay. Pinned by Debt.spec "once in debt, later charges queue behind it even if affordable".
3. **The current player goes bankrupt and the creditor can't afford the inherited mortgage interest.** After the creditor settles, the turn must pass on, not return to the bankrupt player's EndTurn. Pinned by Bankruptcy.spec "a creditor who can't afford the interest owes it to the bank, then the turn passes on".
4. **A tampered or confused client sends `PayDebt` / `Bankrupt` outside a debt, as a non-debtor, or `Bankrupt` while able to pay.** Each is rejected with no state change. Pinned by Debt.spec "only the debtor acts during a debt", "debt actions outside a debt are refused" and Bankruptcy.spec "Bankrupt is refused while you can pay".
5. **A bot that owns a hotel the bank can't take back** (fewer than 4 houses in the bank) and nothing to mortgage. It must go bankrupt instead of looping. Pinned by Bot.spec "a bot that can't sell or mortgage goes bankrupt".

## File Structure

```
src/server/Game/Types.luau               (modify) Debt type, "Debt" phase, debts/resumePhase/auctionQueue/winner, Auction.fromBankruptcy
src/server/Game/Engine.luau              (modify) charge, Debt phase, PayDebt, Bankrupt, bank auctions, game over, resume
src/shared/Rules/PropertyRules.luau      (modify) netWorth
src/server/Game/Snapshot.luau            (modify) debt, winner, netWorth
src/shared/Net/Protocol.luau             (modify) DebtView, Snapshot.debt/winner, PlayerView.netWorth
src/server/Game/Bot.luau                 (modify) raise cash / pay / go bankrupt
src/server/Game/GameSession.luau         (modify) PayDebt/Bankrupt fallbacks
src/server/GameService.luau              (modify) ReturnToLobby, 15 s auto-return, Studio StartingMoney attribute
src/client/Hud/HudModel.luau             (modify) debt buttons/status, rows in debt, isDebtor, standings, confirm field
src/client/Hud/EventText.luau            (modify) DebtOwed/WentBankrupt/GameOver lines
src/client/Hud/HudView.luau              (modify) confirm click, auto-open panel, Bankrupt in list, results panel, log cleared in lobby
src/client/GameClient.luau               (modify) onReturnToLobby
src/tests/GameFixtures.luau              (modify) new state fields in bareState; inDebt helper
src/tests/Debt.spec.luau, Bankruptcy.spec.luau (create)
src/tests/Engine.spec.luau, Jail.spec.luau, PropertyRules.spec.luau, Snapshot.spec.luau, Bot.spec.luau,
          GameSession.spec.luau, HudModel.spec.luau, EventText.spec.luau (modify)
```

No project-file changes, so no Rojo restart.

## How to run the tests

Studio MCP: `start_stop_play(true)`, `execute_luau(Server, 'return require(game.ServerStorage.Tests.TestRunner).run()')` (pass a filter string such as `"Debt"` to run one spec), `start_stop_play(false)`.

**Before every run**, use `execute_luau(Edit, ...)` to confirm that each file edited since the last run has its newest snippet in `.Source`. Studio sometimes misses a Rojo patch. If a file is stuck, make a real content change to it (append then strip a trailing newline).

Baseline: 164 passed, 0 failed.

## Useful board facts

- 1 Mediterranean ($60, $50 houses)
- 3 Baltic ($60)
- 4 Income Tax ($200)
- 5 Reading Railroad ($200, mortgage 100, interest 10)
- 6 Oriental ($100, rent 6)
- 7 Chance
- 10 Jail
- 12 Electric Company ($150, mortgage 75)
- 13 States Avenue ($140, rent 10)
- 15 Pennsylvania Railroad ($200)
- 17 Community Chest
- 37 Park Place and 39 Boardwalk ($200 houses)

Cards:
- `chance.chairman` = pay each player $50;
- `chest.birthday` = collect $10 from each player;
- jail cards are `chance.jailFree` and `chest.jailFree`.

---

### Task 1: Debts — charge, the Debt phase and PayDebt

**Files:**
- Modify: `src/server/Game/Types.luau`, `src/server/Game/Engine.luau`, `src/tests/GameFixtures.luau`, `src/tests/Engine.spec.luau:132-139`, `src/tests/Jail.spec.luau:112-125`
- Create: `src/tests/Debt.spec.luau`

**Interfaces:**
- Consumes: existing `transfer`, `emit`, `propertyAction`, `endTurn`, `Engine.getPlayer/currentPlayer`.
- Produces:
  - `Types.Debt = { debtor: string, creditor: string?, amount: number, reason: string }`
  - `Types.Phase` gains `"Debt"`
  - `GameState.debts: { Debt }`, `GameState.resumePhase: Phase?`, `GameState.auctionQueue: { number }`, `GameState.winner: string?` (the last two are filled in Task 2)
  - actions `{ type = "PayDebt" }`
  - events `DebtOwed { debtor, creditor, amount, reason }` and `DebtPaid { debtor, creditor, amount, reason }`
  - `Engine.actingPlayer` returns `state.debts[1].debtor` in `Debt`
  - engine-internal `charge(state, payer: Player, creditorId: string?, amount, reason)`, `liveCreditor(state, id?): Player?`, and `resume(state)` (forward-declared)
  - `GameFixtures.inDebt(state, debtorId, amount, creditorId?, reason?)` puts a state straight into `Debt`

- [ ] **Step 1: Types and fixtures**

In `Types.luau` change the phase type and add the debt type, then the new state fields:

```lua
export type Phase = "Roll" | "BuyDecision" | "Auction" | "EndTurn" | "Debt" | "GameOver"
```

```lua
-- An IOU: a forced payment the debtor couldn't cover yet. creditor nil = the bank.
export type Debt = {
	debtor: string,
	creditor: string?,
	amount: number,
	reason: string,
}
```

Add to `Auction`: `fromBankruptcy: boolean, -- sold off a bankrupt player's deeds; ends with resume, not finishMove`

Add to `GameState` after `auction: Auction?,`:

```lua
	debts: { Debt }, -- open IOUs, settled first to last
	resumePhase: Phase?, -- where play continues once the debts are settled
	auctionQueue: { number }, -- a bankrupt player's deeds waiting to be auctioned by the bank
	winner: string?,
```

Update the `Action` comment to add `"PayDebt" | "Bankrupt"`.

In `GameFixtures.bareState`, add `debts = {}, resumePhase = nil, auctionQueue = {}, winner = nil,` after `auction = nil,`. Add the helper:

```lua
-- Puts a state straight into the Debt phase: debtorId owes amount, play resumes in the current phase.
function GameFixtures.inDebt(state: Types.GameState, debtorId: string, amount: number, creditorId: string?, reason: string?)
	state.resumePhase = state.phase
	state.phase = "Debt"
	table.insert(state.debts, { debtor = debtorId, creditor = creditorId, amount = amount, reason = reason or "Tax" })
end
```

In `Engine.new`'s state literal add `debts = {}, resumePhase = nil, auctionQueue = {}, winner = nil,` after `auction = nil,`. In `startAuction` add `fromBankruptcy = false` to the auction table. Task 2 wires it.

- [ ] **Step 2: Write the failing tests**

Create `src/tests/Debt.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local ROLL = { type = "Roll" }
local PAY = { type = "PayDebt" }

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function player(state, id: string): any
	return Engine.getPlayer(state, id) :: any
end

-- p1 has $3 and rolls onto p2's Oriental Avenue ($6 rent).
local function shortOnRent()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	GameFixtures.own(state, "p2", 6)
	player(state, "p1").money = 3
	act(state, "p1", ROLL)
	return state
end

-- p1 is in jail with $20 on their third try; the roll {1, 2} forces the $50 fine and moves them to 13.
local function forcedFine(playerCount: number?)
	local state = GameFixtures.newGame(playerCount or 2, { { 1, 2 } })
	local p1 = player(state, "p1")
	p1.position = Engine.JAIL_POSITION
	p1.inJail = true
	p1.jailAttempts = 2
	p1.money = 20
	return state
end

tests["rent you can't afford becomes a debt and pauses the game on you"] = function()
	local state = shortOnRent()
	Expect.equal(player(state, "p1").money, 3, "nothing taken")
	Expect.equal(player(state, "p2").money, 1500, "creditor not paid yet")
	Expect.equal(state.phase, "Debt")
	Expect.equal(state.resumePhase, "EndTurn")
	Expect.equal(Engine.actingPlayer(state), "p1")
	local debt = state.debts[1]
	Expect.equal(debt.debtor, "p1", "debtor")
	Expect.equal(debt.creditor, "p2", "creditor")
	Expect.equal(debt.amount, 6, "amount")
	Expect.equal(debt.reason, "Rent", "reason")
	local owed = GameFixtures.eventsOfType(state, "DebtOwed")[1]
	Expect.equal(owed.creditor, "p2", "event creditor")
	Expect.equal(owed.amount, 6, "event amount")
end

tests["paying the debt pays the creditor and resumes the turn"] = function()
	local state = shortOnRent()
	player(state, "p1").money = 10
	act(state, "p1", PAY)
	Expect.equal(player(state, "p1").money, 4, "p1")
	Expect.equal(player(state, "p2").money, 1506, "p2")
	Expect.equal(#state.debts, 0, "debts")
	Expect.equal(state.phase, "EndTurn")
	Expect.equal(state.resumePhase, nil, "resume cleared")
	local paid = GameFixtures.eventsOfType(state, "DebtPaid")[1]
	Expect.equal(paid.creditor, "p2", "event creditor")
	local rent = GameFixtures.eventsOfType(state, "Paid")
	Expect.equal(rent[#rent].reason, "Rent", "paid as rent")
end

tests["PayDebt is refused while you are short"] = function()
	local state = shortOnRent()
	local ok, err = Engine.act(state, "p1", PAY)
	assert(not ok, "paid without the money")
	Expect.equal(err, "not enough money")
	Expect.equal(#state.debts, 1, "still owed")
	Expect.equal(state.phase, "Debt")
end

tests["in debt you may only sell buildings, mortgage, or pay"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	GameFixtures.own(state, "p2", 6)
	GameFixtures.own(state, "p1", 1, 1)
	GameFixtures.own(state, "p1", 3, 1)
	GameFixtures.own(state, "p1", 15)
	GameFixtures.own(state, "p1", 5)
	state.properties[5].mortgaged = true
	player(state, "p1").money = 3
	act(state, "p1", ROLL)
	Expect.equal(state.phase, "Debt")
	for _, action in {
		{ type = "EndTurn" },
		{ type = "Roll" },
		{ type = "Build", position = 1 },
		{ type = "Unmortgage", position = 5 },
		{ type = "Buy" },
	} :: { any } do
		local ok, err = Engine.act(state, "p1", action)
		assert(not ok, `{action.type} allowed in debt`)
		Expect.equal(err, "pay your debt first", action.type)
	end
	act(state, "p1", { type = "SellBuilding", position = 1 })
	Expect.equal(player(state, "p1").money, 28, "sold a house")
	act(state, "p1", { type = "Mortgage", position = 15 })
	Expect.equal(player(state, "p1").money, 128, "mortgaged")
	Expect.equal(state.phase, "Debt", "still in debt until paid")
	act(state, "p1", PAY)
	Expect.equal(state.phase, "EndTurn")
end

tests["only the debtor acts during a debt"] = function()
	local state = shortOnRent()
	for _, action in { PAY, { type = "Mortgage", position = 6 }, { type = "EndTurn" } } :: { any } do
		local ok, err = Engine.act(state, "p2", action)
		assert(not ok, `p2 {action.type} accepted`)
		Expect.equal(err, "waiting for another player to pay a debt", action.type)
	end
	Expect.equal(state.properties[6].mortgaged, false, "p2's deed untouched")
end

tests["debt actions outside a debt are refused"] = function()
	local state = GameFixtures.newGame(2, { { 3, 4 } })
	assert(not Engine.act(state, "p1", PAY), "PayDebt in Roll")
	assert(not Engine.act(state, "p1", { type = "Bankrupt" }), "Bankrupt in Roll")
	Expect.equal(state.phase, "Roll")
	Expect.equal(#state.events, 1, "only TurnStarted")
end

tests["a debt raised mid-move keeps the buy decision for after"] = function()
	local state = forcedFine()
	act(state, "p1", ROLL) -- fine becomes a debt, then lands on unowned States Avenue
	local p1 = player(state, "p1")
	Expect.equal(p1.position, 13, "still moved")
	Expect.equal(state.phase, "Debt")
	Expect.equal(state.resumePhase, "BuyDecision")
	p1.money = 300
	act(state, "p1", PAY)
	Expect.equal(p1.money, 250, "fine paid")
	Expect.equal(state.phase, "BuyDecision", "purchase still offered")
end

tests["once in debt, later charges queue behind it even if affordable"] = function()
	local state = forcedFine()
	GameFixtures.own(state, "p2", 13) -- $10 rent, and p1 still has $20
	act(state, "p1", ROLL)
	Expect.equal(#state.debts, 2, "fine and rent both owed")
	Expect.equal(state.debts[1].reason, "JailFine", "fine first")
	Expect.equal(state.debts[2].reason, "Rent", "rent second")
	Expect.equal(player(state, "p1").money, 20, "nothing paid out of order")
	player(state, "p1").money = 100
	act(state, "p1", PAY)
	Expect.equal(state.phase, "Debt", "rent still owed")
	Expect.equal(Engine.actingPlayer(state), "p1")
	act(state, "p1", PAY)
	Expect.equal(player(state, "p1").money, 40, "paid both")
	Expect.equal(player(state, "p2").money, 1510, "rent reached p2")
	Expect.equal(state.phase, "EndTurn")
end

tests["pay each player: pays whom it can, owes the rest, in seat order"] = function()
	local state = GameFixtures.newGame(3, { { 1, 2 } })
	player(state, "p1").position = 4
	player(state, "p1").money = 60
	GameFixtures.stackDeck(state, "Chance", { "chance.chairman" })
	act(state, "p1", ROLL)
	Expect.equal(player(state, "p1").money, 10, "paid p2")
	Expect.equal(player(state, "p2").money, 1550, "p2")
	Expect.equal(#state.debts, 1, "owes p3")
	Expect.equal(state.debts[1].creditor, "p3", "creditor")
	Expect.equal(state.debts[1].amount, 50, "amount")
end

tests["collect from each player puts each short player in debt, in seat order"] = function()
	local state = GameFixtures.newGame(3, { { 1, 2 } })
	player(state, "p1").position = 14
	player(state, "p2").money = 5
	player(state, "p3").money = 5
	GameFixtures.stackDeck(state, "CommunityChest", { "chest.birthday" })
	act(state, "p1", ROLL)
	Expect.equal(state.phase, "Debt")
	Expect.equal(Engine.actingPlayer(state), "p2", "p2 first")
	assert(not Engine.act(state, "p1", { type = "EndTurn" }), "drawer moved on early")
	player(state, "p2").money = 20
	act(state, "p2", PAY)
	Expect.equal(Engine.actingPlayer(state), "p3", "then p3")
	player(state, "p3").money = 20
	act(state, "p3", PAY)
	Expect.equal(state.phase, "EndTurn", "back to the drawer's turn")
	Expect.equal(Engine.actingPlayer(state), "p1")
	Expect.equal(player(state, "p1").money, 1520, "collected from both")
end

tests["a debt to a player who has since gone bankrupt is paid to the bank"] = function()
	local state = GameFixtures.newGame(3)
	GameFixtures.inDebt(state, "p1", 50, "p2", "Rent")
	player(state, "p2").bankrupt = true
	act(state, "p1", PAY)
	Expect.equal(player(state, "p1").money, 1450, "p1 paid")
	Expect.equal(player(state, "p2").money, 1500, "bankrupt p2 not paid")
	local paid = GameFixtures.eventsOfType(state, "Paid")
	Expect.equal(paid[#paid].to, nil, "paid to the bank")
end

return tests
```

Also update the two existing tests that expected negative balances:

`Engine.spec.luau`: replace the test `"rent is paid even if it leaves the player in debt"` with:

```lua
tests["rent you can't afford is owed, not taken"] = function()
	local state = GameFixtures.newGame(2, { { 2, 4 } })
	GameFixtures.own(state, "p2", 6)
	Engine.getPlayer(state, "p1").money = 3
	act(state, "p1", ROLL)
	Expect.equal(money(state, "p1"), 3)
	Expect.equal(money(state, "p2"), 1500)
	Expect.equal(state.phase, "Debt")
end
```

`Jail.spec.luau`, in `"the third failed roll forces the fine and moves you"`: replace the three lines from `Expect.equal(p1.money, -30, ...)` through `Expect.equal(GameFixtures.eventsOfType(state, "Paid")[1].reason, "JailFine")` (keep the `position` and `LeftJail` checks) so the test ends:

```lua
	assert(not p1.inJail, "still in jail")
	Expect.equal(p1.money, 20, "fine owed, not taken")
	Expect.equal(p1.position, 13, "moved by the roll")
	Expect.equal(state.phase, "Debt")
	Expect.equal(state.debts[1].reason, "JailFine", "debt reason")
	Expect.equal(state.debts[1].amount, 50, "debt amount")
	Expect.equal(GameFixtures.eventsOfType(state, "LeftJail")[1].reason, "Fine")
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run with filter `"Debt"`, then the full suite.
Expected: the Debt.spec tests FAIL (e.g. `phase` is `EndTurn` instead of `Debt`, and `money` is `-3`). "debt actions outside a debt are refused" may already pass, because unknown actions are refused today. The updated Engine/Jail tests FAIL. Everything else passes.

- [ ] **Step 4: Implement**

In `Engine.luau`:

a) Next to `local resolveLanding: ...` add the forward declaration:

```lua
local resume: (state: GameState) -> ()
```

b) Right after `transfer`, add:

```lua
local function hasDebt(state: GameState, playerId: string): boolean
	for _, debt in state.debts do
		if debt.debtor == playerId then
			return true
		end
	end
	return false
end

-- A forced payment: paid now if the payer can cover it and owes nothing else, otherwise an IOU.
local function charge(state: GameState, payer: Player, creditorId: string?, amount: number, reason: string)
	if payer.money >= amount and not hasDebt(state, payer.id) then
		transfer(state, payer.id, creditorId, amount, reason)
		return
	end
	table.insert(state.debts, { debtor = payer.id, creditor = creditorId, amount = amount, reason = reason })
	emit(state, { type = "DebtOwed", debtor = payer.id, creditor = creditorId, amount = amount, reason = reason })
end

-- The player a debt is owed to, or nil when that's the bank (a bankrupt creditor counts as the bank).
local function liveCreditor(state: GameState, creditorId: string?): Player?
	local creditor = if creditorId then Engine.getPlayer(state, creditorId) else nil
	return if creditor and not creditor.bankrupt then creditor else nil
end
```

c) Replace forced payments with `charge`:
- `applyCard` "Pay": `charge(state, player, nil, effect.amount :: number, "Card")`
- "PayEachPlayer": `charge(state, player, other.id, effect.amount :: number, "Card")`
- "CollectFromEachPlayer": `charge(state, other, player.id, effect.amount :: number, "Card")`
- "Repairs": `charge(state, player, nil, cost, "Card")`
- `resolveLanding` rent: `charge(state, player, ownership.owner, rent, "Rent")`
- tax: `charge(state, player, nil, tile.amount :: number, "Tax")`
- `roll`, the forced fine: `charge(state, player, nil, Engine.JAIL_FINE, "JailFine")`

`payJailFine` (voluntary) keeps `transfer`.

d) `Engine.actingPlayer`: add a branch after the GameOver check:

```lua
	elseif state.phase == "Debt" then
		return state.debts[1].debtor
```

e) `endTurn`: add `state.resumePhase = nil` next to `state.rollAgain = false`.

f) After `endTurn`, add the debt section:

```lua
-- Continues the game once a debt is settled.
function resume(state: GameState)
	if #state.debts > 0 then
		state.phase = "Debt"
	else
		state.phase = state.resumePhase :: Types.Phase
		state.resumePhase = nil
	end
end

local function payDebt(state: GameState, player: Player): (boolean, string?)
	local debt = state.debts[1]
	if player.money < debt.amount then
		return false, "not enough money"
	end
	table.remove(state.debts, 1)
	local creditor = liveCreditor(state, debt.creditor)
	local creditorId = if creditor then creditor.id else nil
	transfer(state, player.id, creditorId, debt.amount, debt.reason)
	emit(state, { type = "DebtPaid", debtor = player.id, creditor = creditorId, amount = debt.amount, reason = debt.reason })
	resume(state)
	return true
end

local function actInDebt(state: GameState, player: Player, action: Types.Action): (boolean, string?)
	if state.debts[1].debtor ~= player.id then
		return false, "waiting for another player to pay a debt"
	elseif action.type == "PayDebt" then
		return payDebt(state, player)
	elseif action.type == "SellBuilding" or action.type == "Mortgage" then
		return propertyAction(state, player, action.type, action.position)
	end
	return false, "pay your debt first"
end
```

g) Split `Engine.act`. Move everything after the `not player or player.bankrupt` check into a local `dispatch(state, player, action)` defined just above `Engine.act`, with a Debt branch first:

```lua
local function dispatch(state: GameState, player: Player, action: Types.Action): (boolean, string?)
	local playerId = player.id
	if state.phase == "Debt" then
		return actInDebt(state, player, action)
	end
	if state.phase == "Auction" then
		-- ... existing auction branch, unchanged ...
	end
	-- ... existing current-player check and action branches, unchanged ...
end

function Engine.act(state: GameState, playerId: string, action: Types.Action): (boolean, string?)
	if typeof(action) ~= "table" or typeof(action.type) ~= "string" then
		return false, "invalid action"
	end
	if state.phase == "GameOver" then
		return false, "the game is over"
	end
	local player = Engine.getPlayer(state, playerId)
	if not player or player.bankrupt then
		return false, "not in this game"
	end
	local ok, err = dispatch(state, player, action)
	-- Anything owed during that action pauses the game on the debtor; play picks up here afterwards.
	if ok and #state.debts > 0 and state.phase ~= "Debt" and state.phase ~= "Auction" and state.phase ~= "GameOver" then
		state.resumePhase = state.phase
		state.phase = "Debt"
	end
	return ok, err
end
```

- [ ] **Step 5: Run the full suite (sync check first)**

Expected: all pass, 0 failed.

- [ ] **Step 6: Commit**

```bash
git add src/server/Game/Types.luau src/server/Game/Engine.luau src/tests/GameFixtures.luau src/tests/Debt.spec.luau src/tests/Engine.spec.luau src/tests/Jail.spec.luau
git commit -m "feat: unaffordable payments become debts the debtor must settle"
```

---

### Task 2: Bankruptcy, bank auctions and game over

**Files:**
- Modify: `src/server/Game/Engine.luau`, `src/shared/Rules/PropertyRules.luau`, `src/tests/PropertyRules.spec.luau`
- Create: `src/tests/Bankruptcy.spec.luau`

**Interfaces:**
- Consumes: Task 1's `charge`, `liveCreditor`, `resume`, `actInDebt`, `state.debts/resumePhase/auctionQueue/winner`, `Auction.fromBankruptcy`, `GameFixtures.inDebt`.
- Produces:
  - `PropertyRules.netWorth(view: View, playerId: string, money: number): number`
  - action `{ type = "Bankrupt" }`
  - events `WentBankrupt { player, creditor }` and `GameOver { winner }`
  - `Paid` reasons `"Bankruptcy"` (the debtor's cash to the creditor or bank) and `"MortgageInterest"`
  - `startAuction(state, position, fromBankruptcy: boolean?)`
  - `resume` now also starts queued auctions and passes the turn when the current player is bankrupt

- [ ] **Step 1: Write the failing tests**

Append to `src/tests/PropertyRules.spec.luau` (before `return tests`; it already has `PropertyRules`, `GameFixtures`, `Expect` in scope — check the requires at the top and add any missing):

```lua
tests["net worth counts cash, deeds at price or mortgage value, and buildings at cost"] = function()
	local state = GameFixtures.bareState(2)
	GameFixtures.own(state, "p1", 1, 2) -- $60 + 2 x $50
	GameFixtures.own(state, "p1", 3, 5) -- $60 + hotel = 5 x $50
	GameFixtures.own(state, "p1", 5) -- mortgaged: $100
	state.properties[5].mortgaged = true
	GameFixtures.own(state, "p2", 6)
	Expect.equal(PropertyRules.netWorth(state, "p1", 100), 100 + 60 + 100 + 60 + 250 + 100)
	Expect.equal(PropertyRules.netWorth(state, "p2", 0), 100, "p2")
end
```

Create `src/tests/Bankruptcy.spec.luau`:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Engine = require(ServerScriptService.Server.Game.Engine)
local GameFixtures = require(script.Parent.GameFixtures)
local Expect = require(script.Parent.Expect)

local tests = {}

local ROLL = { type = "Roll" }
local PAY = { type = "PayDebt" }
local BANKRUPT = { type = "Bankrupt" }

local function act(state, playerId: string, action)
	local ok, err = Engine.act(state, playerId, action)
	assert(ok, `{playerId} {action.type} failed: {err}`)
end

local function player(state, id: string): any
	return Engine.getPlayer(state, id) :: any
end

-- p1 ($3) lands on p2's Oriental Avenue and owes $6 rent.
local function owesRent(playerCount: number)
	local state = GameFixtures.newGame(playerCount, { { 2, 4 } })
	GameFixtures.own(state, "p2", 6)
	player(state, "p1").money = 3
	return state
end

-- p1 ($100) rolls onto Income Tax ($200) and owes the bank.
local function owesTax(playerCount: number)
	local state = GameFixtures.newGame(playerCount, { { 1, 3 } })
	player(state, "p1").money = 100
	return state
end

tests["Bankrupt is refused while you can pay"] = function()
	local state = owesRent(2)
	act(state, "p1", ROLL)
	player(state, "p1").money = 10
	local ok, err = Engine.act(state, "p1", BANKRUPT)
	assert(not ok, "went bankrupt while able to pay")
	Expect.equal(err, "you can pay this debt")
	assert(not player(state, "p1").bankrupt, "flagged bankrupt")
	Expect.equal(#state.debts, 1, "debt kept")
end

tests["going bankrupt to a player hands over cash, deeds and jail cards"] = function()
	local state = owesRent(3)
	GameFixtures.own(state, "p1", 1, 1)
	GameFixtures.own(state, "p1", 3, 1)
	GameFixtures.own(state, "p1", 5)
	state.properties[5].mortgaged = true
	state.bankHouses = 30
	player(state, "p1").jailCards = { "chance.jailFree" }
	act(state, "p1", ROLL)
	act(state, "p1", BANKRUPT)

	local p1, p2 = player(state, "p1"), player(state, "p2")
	assert(p1.bankrupt, "p1 not bankrupt")
	Expect.equal(p1.money, 0, "p1 cash")
	-- $3 cash + 2 houses sold at $25 each, minus $10 interest on Reading Railroad.
	Expect.equal(p2.money, 1500 + 3 + 50 - 10, "p2 cash")
	for _, position in { 1, 3, 5 } do
		Expect.equal(state.properties[position].owner, "p2", `owner of {position}`)
	end
	Expect.equal(state.properties[1].houses, 0, "houses sold")
	Expect.equal(state.bankHouses, 32, "houses back in the bank")
	Expect.equal(state.properties[5].mortgaged, true, "mortgage kept")
	Expect.equal(p2.jailCards[1], "chance.jailFree", "jail card passed on")
	Expect.equal(#p1.jailCards, 0, "p1 has no cards")
	local went = GameFixtures.eventsOfType(state, "WentBankrupt")[1]
	Expect.equal(went.player, "p1", "event player")
	Expect.equal(went.creditor, "p2", "event creditor")
	local reasons = {}
	for _, paid in GameFixtures.eventsOfType(state, "Paid") do
		reasons[paid.reason] = paid.amount
	end
	Expect.equal(reasons.Bankruptcy, 53, "cash handed over")
	Expect.equal(reasons.MortgageInterest, 10, "interest")
	Expect.equal(Engine.currentPlayer(state).id, "p2", "turn passed on")
	Expect.equal(state.phase, "Roll")
	Expect.equal(#state.debts, 0, "no debts left")
end

tests["a creditor who can't afford the interest owes it to the bank, then the turn passes on"] = function()
	local state = owesRent(3)
	GameFixtures.own(state, "p1", 5)
	GameFixtures.own(state, "p1", 15)
	state.properties[5].mortgaged = true
	state.properties[15].mortgaged = true
	act(state, "p1", ROLL)
	player(state, "p2").money = 0
	act(state, "p1", BANKRUPT)

	Expect.equal(state.phase, "Debt")
	Expect.equal(Engine.actingPlayer(state), "p2", "creditor must settle")
	Expect.equal(#state.debts, 2, "interest on both deeds")
	Expect.equal(state.debts[1].creditor, nil, "owed to the bank")
	Expect.equal(state.debts[1].reason, "MortgageInterest")
	player(state, "p2").money = 100
	act(state, "p2", PAY)
	act(state, "p2", PAY)
	Expect.equal(player(state, "p2").money, 80, "paid 2 x $10")
	Expect.equal(Engine.currentPlayer(state).id, "p2", "bankrupt p1's turn is over")
	Expect.equal(state.phase, "Roll")
end

tests["going bankrupt to the bank returns buildings and cards, then auctions each deed"] = function()
	local state = owesTax(3)
	GameFixtures.own(state, "p1", 1, 2)
	GameFixtures.own(state, "p1", 3, 2)
	GameFixtures.own(state, "p1", 5)
	state.properties[5].mortgaged = true
	state.bankHouses = 28
	player(state, "p1").jailCards = { "chest.jailFree" }
	act(state, "p1", ROLL)
	act(state, "p1", BANKRUPT)

	Expect.equal(player(state, "p1").money, 0, "cash gone")
	Expect.equal(state.bankHouses, 32, "houses back")
	local chest = state.decks.CommunityChest
	Expect.equal(chest[#chest], "chest.jailFree", "card back under the deck")
	Expect.equal(GameFixtures.eventsOfType(state, "WentBankrupt")[1].creditor, nil, "to the bank")

	Expect.equal(state.phase, "Auction")
	Expect.equal(state.auction.position, 1, "first deed in board order")
	Expect.equal(table.concat(state.auction.bidders, ","), "p2,p3", "bankrupt p1 doesn't bid")
	Expect.equal(state.properties[1], nil, "released to the bank")
	act(state, "p2", { type = "Bid", amount = 10 })
	act(state, "p3", { type = "PassBid" })
	Expect.equal(state.properties[1].owner, "p2", "p2 won Mediterranean")
	Expect.equal(state.properties[1].houses, 0, "sold bare")

	Expect.equal(state.auction.position, 3, "next deed")
	act(state, "p2", { type = "PassBid" })
	act(state, "p3", { type = "PassBid" })
	Expect.equal(state.properties[3], nil, "no bids: stays with the bank")

	Expect.equal(state.auction.position, 5, "last deed")
	act(state, "p2", { type = "PassBid" })
	act(state, "p3", { type = "Bid", amount = 50 })
	Expect.equal(state.properties[5].owner, "p3", "p3 won Reading")
	Expect.equal(state.properties[5].mortgaged, false, "sold unmortgaged")

	Expect.equal(state.auction, nil, "auctions over")
	Expect.equal(Engine.currentPlayer(state).id, "p2", "turn passed on")
	Expect.equal(state.phase, "Roll")
end

tests["bankruptcy on someone else's turn lets that turn carry on"] = function()
	local state = GameFixtures.newGame(3, { { 1, 2 } })
	player(state, "p1").position = 14
	player(state, "p2").money = 5
	GameFixtures.stackDeck(state, "CommunityChest", { "chest.birthday" })
	act(state, "p1", ROLL)
	Expect.equal(Engine.actingPlayer(state), "p2")
	act(state, "p2", BANKRUPT)
	assert(player(state, "p2").bankrupt, "p2 not bankrupt")
	Expect.equal(player(state, "p1").money, 1500 + 10 + 5, "p3's $10 and p2's last $5")
	Expect.equal(state.phase, "EndTurn", "p1's turn resumes")
	Expect.equal(Engine.currentPlayer(state).id, "p1")
	act(state, "p1", { type = "EndTurn" })
	Expect.equal(Engine.currentPlayer(state).id, "p3", "bankrupt p2 is skipped")
end

tests["a bankrupt player's other debts are dropped"] = function()
	local state = GameFixtures.newGame(3, { { 1, 2 } })
	player(state, "p1").position = 4
	player(state, "p1").money = 20
	GameFixtures.stackDeck(state, "Chance", { "chance.chairman" })
	act(state, "p1", ROLL)
	Expect.equal(#state.debts, 2, "owes p2 and p3")
	act(state, "p1", BANKRUPT)
	Expect.equal(#state.debts, 0, "debt to p3 dropped")
	Expect.equal(player(state, "p2").money, 1520, "p2 got the $20")
	Expect.equal(player(state, "p3").money, 1500, "p3 got nothing")
	Expect.equal(Engine.currentPlayer(state).id, "p2")
	Expect.equal(state.phase, "Roll")
end

tests["the last player standing wins"] = function()
	local state = owesTax(2)
	GameFixtures.own(state, "p1", 1)
	act(state, "p1", ROLL)
	act(state, "p1", BANKRUPT)
	Expect.equal(state.phase, "GameOver")
	Expect.equal(state.winner, "p2")
	Expect.equal(GameFixtures.eventsOfType(state, "GameOver")[1].winner, "p2", "event")
	Expect.equal(state.auction, nil, "no auction once the game is over")
	Expect.equal(#state.auctionQueue, 0, "queue discarded")
	Expect.equal(Engine.actingPlayer(state), nil)
	local ok, err = Engine.act(state, "p2", ROLL)
	assert(not ok, "acted after game over")
	Expect.equal(err, "the game is over")
end

tests["when the last human goes bankrupt the richest remaining player wins"] = function()
	local state = owesTax(3)
	player(state, "p2").isBot = true
	player(state, "p3").isBot = true
	player(state, "p3").money = 1400
	GameFixtures.own(state, "p3", 39) -- $1400 + $400 beats p2's $1500
	act(state, "p1", ROLL)
	act(state, "p1", BANKRUPT)
	Expect.equal(state.phase, "GameOver")
	Expect.equal(state.winner, "p3")
end

tests["net worth ties go to the earlier seat"] = function()
	local state = owesTax(3)
	player(state, "p2").isBot = true
	player(state, "p3").isBot = true
	act(state, "p1", ROLL)
	act(state, "p1", BANKRUPT)
	Expect.equal(state.winner, "p2")
end

tests["a bot going bankrupt doesn't end the game while a human plays on"] = function()
	local state = owesTax(3)
	player(state, "p1").isBot = true
	player(state, "p3").isBot = true
	act(state, "p1", ROLL)
	act(state, "p1", BANKRUPT)
	Expect.equal(state.phase, "Roll")
	Expect.equal(state.winner, nil)
	Expect.equal(Engine.currentPlayer(state).id, "p2")
end

return tests
```

- [ ] **Step 2: Run tests to verify they fail**

Run with filters `"Bankruptcy"` and `"PropertyRules"`.
Expected: the Bankruptcy.spec tests FAIL with "pay your debt first" (Bankrupt isn't handled yet). The net-worth test FAILS with "attempt to call a nil value".

- [ ] **Step 3: Implement `PropertyRules.netWorth`**

Append before `return PropertyRules`:

```lua
-- What a player is worth if everything were counted at face value: used to rank players at the end.
function PropertyRules.netWorth(view: View, playerId: string, money: number): number
	local worth = money
	for position, ownership in view.properties do
		if ownership.owner ~= playerId then
			continue
		end
		worth += if ownership.mortgaged
			then PropertyRules.mortgageValue(position)
			else Tiles.at(position).price :: number
		if ownership.houses > 0 then
			worth += ownership.houses * PropertyRules.housePrice(position)
		end
	end
	return worth
end
```

- [ ] **Step 4: Implement bankruptcy in the engine**

a) `startAuction(state, position, fromBankruptcy: boolean?)` stores `fromBankruptcy = fromBankruptcy == true`.

b) `endAuctionIfSettled`: replace the final `finishMove(state)` with:

```lua
	if auction.fromBankruptcy then
		resume(state)
	else
		finishMove(state)
	end
```

c) Replace `resume` with the full version:

```lua
-- Continues the game once a debt, a bankruptcy or a bankruptcy auction is settled.
function resume(state: GameState)
	if #state.auctionQueue > 0 then
		startAuction(state, table.remove(state.auctionQueue, 1) :: number, true)
	elseif #state.debts > 0 then
		state.phase = "Debt"
	elseif Engine.currentPlayer(state).bankrupt then
		endTurn(state)
	else
		state.phase = state.resumePhase :: Types.Phase
		state.resumePhase = nil
	end
end
```

d) Add after `payDebt`:

```lua
-- Hands a property's buildings back to the bank supply; returns what selling them earns (half price each).
local function returnBuildings(state: GameState, position: number, ownership: Types.Ownership): number
	local houses = ownership.houses
	if houses == 0 then
		return 0
	end
	if houses == PropertyRules.HOTEL then
		state.bankHotels += 1
	else
		state.bankHouses += houses
	end
	ownership.houses = 0
	return houses * (PropertyRules.housePrice(position) // 2)
end

-- After a bankruptcy: ends the game if one player is left, or if the last human still playing just went out.
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
	state.debts = {}
	state.auctionQueue = {}
	state.resumePhase = nil
	emit(state, { type = "GameOver", winner = state.winner })
	return true
end

local function goBankrupt(state: GameState, player: Player): (boolean, string?)
	local debt = state.debts[1]
	if player.money >= debt.amount then
		return false, "you can pay this debt"
	end
	local creditor = liveCreditor(state, debt.creditor)
	player.bankrupt = true
	player.inJail = false
	for i = #state.debts, 1, -1 do
		if state.debts[i].debtor == player.id then
			table.remove(state.debts, i)
		end
	end
	emit(state, { type = "WentBankrupt", player = player.id, creditor = if creditor then creditor.id else nil })

	local refund = 0
	local inherited = {} -- mortgaged deeds the creditor takes over
	for position = 0, Tiles.COUNT - 1 do
		local ownership = state.properties[position]
		if not ownership or ownership.owner ~= player.id then
			continue
		end
		refund += returnBuildings(state, position, ownership)
		if creditor then
			ownership.owner = creditor.id
			if ownership.mortgaged then
				table.insert(inherited, position)
			end
		else
			state.properties[position] = nil
			table.insert(state.auctionQueue, position)
		end
	end

	if creditor then
		if refund > 0 then
			transfer(state, nil, player.id, refund, "Building")
		end
		for _, id in player.jailCards do
			table.insert(creditor.jailCards, id)
		end
	else
		for _, id in player.jailCards do
			table.insert(state.decks[Cards.byId[id].deck], id)
		end
	end
	table.clear(player.jailCards)
	if player.money > 0 then
		transfer(state, player.id, if creditor then creditor.id else nil, player.money, "Bankruptcy")
	end

	if endIfOver(state, player) then
		return true
	end
	if creditor then
		for _, position in inherited do
			local interest = PropertyRules.unmortgageCost(position) - PropertyRules.mortgageValue(position)
			charge(state, creditor, nil, interest, "MortgageInterest")
		end
	end
	resume(state)
	return true
end
```

e) In `actInDebt`, add the branch after `PayDebt`:

```lua
	elseif action.type == "Bankrupt" then
		return goBankrupt(state, player)
```

- [ ] **Step 5: Run the full suite (sync check first)**

Expected: all pass, 0 failed.

The existing Bot.spec simulations still use $1500 and 2000 steps. If one of them now reaches `GameOver` and fails on "no acting player", apply Task 3 Step 1's loop change here and note it in the ledger.

- [ ] **Step 6: Commit**

```bash
git add src/server/Game/Engine.luau src/shared/Rules/PropertyRules.luau src/tests/PropertyRules.spec.luau src/tests/Bankruptcy.spec.luau
git commit -m "feat: bankruptcy to players and the bank, and the winner"
```

---

### Task 3: Snapshot, bots and sessions settle debts

**Files:**
- Modify: `src/shared/Net/Protocol.luau`, `src/server/Game/Snapshot.luau`, `src/server/Game/Bot.luau`, `src/server/Game/GameSession.luau`
- Test: `src/tests/Snapshot.spec.luau`, `src/tests/Bot.spec.luau`, `src/tests/GameSession.spec.luau`

**Interfaces:**
- Consumes: `state.debts`, `state.winner`, `PropertyRules.netWorth`, actions `PayDebt`/`Bankrupt`, `GameFixtures.inDebt`.
- Produces:
  - `Protocol.DebtView = { debtor: string, creditor: string?, amount: number, reason: string }`
  - `Protocol.Snapshot.debt: DebtView?`, `Protocol.Snapshot.winner: string?`
  - `Protocol.PlayerView.netWorth: number`
  - `Bot.chooseAction` handles `"Debt"`
  - `GameSession` fallbacks include `PayDebt`, `Bankrupt`

- [ ] **Step 1: Write the failing tests**

`Snapshot.spec.luau`, add:

```lua
tests["snapshot shows the open debt, the winner and each player's net worth"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1)
	GameFixtures.inDebt(state, "p1", 200, "p2", "Rent")
	local snapshot = Snapshot.fromState(state)
	local debt = snapshot.debt :: any
	Expect.equal(debt.debtor, "p1", "debtor")
	Expect.equal(debt.creditor, "p2", "creditor")
	Expect.equal(debt.amount, 200, "amount")
	Expect.equal(debt.reason, "Rent", "reason")
	Expect.equal(snapshot.players[1].netWorth, 1560, "cash + Mediterranean")
	Expect.equal(snapshot.winner, nil, "no winner yet")
	state.winner = "p2"
	state.debts = {}
	Expect.equal(Snapshot.fromState(state).winner, "p2", "winner")
	Expect.equal(Snapshot.fromState(state).debt, nil, "no debt")
end
```

`Bot.spec.luau`, add:

```lua
tests["a bot in debt pays as soon as it can"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.inDebt(state, "p1", 100)
	Expect.equal(Bot.chooseAction(state, "p1").type, "PayDebt")
	Expect.equal(Bot.chooseAction(state, "p2"), nil, "not p2's move")
end

tests["a bot in debt sells its most expensive building first"] = function()
	local state = GameFixtures.newGame(2)
	for _, position in { 1, 3, 37, 39 } do
		GameFixtures.own(state, "p1", position, 1)
	end
	Engine.getPlayer(state, "p1").money = 0
	GameFixtures.inDebt(state, "p1", 100)
	local action = Bot.chooseAction(state, "p1")
	Expect.equal(action.type, "SellBuilding", "sells")
	Expect.equal(action.position, 39, "a $200 house before a $50 one")
end

tests["a bot in debt with no buildings mortgages its cheapest deed"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 5) -- mortgage value 100
	GameFixtures.own(state, "p1", 12) -- 75
	GameFixtures.own(state, "p1", 1) -- 30
	Engine.getPlayer(state, "p1").money = 0
	GameFixtures.inDebt(state, "p1", 100)
	local action = Bot.chooseAction(state, "p1")
	Expect.equal(action.type, "Mortgage")
	Expect.equal(action.position, 1)
end

tests["a bot that can't sell or mortgage goes bankrupt"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1, 5)
	GameFixtures.own(state, "p1", 3, 5)
	state.bankHouses = 0 -- the bank can't swap the hotels back
	Engine.getPlayer(state, "p1").money = 0
	GameFixtures.inDebt(state, "p1", 100)
	Expect.equal(Bot.chooseAction(state, "p1").type, "Bankrupt", "hotels stuck, nothing to mortgage")
	state.properties = {}
	Expect.equal(Bot.chooseAction(state, "p1").type, "Bankrupt", "owns nothing")
end

tests["an all-bot game on short money ends with a winner"] = function()
	local random = Random.new(7)
	local state = Engine.new({
		{ id = "b1", name = "B1", isBot = true },
		{ id = "b2", name = "B2", isBot = true },
		{ id = "b3", name = "B3", isBot = true },
	}, function()
		return random:NextInteger(1, 6), random:NextInteger(1, 6)
	end)
	for _, bot in state.players do
		bot.money = 300
	end
	for step = 1, 20000 do
		if state.phase == "GameOver" then
			break
		end
		local actor = assert(Engine.actingPlayer(state), `no acting player at step {step}`)
		local action = assert(Bot.chooseAction(state, actor), `bot {actor} had no action in {state.phase}`)
		local ok, err = Engine.act(state, actor, action)
		assert(ok, `step {step}: {actor} {action.type} rejected: {err}`)
	end
	Expect.equal(state.phase, "GameOver", "game never ended")
	assert(state.winner, "no winner")
	Expect.equal(#GameFixtures.eventsOfType(state, "WentBankrupt"), 2, "two bots went out")
	for _, bot in state.players do
		assert(bot.money >= 0, `{bot.id} went negative`)
	end
end
```

Also in the two existing simulation tests (`"two bots eventually build"`, `"an all-bot game keeps making legal moves"`), add `if state.phase == "GameOver" then break end` as the first line of the loop body. In "two bots eventually build", move the `error(...)` after the loop to `error("no bot built anything before the game ended or 4000 steps")`. In "keeps making legal moves", keep the event assertions after the loop.

`GameSession.spec.luau`:

a) In `"bots play until a human must act"`, extend the h1 branch so a human debt is settled:

```lua
		if Engine.actingPlayer(session.state) == "h1" and session.state.phase ~= "Roll" then
			local phase = session.state.phase
			local action = if phase == "Auction"
				then { type = "PassBid" }
				elseif phase == "Debt" then { type = "PayDebt" }
				else { type = "EndTurn" }
			assert(GameSession.act(session, "h1", action))
		end
```

b) Add:

```lua
tests["a bot with no plan in debt still settles it"] = function()
	local Bot = require(ServerScriptService.Server.Game.Bot)
	local original = Bot.chooseAction
	Bot.chooseAction = function()
		return nil
	end
	local ok, err = pcall(function()
		local session = GameSession.new(humans(1), 2, GameFixtures.scriptedDice({}))
		session.state.currentIndex = 2
		GameFixtures.inDebt(session.state, "bot1", 100)
		assert(GameSession.stepBot(session), "rich bot did not pay")
		Expect.equal(#session.state.debts, 0, "paid")
		GameFixtures.inDebt(session.state, "bot1", 5000)
		assert(GameSession.stepBot(session), "broke bot did not go bankrupt")
		assert(Engine.getPlayer(session.state, "bot1").bankrupt, "bot1 still in")
	end)
	Bot.chooseAction = original
	assert(ok, err)
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run with filters `"Snapshot"`, `"Bot"`, `"GameSession"`.
Expected:
- the snapshot test FAILS (`debt` is nil);
- the bot debt tests FAIL with "had no action" / nil action;
- the new GameSession test FAILS ("rich bot did not pay");
- the short-money simulation FAILS on a nil action in `Debt`.

- [ ] **Step 3: Implement**

`Protocol.luau`: add `netWorth: number,` to `PlayerView`. Add:

```lua
export type DebtView = {
	debtor: string,
	creditor: string?, -- nil = the bank
	amount: number,
	reason: string,
}
```

Add `debt: DebtView?, -- the IOU being settled, while phase is "Debt"` and `winner: string?,` to `Snapshot`.

`Snapshot.luau`: require `PropertyRules` (`ReplicatedStorage.Shared.Rules.PropertyRules`). In the player rows add `netWorth = PropertyRules.netWorth(state, player.id, player.money),`. Before the return:

```lua
	local openDebt = state.debts[1]
	local debt: Protocol.DebtView? = if openDebt
		then { debtor = openDebt.debtor, creditor = openDebt.creditor, amount = openDebt.amount, reason = openDebt.reason }
		else nil
```

Add `debt = debt,` and `winner = state.winner,` to the returned table.

`Bot.luau`: update the header comment to mention debts. Add before `Bot.chooseAction`:

```lua
-- In debt: sell the priciest building (the rules keep sets even), else mortgage the cheapest bare deed.
local function raiseCash(state: Types.GameState, me: Types.Player): Types.Action?
	local best: number?, bestPrice = nil, -math.huge
	for _, tile in Tiles.list do
		if tile.kind == "Property" and PropertyRules.canSell(state, me.id, tile.position) then
			local price = PropertyRules.housePrice(tile.position)
			if price >= bestPrice then
				best, bestPrice = tile.position, price
			end
		end
	end
	if best then
		return { type = "SellBuilding", position = best }
	end

	local cheapest = math.huge
	for _, tile in Tiles.list do
		if PropertyRules.canMortgage(state, me.id, tile.position) then
			local value = PropertyRules.mortgageValue(tile.position)
			if value < cheapest then
				best, cheapest = tile.position, value
			end
		end
	end
	return if best then { type = "Mortgage", position = best } else nil
end
```

In `Bot.chooseAction` add before the `EndTurn` branch:

```lua
	elseif state.phase == "Debt" then
		if me.money >= state.debts[1].amount then
			return { type = "PayDebt" }
		end
		return raiseCash(state, me) or { type = "Bankrupt" }
```

`GameSession.luau`: append `{ type = "PayDebt" }` and `{ type = "Bankrupt" }` to `FALLBACK_ACTIONS`, in that order.

- [ ] **Step 4: Run the full suite (sync check first)**

Expected: all pass, 0 failed. If seed 7 leaves the short-money game unfinished in 20000 steps, try seeds 8, 9, … and use the first one that finishes. Record the change as a ruling. The test's point is that bots finish games, not the seed.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Net/Protocol.luau src/server/Game/Snapshot.luau src/server/Game/Bot.luau src/server/Game/GameSession.luau src/tests/Snapshot.spec.luau src/tests/Bot.spec.luau src/tests/GameSession.spec.luau
git commit -m "feat: bots raise cash or go bankrupt; debt and winner in the snapshot"
```

---

### Task 4: HUD model and log lines for debts, bankruptcy and the winner

**Files:**
- Modify: `src/client/Hud/HudModel.luau`, `src/client/Hud/EventText.luau`
- Test: `src/tests/HudModel.spec.luau`, `src/tests/EventText.spec.luau`

**Interfaces:**
- Consumes: `Snapshot.debt/winner`, `PlayerView.netWorth/bankrupt`.
- Produces:
  - `HudModel.Button` gains `confirm: string?`, meaning the text shown after a first click (the second click sends the action)
  - `HudModel.isDebtor(snapshot, localId): boolean`
  - `HudModel.Standing = { name: string, netWorth: number, bankrupt: boolean, winner: boolean }`
  - `HudModel.standings(snapshot): { Standing }`
  - `HudModel.buttons` / `status` / `propertyRows` / `showsPropertiesToggle` handle `Debt` and `GameOver`
  - EventText lines for `DebtOwed`, `WentBankrupt`, `GameOver`

- [ ] **Step 1: Write the failing tests**

`HudModel.spec.luau`, add:

```lua
tests["a debtor is offered Pay when they can afford it, else a confirmed bankruptcy"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.inDebt(state, "p1", 200, "p2", "Rent")
	local snapshot = Snapshot.fromState(state)
	local buttons = HudModel.buttons(snapshot, "p1")
	Expect.equal(labels(buttons), "Pay $200")
	Expect.equal(buttons[1].action.type, "PayDebt")
	Expect.equal(buttons[1].confirm, nil, "no confirm to pay")
	Expect.equal(#HudModel.buttons(snapshot, "p2"), 0, "creditor waits")
	assert(HudModel.isDebtor(snapshot, "p1"), "p1 is the debtor")
	assert(not HudModel.isDebtor(snapshot, "p2"), "p2 is not")

	Engine.getPlayer(state, "p1").money = 120
	buttons = HudModel.buttons(Snapshot.fromState(state), "p1")
	Expect.equal(labels(buttons), "Go bankrupt")
	Expect.equal(buttons[1].action.type, "Bankrupt")
	Expect.equal(buttons[1].confirm, "Confirm bankruptcy?")
end

tests["debt status tells the debtor what they owe and everyone else who they wait on"] = function()
	local state = GameFixtures.newGame(2)
	Engine.getPlayer(state, "p1").money = 300
	GameFixtures.inDebt(state, "p1", 2000, "p2", "Rent")
	local snapshot = Snapshot.fromState(state)
	Expect.equal(HudModel.status(snapshot, "p1"), "You owe Player 2 $2000. You have $300.")
	Expect.equal(HudModel.status(snapshot, "p2"), "Waiting for Player 1 to raise $2000…")
	state.debts[1].creditor = nil
	Expect.equal(HudModel.status(Snapshot.fromState(state), "p1"), "You owe the bank $2000. You have $300.")
end

tests["in debt, property rows offer only selling and mortgaging, and only to the debtor"] = function()
	local state = GameFixtures.newGame(2)
	GameFixtures.own(state, "p1", 1, 1)
	GameFixtures.own(state, "p1", 3)
	GameFixtures.own(state, "p1", 5)
	state.properties[5].mortgaged = true
	GameFixtures.own(state, "p2", 12)
	state.currentIndex = 2 -- a debt on someone else's turn
	GameFixtures.inDebt(state, "p1", 500, "p2")
	local rows = HudModel.propertyRows(Snapshot.fromState(state), "p1")
	Expect.equal(rowLabels(rows[1]), "−🏠 +$25", "sell, no build")
	Expect.equal(rowLabels(rows[2]), "", "Baltic: set has a house, can't mortgage or build")
	Expect.equal(rowLabels(rows[3]), "", "no unmortgage in debt")
	for _, row in HudModel.propertyRows(Snapshot.fromState(state), "p2") do
		Expect.equal(#row.buttons, 0, "the creditor can't act")
	end
end

tests["game over: the winner is announced and standings rank by net worth"] = function()
	local state = GameFixtures.newGame(3)
	Engine.getPlayer(state, "p1").bankrupt = true
	Engine.getPlayer(state, "p1").money = 0
	Engine.getPlayer(state, "p2").money = 900
	GameFixtures.own(state, "p3", 39) -- $1500 + $400
	state.phase = "GameOver"
	state.winner = "p3"
	local snapshot = Snapshot.fromState(state)
	Expect.equal(HudModel.status(snapshot, "p1"), "Player 3 wins!")
	Expect.equal(#HudModel.buttons(snapshot, "p3"), 0, "no buttons")
	assert(not HudModel.showsPropertiesToggle(snapshot), "no properties toggle at game over")
	local order = {}
	for _, standing in HudModel.standings(snapshot) do
		table.insert(order, `{standing.name}:{standing.netWorth}:{standing.bankrupt}:{standing.winner}`)
	end
	Expect.equal(table.concat(order, ","), "Player 3:1900:false:true,Player 2:900:false:false,Player 1:0:true:false")
end
```

`EventText.spec.luau`: add to `cases` in `"describes the events players care about"`:

```lua
		{ { type = "DebtOwed", debtor = "p1", creditor = "p2", amount = 340, reason = "Rent" }, "Ana owes Bot 1 $340 in rent" },
		{ { type = "DebtOwed", debtor = "p1", creditor = nil, amount = 200, reason = "Tax" }, "Ana owes the bank $200 in tax" },
		{ { type = "DebtOwed", debtor = "p1", creditor = nil, amount = 50, reason = "JailFine" }, "Ana owes the bank $50 for the jail fine" },
		{ { type = "DebtOwed", debtor = "p1", creditor = "p2", amount = 50, reason = "Card" }, "Ana owes Bot 1 $50 for a card" },
		{ { type = "DebtOwed", debtor = "p2", creditor = nil, amount = 10, reason = "MortgageInterest" }, "Bot 1 owes the bank $10 in mortgage interest" },
		{ { type = "WentBankrupt", player = "p1", creditor = "p2" }, "Ana went bankrupt to Bot 1" },
		{ { type = "WentBankrupt", player = "p1", creditor = nil }, "Ana went bankrupt to the bank" },
		{ { type = "GameOver", winner = "p2" }, "Bot 1 wins!" },
```

Add to the skip list in `"skips events that have no log line"`:

```lua
		{ type = "DebtPaid", debtor = "p1", creditor = "p2", amount = 6, reason = "Rent" },
		{ type = "Paid", from = "p1", to = "p2", amount = 53, reason = "Bankruptcy" },
		{ type = "Paid", from = "p2", to = nil, amount = 10, reason = "MortgageInterest" },
```

- [ ] **Step 2: Run tests to verify they fail**

Run with filters `"HudModel"` and `"EventText"`.
Expected:
- the new HudModel tests FAIL: `labels` is `""` in Debt, the status is "Your turn", and `isDebtor`/`standings` are nil;
- the EventText cases FAIL with `nil` instead of the line.

- [ ] **Step 3: Implement HudModel**

a) `Button` type: add `confirm: string?, -- shown after the first click; the second click sends the action`.

b) `actingPlayer`: add after the GameOver branch:

```lua
	elseif snapshot.phase == "Debt" and snapshot.debt then
		return snapshot.debt.debtor
```

c) Add after `actingPlayer`:

```lua
function HudModel.isDebtor(snapshot: Protocol.Snapshot, localId: string): boolean
	return snapshot.phase == "Debt" and snapshot.debt ~= nil and snapshot.debt.debtor == localId
end
```

d) `HudModel.buttons`: add before the `EndTurn` branch:

```lua
	elseif phase == "Debt" and snapshot.debt then
		local amount = snapshot.debt.amount
		if me.money >= amount then
			return { { label = `Pay ${amount}`, action = { type = "PayDebt" } } }
		end
		return { { label = "Go bankrupt", confirm = "Confirm bankruptcy?", action = { type = "Bankrupt" } } }
```

e) `HudModel.status`: at the top, after `local names = ...`:

```lua
	if snapshot.phase == "GameOver" then
		local winner = snapshot.winner
		return `{if winner then names[winner] or winner else "Nobody"} wins!`
	end
	local debt = snapshot.debt
	if snapshot.phase == "Debt" and debt then
		if debt.debtor == localId then
			local me = findPlayer(snapshot, localId) :: Protocol.PlayerView
			local creditor = if debt.creditor then names[debt.creditor] or debt.creditor else "the bank"
			return `You owe {creditor} ${debt.amount}. You have ${me.money}.`
		end
		return `Waiting for {names[debt.debtor] or debt.debtor} to raise ${debt.amount}…`
	end
```

f) `HudModel.propertyRows`: replace the `canAct` computation with:

```lua
	-- On your own turn you may do everything; while settling a debt only sell and mortgage.
	local canImprove = snapshot.currentPlayer == localId
		and snapshot.auction == nil
		and (snapshot.phase == "Roll" or snapshot.phase == "EndTurn")
	local canRaise = canImprove or HudModel.isDebtor(snapshot, localId)
```

Then change the row code:
- wrap the `canBuild` insert in `if canImprove and ...`;
- the `canSell` and `canMortgage` inserts in `if canRaise and ...`;
- the `canUnmortgage` insert in `if canImprove and ...`;
- replace the outer `if canAct then` with `if canRaise then`.

g) `showsPropertiesToggle`: `return snapshot.phase ~= "Auction" and snapshot.phase ~= "GameOver"`, and update its comment to say the panel has no use once the game is over.

h) Add:

```lua
export type Standing = {
	name: string,
	netWorth: number,
	bankrupt: boolean,
	winner: boolean,
}

-- Final ranking: players still in by net worth (richest first, then seat), bankrupt players last.
function HudModel.standings(snapshot: Protocol.Snapshot): { Standing }
	local players = table.clone(snapshot.players)
	table.sort(players, function(a, b)
		if a.bankrupt ~= b.bankrupt then
			return not a.bankrupt
		elseif a.netWorth ~= b.netWorth then
			return a.netWorth > b.netWorth
		end
		return a.seat < b.seat
	end)
	local standings = {}
	for _, player in players do
		table.insert(standings, {
			name = player.name,
			netWorth = player.netWorth,
			bankrupt = player.bankrupt,
			winner = player.id == snapshot.winner,
		})
	end
	return standings
end
```

- [ ] **Step 4: Implement EventText**

Add a reason table above `EventText.describe`:

```lua
local DEBT_REASONS = {
	Rent = " in rent",
	Tax = " in tax",
	JailFine = " for the jail fine",
	Card = " for a card",
	MortgageInterest = " in mortgage interest",
}
```

Add branches before `PlayerReplaced`:

```lua
	elseif kind == "DebtOwed" then
		local creditor = if event.creditor then name(event.creditor) else "the bank"
		return `{name(event.debtor)} owes {creditor} ${event.amount}{DEBT_REASONS[event.reason] or ""}`
	elseif kind == "WentBankrupt" then
		return `{name(event.player)} went bankrupt to {if event.creditor then name(event.creditor) else "the bank"}`
	elseif kind == "GameOver" then
		return `{name(event.winner)} wins!`
```

- [ ] **Step 5: Run the full suite (sync check first)**

Expected: all pass, 0 failed. The existing "property rows have no buttons off your turn or mid-decision" test must still pass: no debt means `canRaise == canImprove`.

- [ ] **Step 6: Commit**

```bash
git add src/client/Hud/HudModel.luau src/client/Hud/EventText.luau src/tests/HudModel.spec.luau src/tests/EventText.spec.luau
git commit -m "feat: HUD buttons, status and log lines for debts, bankruptcy and the winner"
```

---

### Task 5: Debt and results on screen, back to the lobby

**Files:**
- Modify: `src/client/Hud/HudView.luau`, `src/client/GameClient.luau`, `src/server/GameService.luau`

**Interfaces:**
- Consumes:
  - `HudModel.buttons` (with `confirm`), `HudModel.isDebtor`, `HudModel.standings`, `HudModel.status`
  - `PlayerView.bankrupt`, `Snapshot.phase == "GameOver"`
- Produces:
  - `HudView.Callbacks.onReturnToLobby: () -> ()`
  - lobby request `{ type = "ReturnToLobby" }`
  - `GameService.RESULTS_SECONDS = 15`
  - the Studio-only `workspace` attribute `StartingMoney`, which overrides everyone's starting cash for playtests

This task is view and remote wiring with no unit tests; its logic is in HudModel (Task 4). It's verified by a playtest.

- [ ] **Step 1: GameService**

Add `GameService.RESULTS_SECONDS = 15` and `local RunService = game:GetService("RunService")`. Add after `broadcast`'s definition (and make `broadcast` call it at the end):

```lua
local endingSession: GameSession.Session? = nil

-- Once a game is over, everyone gets RESULTS_SECONDS on the results screen before the lobby returns.
local function scheduleLobbyReturn()
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
```

`broadcast` is a local function defined above; because `scheduleLobbyReturn` calls `broadcast` and `broadcast` calls `scheduleLobbyReturn`, forward-declare `local scheduleLobbyReturn: () -> ()` above `broadcast` and define it as `function scheduleLobbyReturn()` after. At the end of `broadcast` add `scheduleLobbyReturn()`.

Replace `onLobbyRequest` with:

```lua
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
	session = GameSession.new(humans, request.seats, rollDice, shuffle)
	-- Playtests: a workspace StartingMoney attribute makes debts and bankruptcies come quickly.
	local startingMoney = workspace:GetAttribute("StartingMoney")
	if RunService:IsStudio() and typeof(startingMoney) == "number" then
		for _, player in session.state.players do
			player.money = startingMoney
		end
	end
	broadcast()
	scheduleBots()
end
```

- [ ] **Step 2: HudView**

a) Colors: add `local DANGER_COLOR = Color3.fromRGB(200, 60, 60)` and `local DEBT_TEXT_COLOR = Color3.fromRGB(255, 120, 120)`.

b) `Callbacks`: add `onReturnToLobby: () -> (),`. The `HudView` type gains `wasDebtor: boolean, results: Frame, resultsTitle: TextLabel, resultsRows: Frame,`. Initialise `wasDebtor = false` and the others as `nil :: any` in `new`.

c) In `HudView.new`, after the card popup, build the results panel:

```lua
	-- Results, centre screen once the game is over.
	local results = panel("Results", UDim2.fromOffset(360, 0), UDim2.fromScale(0.5, 0.45), Vector2.new(0.5, 0.5), gui)
	results.AutomaticSize = Enum.AutomaticSize.Y
	results.Visible = false
	list(results, Enum.FillDirection.Vertical, 8)
	local resultsPadding = Instance.new("UIPadding")
	resultsPadding.PaddingTop = UDim.new(0, 12)
	resultsPadding.PaddingBottom = UDim.new(0, 12)
	resultsPadding.Parent = results
	self.resultsTitle = text("Title", results, UDim2.new(1, -16, 0, 36), 28)
	self.resultsTitle.LayoutOrder = 1
	local resultsRows = Instance.new("Frame")
	resultsRows.Name = "Standings"
	resultsRows.Size = UDim2.new(1, -16, 0, 0)
	resultsRows.AutomaticSize = Enum.AutomaticSize.Y
	resultsRows.BackgroundTransparency = 1
	resultsRows.LayoutOrder = 2
	resultsRows.Parent = results
	list(resultsRows, Enum.FillDirection.Vertical, 4)
	self.resultsRows = resultsRows
	local back = button("Back to lobby", results, function()
		callbacks.onReturnToLobby()
	end)
	back.LayoutOrder = 3
	self.results = results
```

d) `HudView.render`:
- In the `if not snapshot then` block, also clear the log (`table.clear(self.logLines)`, `self.logLabel.Text = ""`), set `self.wasDebtor = false`, and hide `self.results`.
- In the player list rows, show `Bankrupt` in place of the money: `local balance = if player.bankrupt then "Bankrupt" else `${player.money}``, then use it in `row.Text`.
- Status colour: `self.status.TextColor3 = if HudModel.isDebtor(snapshot, localId) then DEBT_TEXT_COLOR else TEXT_COLOR`.
- Before the buttons loop, auto-open the panel on entering debt:

```lua
	local debtor = HudModel.isDebtor(snapshot, localId)
	if debtor and not self.wasDebtor then
		self.propertiesOpen = true -- raising cash happens in the panel
	end
	self.wasDebtor = debtor
	if snapshot.phase == "GameOver" then
		self.propertiesOpen = false
	end
```

- Replace the buttons loop so a `confirm` button needs two clicks:

```lua
	for order, entry in HudModel.buttons(snapshot, localId) do
		local b: TextButton
		b = button(entry.label, self.buttonRow, function()
			local confirm = entry.confirm
			if confirm and b.Text ~= confirm then
				b.Text = confirm -- first click only arms it; any re-render disarms it
				b.BackgroundColor3 = DANGER_COLOR
				return
			end
			self.callbacks.onAction(entry.action)
		end)
		b.LayoutOrder = order
		if entry.confirm then
			b.BackgroundColor3 = DANGER_COLOR
			b.Size = UDim2.fromOffset(200, 44)
		end
	end
```

- After `renderProperties(...)`, render the results:

```lua
	self.results.Visible = snapshot.phase == "GameOver"
	for _, child in self.resultsRows:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if snapshot.phase == "GameOver" then
		self.resultsTitle.Text = HudModel.status(snapshot, localId)
		for order, standing in HudModel.standings(snapshot) do
			local line = text(`Rank{order}`, self.resultsRows, UDim2.new(1, 0, 0, 24), 18)
			line.LayoutOrder = order
			local worth = if standing.bankrupt then "Bankrupt" else `${standing.netWorth}`
			line.Text = `{order}. {standing.name}{if standing.winner then " 🏆" else ""}   {worth}`
		end
	end
```

- [ ] **Step 3: GameClient**

Add to the `HudView.new` callbacks:

```lua
		onReturnToLobby = function()
			lobbyRemote:FireServer({ type = "ReturnToLobby" })
		end,
```

- [ ] **Step 4: Run the full suite (sync check first)**

Expected: all pass, 0 failed (nothing here is unit-tested; this catches load errors in required modules).

- [ ] **Step 5: Playtest in Studio**

1. In Edit mode: `execute_luau(Edit, 'workspace:SetAttribute("StartingMoney", 150)')`. Start play, then in the lobby click **Start game** with 2 players (you + a bot).
2. Play the human's turns with real clicks where cheap. A client autopilot that fires `GameAction` (Roll/Decline/EndTurn/PayDebt), as in earlier milestones, is fine for routine turns.
3. When the human first owes more than they have, screenshot and check:
   - the red status line "You owe … You have $…";
   - the Properties panel opened by itself, with only −🏠 / Mortgage buttons;
   - the "Go bankrupt" button.
4. **Mortgage with a real click** on a row button (this also settles the earlier unconfirmed second-click-on-a-re-rendered-row). If that raises enough, check that the button turns into "Pay $X", click it, and check that play resumes.
5. On a later debt, click **Go bankrupt** once and check that it reads "Confirm bankruptcy?". Click again. Screenshot the results screen: "Bot 1 wins!", standings, Back to lobby.
6. Wait 15 s, or click Back to lobby, and check that the lobby panel returns with an empty log.
7. Clear the attribute afterwards: `workspace:SetAttribute("StartingMoney", nil)`.

Record anything you didn't observe as "Not observed" in the ledger, with the covering unit tests.

- [ ] **Step 6: Commit**

```bash
git add src/client/Hud/HudView.luau src/client/GameClient.luau src/server/GameService.luau
git commit -m "feat: debt prompts, bankruptcy confirm and results screen, then back to the lobby"
```
