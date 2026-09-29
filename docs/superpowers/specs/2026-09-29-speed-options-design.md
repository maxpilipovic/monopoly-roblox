# Speed Options — Design

Milestone 5. Agreed in conversation on 2026-09-29.

## Goal

The player who starts a game picks two speed options in the lobby:
- a **turn timer**, so nobody can stall the game and, if wanted, play stays brisk;
- a **game length** in rounds or minutes. When it's reached, the richest player wins.

When a human's timer runs out, the server plays a safe default move for them.

## Decisions

| Topic | Decision |
|---|---|
| Timer presets | **Off**, **Relaxed** (60 s), **Fast** (20 s). Default: Relaxed. |
| What the timer times | **Each decision**, not a whole turn. The clock restarts whenever the game starts waiting on a different player or phase, and whenever the waiting player makes a successful move. An auction bid gets a third of the timer, rounded up (20 s or 7 s). |
| On timeout | **Safe defaults**: never spend the player's money by choice. There is no kick and no bot takeover. |
| Game length | **Off**, **15 / 25 / 40 rounds**, or **30 / 45 / 60 minutes**. One limit at most. Default: Off. |
| When a limit ends the game | Only at a turn change, so the current turn always finishes. |
| Winner at the limit | The highest net worth among players still in, with ties going to the earlier seat. This is the rule bankruptcy endings already use. |
| Who picks | Whoever presses **Start**. The settings travel with the Start request. |
| Bots | Never timed; they keep their 0.8 s pacing. |
| Architecture | The engine stays free of clocks. The server owns real time; pure modules decide default moves, deadlines and the limit rules. |

## Rules

### Settings (`MatchSettings`, shared, pure)

```
Settings = { timer: "Off" | "Relaxed" | "Fast", length: LengthId }
LengthId = "Off" | "Rounds15" | "Rounds25" | "Rounds40" | "Minutes30" | "Minutes45" | "Minutes60"
```

- `MatchSettings.DEFAULT = { timer = "Relaxed", length = "Off" }`.
- `validate(raw: any): Settings` never fails. Anything that isn't a known id falls back to that field's default.
- `timerSeconds(settings)` gives 0, 60 or 20. `bidSeconds(settings)` gives `math.ceil(timerSeconds / 3)`.
- `roundLimit(settings)` gives a number or nil. `limitMinutes(settings)` gives a number or nil.
- `nextTimer(id)` and `nextLength(id)` cycle through the options in the order listed above, wrapping round.
- `timerLabel(id)` gives "Timer: Relaxed 60 s", "Timer: Fast 20 s" or "Timer: Off". `lengthLabel(id)` gives "Length: 25 rounds", "Length: 30 min" or "Length: Off".

### Game length (engine)

- **New state:**
  - `round: number` starts at 1.
  - `roundLimit: number?` is passed to `Engine.new` as an optional fifth argument.
  - `timeUp: boolean` starts false.
- **Counting rounds:** when `endTurn` moves to the next player and the new seat index is at or below the old one (a wrap, whatever bankrupt seats were skipped), `round` goes up by 1.
- **Ending by the limit:** in `endTurn`, after choosing the next player and before emitting `TurnStarted`:
  - if `roundLimit` is set and `round > roundLimit`, finish with reason `"RoundLimit"`;
  - otherwise, if `timeUp` is set, finish with reason `"TimeLimit"`.

  Because this only happens in `endTurn`, doubles, auctions, debts and trade offers from the current turn all finish first. A bankrupt current player's turn also ends through `endTurn`, via `resume`, so the check covers that path too.
- **`Engine.markTimeUp(state)`** sets `timeUp`. It does nothing once the phase is GameOver.
- **`finishGame(state, reason)`** is extracted from `endIfOver`. It picks the winner by net worth among non-bankrupt players, with ties to the earlier seat. It sets GameOver, clears debts, the auction queue and `resumePhase`, and emits `GameOver { winner, reason }`. `endIfOver` uses it with reason `"Bankruptcy"`.

### Default moves (`Timeouts`, server, pure)

`Timeouts.defaultAction(state, playerId): Action?` returns nil when `playerId` isn't the acting player. Otherwise:

| Phase | Default |
|---|---|
| Roll | `Roll`. In jail this is a doubles attempt; the engine already forces the fine after the third miss. |
| BuyDecision | `Decline` |
| Auction | `PassBid` |
| EndTurn | `EndTurn` |
| Trade | `DeclineTrade` |
| Debt | `PayDebt` if the player can afford it. Otherwise `Bot.raiseCash` (made public: sell the priciest building, else mortgage the cheapest bare deed). With nothing left to raise, `Bankrupt`. |

`GameSession.timeout(session, playerId): boolean` plays the default through `Engine.act`. If the engine refuses it, it tries the existing fallback list, as `stepBot` does. In **Debt**, it keeps playing defaults while that same player is still the acting debtor, capped at 100 steps as a safety net, so one timeout settles the whole debt. Everywhere else, one timeout is one move.

### Deadlines (`TurnClock`, server, pure)

```
Clock = { key: string?, deadline: number? }
TurnClock.update(clock, state, settings, now, actedBy: string?)
```

