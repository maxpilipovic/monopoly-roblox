# UI Overhaul 2 — Cards, Deeds, Dice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline; design decisions delegated by the user). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A drawn card is an event (face-down card that flips to a readable face with an effect badge); buying and bidding show the property's deed; dice are drawn and tumble.

**Architecture:** Pure models decide content (`CardFace`, `DeedModel`, `Dice.pips`, `HudModel.deedFocus`, `CardQueue.dismiss`); three new views draw it (`CardReveal`, `DeedCard`, `Dice`). Both cards use the empty centre of the board; the card reveal has priority over the deed.

**Tech Stack:** Luau (`--!strict`), Roblox Studio, Rojo 7.7, tests inside Studio via the `RunTests` hook.

**Spec:** `docs/superpowers/specs/2026-10-01-ui-overhaul-design.md` — Card reveal, Deed card, Action bar (dice).

## Global Constraints

- Client-only, plus one shared read-only addition: `Cards.titleFor(cardId)`. No Engine/Protocol changes.
- Cards still queue one at a time, never before their token arrives (`CardQueue` semantics unchanged); each stays up to 5 s; clicking dismisses it.
- Every drawn card is shown to every player.
- Deck colours: Chance `Theme.color.chance`, Community Chest `Theme.color.chest`. Paper `Theme.color.paper`, ink `Theme.color.ink`.
- Railroad rent 25/50/100/200 and utility multipliers 4×/10× mirror the server's `Rent` constants; a test pins them.
- All existing tests keep passing (344 before this plan).

## Review Focus

1. A card drawn on one map and shown after the map changed keeps its own deck title (`Cards.titleFor`).
2. Two cards queued back to back (card sends you to another card tile): the second plays its own flip after the first leaves; dismissing the first shows the second at once, not before its token arrives.
3. Back to the lobby mid-reveal: the card disappears and no animation thread touches destroyed instances.
4. A deed for a mortgaged or unowned tile highlights no rent line; an owned set highlights "With full set"; houses highlight their own line.
5. The deed never covers a card reveal or the trade window; it hides when the phase moves on.

---

### Task 1: Card faces and dismissal

**Files:** Modify `src/shared/Board/Cards.luau`, `src/client/Hud/CardQueue.luau`; Create `src/client/Hud/CardFace.luau`; Test `src/tests/CardFace.spec.luau`, `src/tests/CardQueue.spec.luau` (append), `src/tests/Cards.spec.luau` (append).

**Produces:**
- `Cards.titleFor(cardId: string): string?` — the deck title on the card's own map ("Pop Quiz" for `college.chance.*` whatever map is active).
- `export type Tone = "good" | "bad" | "neutral"`; `export type Face = { id: string, deck: string, title: string, drawer: string, text: string, badge: { text: string, tone: Tone } }`; `CardFace.of(cardId: string, drawer: string): Face?` (nil for an unknown id).
- Badges: Collect `+$50` good · Pay `−$15` bad · PayEachPlayer `−$50 each` bad · CollectFromEachPlayer `+$10 each` good · AdvanceTo `→ <tile name>` neutral · AdvanceToNearest `→ Nearest railroad` / `→ Nearest utility` (college: `shuttle`) neutral · GoBack `← 3 spaces` neutral · GoToJail `Go to <jail tile name>` bad · JailFree `Keep this card` good · Repairs `−$25 per house · −$100 per hotel` bad.
- `CardQueue.push(queue, deck, text, notBefore, face: CardFace.Face?)` (items gain `face`); `CardQueue.dismiss(queue, now)` — ends the card showing now so the next may start at `now` (still not before its own `notBefore`); does nothing if none is showing.

- [ ] Tests: one badge per effect kind (classic), the college jail and shuttle wording under `MapTestHelper.onCollege`, title from the card's own map on the other map, unknown id → nil; `dismiss` ends the current card, the next waits for its `notBefore`, dismissing with nothing showing changes nothing; `titleFor` for both maps on both maps.
- [ ] Run → fail; implement; run all → green; commit `feat: card faces with effect badges; cards can be dismissed`.

### Task 2: Deed model

**Files:** Create `src/client/Hud/DeedModel.luau`; Modify `src/client/Hud/HudModel.luau`; Test `src/tests/DeedModel.spec.luau`, `src/tests/HudModel.spec.luau` (append).

