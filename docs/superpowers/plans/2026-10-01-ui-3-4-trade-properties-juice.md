# UI Overhaul 3 + 4 — Trade, Properties, Juice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline; design decisions delegated by the user). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trading reads at a glance (deed chips in set colours, an offer card everyone can see), the properties panel is grouped by set, and the game reacts: a turn banner, money that counts and floats, a draining turn timer, confetti for the winner.

**Architecture:** New pure helpers in `HudModel` (`tradeOffer`, `propertyGroups`, `moneyDeltas`, `becameMyTurn`, `timerFraction`) feed redrawn views (`TradeWindow`, `OfferCard`, `PropertiesPanel`, `PlayerList`, `ActionBar`, `Results`) and one new view (`TurnBanner`). `HudView` keeps the previous snapshot to derive changes.

**Tech Stack:** Luau (`--!strict`), Roblox Studio, Rojo 7.7, tests inside Studio via the `RunTests` hook.

**Spec:** `docs/superpowers/specs/2026-10-01-ui-overhaul-design.md` — Trade window, Offer card, Properties panel, Player list, Action bar (timer), Turn banner, Results.

## Global Constraints

- Client-only; no server or Protocol change. `TradeBuilder` and `TradeRules` decide what may be offered; views only draw.
- The trade window and the properties panel rebuild only when what they show changes (clicks and scroll survive bot moves).
- Texts kept for lookups: partner buttons carry the partner's name; `Send offer`, `Cancel`; property action buttons keep `HudModel` labels; properties rows are named by the tile name.
- Motion never blocks input and never touches destroyed instances.
- All existing tests keep passing (365 before this plan).

## Review Focus

1. A spectator and the proposer see the open offer from their own point of view, never with Accept/Decline.
2. A deed that became untradable after being picked can still be unpicked (chip stays clickable) and says why it can't be traded.
3. Money deltas ignore players who joined or left between snapshots, and a new game (lobby → game) shows no floaters.
4. Rolling doubles (same player, new Roll phase) does not replay the "YOUR TURN" banner; a bot-held seat or spectator never sees it.
5. The timer bar is empty-safe: no deadline → hidden; a deadline in the past → zero width, not negative.

---

### Task 1: Models

**Files:** Modify `src/client/Hud/HudModel.luau`; Test `src/tests/HudModel.spec.luau` (append).

**Produces:**
- `export type Chip = { position: number, name: string, color: Color3?, mortgaged: boolean }`; `export type OfferSide = { title: string, chips: { Chip }, cash: number, jailCards: number }`; `export type Offer = { title: string, left: OfferSide, right: OfferSide }`.
- `HudModel.tradeOffer(snapshot, localId): Offer?` — nil unless an offer is open. Receiver: title `<from> offers you a trade`, left `You give` (= trade.get), right `You get` (= trade.give). Proposer: `Your offer to <to>`, left `You give` (= give), right `You get` (= get). Anyone else: `<from> offers <to> a trade`, left `<from> gives`, right `<to> gives`.
- `export type PropertyGroup = { key: string, title: string, color: Color3?, owned: number, size: number, rows: { PropertyRow } }`; `HudModel.propertyGroups(rows: { PropertyRow }): { PropertyGroup }` — groups in the order their first row appears; titles `Brown`, `Light Blue`, …, `Railroads`, `Utilities`; `size` 4 for railroads, 2 for utilities, else the colour set's size.
- `HudModel.moneyDeltas(previous: Snapshot?, next: Snapshot): { [string]: number }` — non-zero cash changes for players present in both.
- `HudModel.becameMyTurn(previous: Snapshot?, next: Snapshot, localId): boolean` — next is `Roll` phase with the local, seated, human player current, and previous was nil or had someone else current.
- `HudModel.timerFraction(snapshot, now): number?` — share of the acting player's decision time left, 0–1; nil without a deadline. Total is `MatchSettings.bidSeconds(timer)` during an auction, else the timer's seconds.

- [ ] Tests for each (receiver / proposer / spectator offers with a mortgaged deed, cash and jail cards; groups with counts and titles; deltas incl. a player missing from one side and nil previous; banner cases incl. doubles and spectator; timer fraction mid-turn, past deadline → 0, auction total, no deadline → nil).
- [ ] Run → fail; implement; run all → green; commit `feat: HUD models for offers, property sets, money changes, turn start and the timer`.

### Task 2: Trade window, offer card, properties panel

**Files:** Rewrite `src/client/Hud/Views/TradeWindow.luau`, `OfferCard.luau`, `PropertiesPanel.luau`; Modify `src/client/Hud/Ui.luau` (`Ui.chip`), `src/client/Hud/HudView.luau`; Test `src/tests/HudView.spec.luau`, `src/tests/HudUi.spec.luau`.

**Produces:**
- `Ui.chip(text, parent, color: Color3?, state: "normal" | "selected" | "disabled", onClick: (() -> ())?): TextButton` — a deed chip: colour bar, name, gold outline and tick when selected, dim when disabled; `Text` mirrors the label.
- `OfferCard.render(self, offer: HudModel.Offer?)`.
- `PropertiesPanel.render(self, open, groups: { HudModel.PropertyGroup }, emptyText)`.
- `TradeWindow.render` signature unchanged.

- [ ] Tests: chip states (selected has the tick and accent stroke; disabled doesn't fire; text mirrored); smoke: receiver, proposer and a spectator all see the offer card with the right title, only the receiver has Accept/Decline; properties panel shows a set header (`Brown 1/2`) and the row; trade window lists the local player's deeds as chips and toggling one marks it selected.
- [ ] Run → fail; implement; run all → green; playtest screenshots (trade window with deeds on both sides, an incoming bot offer, grouped properties); commit `feat: trade window and offer card with deed chips; properties grouped by set`.

### Task 3: Juice

**Files:** Create `src/client/Hud/Views/TurnBanner.luau`; Modify `PlayerList.luau`, `ActionBar.luau`, `Results.luau`, `HudView.luau`; Test `src/tests/HudView.spec.luau`.

**Produces:**
- `TurnBanner.new(parent)` → `{ frame }`; `TurnBanner.play(self)` — shows for ~1.4 s.
- `PlayerList.render(self, rows, deltas: { [string]: number }?)` — counts money from its last shown value and floats each delta.
- `ActionBar.setTimer(self, fraction: number?, urgent: boolean)` — a bar named `Timer` along the top edge; nil hides.
- `Results.render` plays a confetti burst when it first shows a winner.

- [ ] Tests (smoke): the banner shows when the turn becomes the local player's and not for a spectator; a money change adds a floater under that player's row; the timer bar is hidden without a deadline and sized by the fraction with one; results spawn confetti once, not again on a re-render.
- [ ] Run → fail; implement; run all → green; playtest; commit `feat: turn banner, money that counts and floats, a draining turn timer, winner confetti`.

### Task 4: Wrap up

- [ ] Full suite green; whole-branch review (one reviewer on the most capable model, both plans' Review Focus plus plans 1–2); fix Important findings test-first; record minors in `docs/superpowers/plans/2026-10-01-ui-overhaul.followups.txt`.
- [ ] Ask the user before merging to `main` and pushing.