- **key** = `actingPlayer .. "|" .. phase`, or nil when nobody is acting (GameOver).
- **No deadline:** the timer is Off, the acting player is a bot, or the key is nil.
- **Deadline:** otherwise, when the key changed, or `actedBy` is the acting player, or there is no deadline yet, the deadline becomes `now + seconds`. `seconds` is `bidSeconds` in an Auction and `timerSeconds` in every other phase. Otherwise the deadline is kept.

### Server (`GameService`)

- **Start:** the Start request carries the settings, and the server runs them through `MatchSettings.validate`. The session stores them and passes `roundLimit` to `Engine.new`. With a minutes limit, the session records `endsAt = now + minutes × 60`, and a `task.delay` calls `GameSession.markTimeUp` and broadcasts. That delay is ignored if the session has changed since.
- **The clock:** after every state change (action, bot step, timeout, player leaving), the server calls `TurnClock.update`, passing `actedBy` = the player whose action just succeeded. If there's a deadline, it schedules one `task.delay` check tagged with a generation number, so stale checks do nothing. A check that fires at or after the deadline calls `GameSession.timeout` for the acting player, broadcasts, and schedules bots.
- **Time source:** `workspace:GetServerTimeNow()`, so clients can count down against the same clock.
- **Studio-only playtest attributes on `workspace`:**
  - `TimerSeconds` overrides the timer length;
  - `LimitMinutes` sets a minutes limit (fractions allowed);
  - `RoundLimit` sets a round limit.

  They sit beside the existing `StartingMoney` attribute.

## Snapshot and protocol

- **Start request:** `{ type = "Start", seats, timer, length }`.
- **`Snapshot.match`:**

  ```
  {
    timer: string,          -- the timer preset id
    length: string,         -- the length id
    round: number,
    roundLimit: number?,
    endsAt: number?,        -- server time when the minutes limit runs out
    turnDeadline: number?,  -- server time when the acting human's decision times out
  }
  ```

- `Snapshot.fromState(state, match?)` takes the session-side values (`timer`, `length`, `endsAt`, `turnDeadline`). Without them, it defaults to Off/Off with no deadlines, so existing callers and tests keep working.
- **`GameOver` event:** gains `reason`. Log lines:
  - Bankruptcy: unchanged, "Max wins!"
  - RoundLimit: "Round limit reached — Max wins!"
  - TimeLimit: "Time's up — Max wins!"
- **`Snapshot.winReason`** carries the reason, so the results title can use it.

## HUD

- **Lobby:** two cycle buttons under the seat row, showing `timerLabel` and `lengthLabel`. The client remembers the choice until Start and sends it with the seats.
- **Countdown:** `HudModel.countdown(snapshot, now): (string?, boolean)` returns text such as "0:14", plus `urgent` (true in the last 5 seconds). It returns nil when there's no `turnDeadline`, and never shows below 0:00.
  - It's appended to the status line: "Your turn · 0:14", "Waiting for Ana · 0:42".
  - The status turns red when urgent. The existing Heartbeat hook refreshes it every frame.
- **Match line:** `HudModel.matchLine(snapshot, now): string?` returns "Fast · Round 7 of 25", "Relaxed · 23:10 left" or "Fast", shown under the player list.
  - With a minutes limit that has run out, it reads "Relaxed · Final turn".
  - It returns nil when the timer and the length are both Off.
- **Results:** the title reads from the reason ("Time's up — Max wins!" and so on).

## Testing

- **MatchSettings spec:**
  - defaults, and validating garbage (wrong types, unknown ids, missing fields);
  - cycle order and wrap-around;
  - labels, seconds and bid seconds.
- **Limits spec (engine):**
  - round counting, including a wrap past bankrupt seats;
  - the round limit ends the game after the last turn of the last round, not before;
  - `timeUp` ends the game at the next turn change, not mid-turn: a doubles roll, an auction and a debt all finish first;
  - the winner is chosen by net worth, with ties to the earlier seat;
  - `GameOver.reason` for all three endings;
  - `markTimeUp` after GameOver does nothing.
- **Timeouts spec:**
  - the default in every phase, including jail and Trade;
  - a debt settled by selling, then mortgaging, then bankruptcy;
  - nil for a non-acting player;
  - `GameSession.timeout` settles a whole debt in one call, and plays one move elsewhere.
- **TurnClock spec:**
  - the deadline resets on a key change and on the acting player's own move;
  - it is kept when another player acts (e.g. a bot bidding in an auction), unless the key changes;
  - auctions use bid seconds;
  - there is no deadline for bots, with the timer Off, or at GameOver.
- **Snapshot, HudModel, EventText specs:**
  - the match fields;
  - countdown formatting, urgency and clamping;
  - match-line variants;
  - GameOver lines per reason.
- **Playtest in Studio** (using `TimerSeconds`, `LimitMinutes` and `RoundLimit`):
  - let the timer run out in Roll, BuyDecision, an auction, EndTurn, a trade offer and a debt;
  - finish a game by the round limit and by the time limit;
  - check the lobby buttons, the countdown and the match line.

## Out of scope

- Kicking or bot-replacing AFK players (a player who leaves already becomes a bot).
- Per-player time banks, pausing, a host role or voting on settings.
- Remembering settings between games.
- Showing the clock on the 3D board.