**Produces:**
- `export type Line = { label: string, value: string, current: boolean }`; `export type Deed = { position: number, name: string, kind: string, color: Color3?, price: number, lines: { Line }, footer: { { label: string, value: string } }, owner: string?, mortgaged: boolean }`; `DeedModel.of(position: number, snapshot: Protocol.Snapshot?): Deed?` (nil for tiles that can't be owned).
- `DeedModel.RAILROAD_RENT = { 25, 50, 100, 200 }`, `DeedModel.UTILITY_MULTIPLIER = { 4, 10 }`.
- Property lines: `Rent`, `With full set`, `1 house` … `4 houses`, `Hotel`; footer `House cost`, `Mortgage value`. Railroad: `1 owned` … `4 owned`; utility: `One owned` `4× dice`, `Both owned` `10× dice`; footer `Mortgage value`.
- `HudModel.deedFocus(snapshot): number?` — the auction's tile during an auction, the current player's tile in `BuyDecision`, else nil.

- [ ] Tests: Boardwalk unowned (7 lines, values, no current, colour, footer), owned alone → `Rent` current, full set → `With full set`, 2 houses → `2 houses`, hotel → `Hotel`, mortgaged → none; railroad with 2 owned → `2 owned` current and `$50`; utility with both → `Both owned`; Go → nil; constants equal the server's `Rent`; `deedFocus` per phase.
- [ ] Run → fail; implement; run all → green; commit `feat: deed model — rent table with the line that applies`.

### Task 3: Dice pips

**Files:** Create `src/client/Hud/Views/Dice.luau`; Test `src/tests/Dice.spec.luau`.

**Produces:** `Dice.pips(value: number): { Vector2 }` — pip centres on a 3 × 3 grid (coordinates 1–3) for faces 1–6; `Dice.new(parent): Dice` (a frame named `Dice` with two faces); `Dice.show(self, roll: { number }?, tumble: boolean)` — nil hides; tumble plays ~0.45 s of random faces first.

- [ ] Tests: a face has as many pips as its value; odd faces have the centre pip, even ones don't; every pattern is symmetric under a half turn; values outside 1–6 error; `show({3, 5}, false)` draws 3 and 5 pips, `show(nil)` hides.
- [ ] Run → fail; implement; run → green; commit with Task 4.

### Task 4: Views and wiring

**Files:** Create `src/client/Hud/Views/CardReveal.luau`, `src/client/Hud/Views/DeedCard.luau`; Modify `src/client/Hud/HudView.luau`, `src/client/Hud/Views/ActionBar.luau`, `src/client/Hud/Views/PropertiesPanel.luau`, `src/client/GameClient.luau`; Test `src/tests/HudView.spec.luau` (append).

**Produces:**
- `CardReveal.new(parent, onDismiss: () -> ())` → `{ frame }`; `CardReveal.show(self, face: CardFace.Face?)` — nil hides at once; a new face starts face-down, flips, holds.
- `DeedCard.new(parent, onClose: () -> ())` → `{ frame }`; `DeedCard.render(self, deed: DeedModel.Deed?, note: string?, closable: boolean)`.
- `HudView.showCard(self, cardId: string, drawer: string, notBefore: number)` (replaces the deck/text form); `HudView.diceRolled(self)` — the next render tumbles the dice; `HudView.inspect(self, position: number?)` — pins a deed opened from the Properties panel (cleared by its close button, the lobby, or game over).
- `PropertiesPanel.new(parent, send, inspect: (position: number) -> ())`: clicking a row's name inspects it.
- The status line no longer carries the dice text; `ActionBar` holds the `Dice` view at its right edge.
- `GameClient`: `hud:showCard(event.card, names[event.player] or event.player, when)`; `hud:diceRolled()` on a `Rolled` event.

- [ ] Tests (smoke): BuyDecision shows the deed card with the tile's name; an auction shows it with a bid note; Roll hides it; a queued card shows the reveal and hides the deed until dismissed; lobby hides both; `inspect(39)` shows Boardwalk's deed in a Roll phase and `inspect(nil)` hides it; after a roll the dice frame is visible with the rolled pips.
- [ ] Run → fail; implement; run all → green.
- [ ] Playtest: draw a card (screenshot back, face), buy decision (deed), auction (deed + bid), dice after a roll.
- [ ] Commit `feat: card reveal, deed cards and drawn dice`.
