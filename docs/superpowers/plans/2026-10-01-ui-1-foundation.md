# UI Overhaul 1 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (the user chose inline execution and delegated design decisions). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One visual language and a scalable layout for the whole HUD: every existing screen restyled with the same information as today, split into one module per screen.

**Architecture:** `Theme` holds the tokens, `Ui` builds styled widgets, `Layout` (pure) does scaling math. `HudView` becomes a coordinator over `Hud/Views/*`; its public API is unchanged. New pure helpers (`HudModel.playerRows`, `LogFormat.rich`) carry what the views show.

**Tech Stack:** Luau (`--!strict`), Roblox Studio, Rojo 7.7, tests inside Studio.

**Spec:** `docs/superpowers/specs/2026-10-01-ui-overhaul-design.md` (sections Visual language, Screens, Architecture). This plan covers build step 1.

**Note on code listings:** view code is visual and is tuned against playtest screenshots, so this plan fixes interfaces, tests and acceptance checks rather than listing every line of GUI construction. Pure functions and tests are specified exactly.

## Global Constraints

- Client-only; no server, Engine or Protocol changes. `--!strict`, tabs, short "why" comments.
- `HudView` public API unchanged: `new(playerGui, callbacks)`, `render(snapshot, localId)`, `showCard`, `log`, `notice`, `send`, `unlock`; add `destroy`.
- Button texts from `HudModel` unchanged; lobby setting buttons keep `MatchSettings.*Label` texts; the Start button keeps the text `Start game`; seat buttons keep `-` and `+`.
- ScreenGui stays named `MonopolyHud`; the action bar's button container stays `ActionBar.Buttons`.
- Tokens exactly as in the spec's Visual language table. Design canvas 1280 × 720; scale `clamp(min(w/1280, h/720), 0.55, 1.3)`; narrow when `w / scale < 900`.
- All 320 existing tests keep passing. Tests run through the Studio `RunTests` workspace-attribute hook.
- Never switch git branches to one with different files while Rojo is connected.

## Review Focus

1. Clicks: a re-render must not swallow a click or reset scroll (Properties and Trade rebuild only when their key changes; action buttons are rebuilt on every render as today). Smoke test: rendering the same snapshot twice keeps the same Properties row instances.
2. Back to lobby (nil snapshot) hides every in-game screen and clears the log, queued cards, trade draft and toasts. Smoke test.
3. A spectator / bot-held seat sees no action buttons and no crash in any phase. Smoke test with a `localId` not in the game.
4. Long names (20-character Roblox names, "North Carolina Avenue") truncate instead of overflowing rows. Playtest check.
5. Player names containing rich-text characters (`<`, `&`) are shown literally in the log. `LogFormat` test.

---

### Task 1: Theme and Layout

**Files:** Create `src/client/Hud/Theme.luau`, `src/client/Hud/Layout.luau`; Test `src/tests/HudLayout.spec.luau`.

**Produces:**
- `Theme` table: `Theme.color.{panel, surface, stroke, accent, primary, primaryLip, secondary, secondaryLip, danger, dangerLip, text, textDim, moneyUp, moneyDown, paper, ink, shadow}` (Color3), `Theme.font.{display, body, bodyBold}` (Font), `Theme.radius.{panel=14, surface=10, pill=8}`, `Theme.space.{xs=4, s=8, m=12, l=16}`, `Theme.time.{fast=0.12, pop=0.2, slow=0.35}`, `Theme.textSize.{title=30, heading=22, body=17, small=14}`.
- `Layout.CANVAS = Vector2.new(1280, 720)`, `Layout.scale(viewport: Vector2): number`, `Layout.isNarrow(viewport: Vector2): boolean`, `Layout.bottomInset(barHeight: number, margin: number, scale: number, viewportHeight: number): number` (= `clamp((barHeight + margin) * scale / viewportHeight, 0, 0.4)`; 0 when the viewport height is 0).

- [ ] Step 1: write `HudLayout.spec` — scale is 1 at 1280×720, 1.3 cap at 4K, 0.55 floor on a 390×844 phone, limited by the smaller axis (1736×793 → 793/720); narrow for 390×844, not for 1280×720 or 844×390; bottomInset (112 px bar+margin at scale 1 on 720) ≈ 0.1556, clamps at 0.4, 0 for a zero-height viewport.
- [ ] Step 2: run `HudLayout` → fails to load (module missing).
- [ ] Step 3: implement both modules.
- [ ] Step 4: run `HudLayout` then all → green.
- [ ] Step 5: commit `feat: HUD theme tokens and layout scaling`.

### Task 2: Ui widget kit

**Files:** Create `src/client/Hud/Ui.luau`; Test `src/tests/HudUi.spec.luau`.

**Consumes:** `Theme`.

**Produces:**
- `Ui.panel(name, size, position, anchor, parent): Frame` — navy panel with corner, stroke, shadow.
- `Ui.surface(name, size, parent): Frame` — raised surface.
- `Ui.label(name, parent, size, textSize, font?): TextLabel` — transparent, wrapped, `Theme.color.text`.
- `Ui.button(text, parent, onClick, style?: "primary" | "secondary" | "danger" | "accent"): TextButton` — the TextButton is the clickable face, named by its text, with a child `Lip`; default size 150 × 44; hover lifts, press sinks. Returns the TextButton so callers can set `Size`, `LayoutOrder`, `Text`.
- `Ui.setStyle(button, style)` — recolours an existing button.
- `Ui.pill(text, parent, color, textColor?): TextLabel`, `Ui.dot(parent, color, diameter): Frame`.
- `Ui.list(parent, direction, padding, horizontal?, vertical?): UIListLayout`, `Ui.padding(parent, all | {top,bottom,left,right})`, `Ui.corner(parent, radius?)`, `Ui.stroke(parent, color?, thickness?, transparency?)`.
- `Ui.show(frame)`, `Ui.hide(frame)` — set `Visible` (show pops the frame's `UIScale` 0.92 → 1; hide is immediate so a hidden panel never eats clicks), `Ui.clear(parent, keep?: (Instance) -> boolean)` — destroys children that aren't layout/decoration objects.

- [ ] Step 1: write `HudUi.spec` — a button is a TextButton named and labelled by its text, has a `Lip`, and its callback fires on `Activated` (fire with `button.Activated:Fire()` is not possible; call through the test seam `Ui.press(button)` which runs the same handler); `setStyle` changes face and lip colours to the theme's; `show`/`hide` toggle `Visible`; `clear` leaves `UIListLayout`/`UICorner`/`UIStroke`/`UIPadding`/`UIScale` and the `Shadow` in place and removes the rest; `pill` text and colour.
- [ ] Step 2: run → fails to load.
- [ ] Step 3: implement.
- [ ] Step 4: run `HudUi` then all → green.
- [ ] Step 5: commit `feat: HUD widget kit`.

### Task 3: Player rows and rich log lines

**Files:** Modify `src/client/Hud/HudModel.luau`; Create `src/client/Hud/LogFormat.luau`; Test `src/tests/HudModel.spec.luau` (append), `src/tests/LogFormat.spec.luau`.

**Produces:**
- `export type PlayerRow = { id: string, name: string, seat: number, money: number, bankrupt: boolean, inJail: boolean, isYou: boolean, isCurrent: boolean, deeds: number }`; `HudModel.playerRows(snapshot, localId): { PlayerRow }` in seat order.
- `LogFormat.escape(text): string` (`&`, `<`, `>`, `"`, `'`), `LogFormat.rich(line: string, players: { { name: string, seat: number } }): string` — escaped line with each player name wrapped in `<font color="#rrggbb">…</font>` using `TokenLayout.SEAT_COLORS`; longer names are matched first so "Bot 1" inside "Bot 10" isn't split.

- [ ] Step 1: tests — playerRows: seat order, `isYou`, `isCurrent`, deed counts, bankrupt/jail flags, a spectator id marks nobody as you. LogFormat: a name is coloured with its seat colour's hex; `<b>` in a name appears as `&lt;b&gt;`; "Bot 10" is coloured as one name when "Bot 1" also plays; a line with no names is only escaped.
- [ ] Step 2: run `HudModel`, `LogFormat` → fail (nil function / missing module).
- [ ] Step 3: implement.
- [ ] Step 4: run both then all → green.
- [ ] Step 5: commit `feat: player rows and seat-coloured log lines`.

### Task 4: Views and the HudView coordinator

**Files:** Create `src/client/Hud/Views/{Lobby,PlayerList,ActionBar,LogFeed,Toasts,Results,PropertiesPanel,TradeWindow,OfferCard}.luau`; Rewrite `src/client/Hud/HudView.luau`; Test `src/tests/HudView.spec.luau` (append smoke tests; keep the existing `send` test).

**Consumes:** Tasks 1–3; existing `HudModel`, `TradeBuilder`, `CardQueue`, `MatchSettings`.

**Produces (view interfaces; each `new` builds once, hidden unless stated):**
- `Lobby.new(parent, onStart: (seats, settings) -> ())` → `{ frame, seats, settings }`; visible by default.
- `PlayerList.new(parent)`; `PlayerList.render(self, rows: { HudModel.PlayerRow }, matchLine: string?)`; `PlayerList.setMatchLine(self, line: string?)`.
- `ActionBar.new(parent)` → `{ frame, buttons: Frame (named "Buttons"), status: TextLabel }`; `ActionBar.setStatus(self, text, color)`; `ActionBar.setButtons(self, entries: { { label: string, style: string, width: number?, onClick: (TextButton) -> () } })`.
- `LogFeed.new(parent)`; `LogFeed.push(self, richLines: { string })`; `LogFeed.clear(self)`.
- `Toasts.new(parent)`; `Toasts.show(self, message)`; `Toasts.clear(self)`.
- `Results.new(parent, onBack)`; `Results.render(self, title: string?, standings: { HudModel.Standing })` (nil title hides).
- `PropertiesPanel.new(parent, send: (action) -> ())`; `PropertiesPanel.render(self, open, rows, emptyText)` — rebuilds only when its key changes.
- `TradeWindow.new(parent, hooks: { send: (action) -> boolean, close: () -> (), changed: () -> () })`; `TradeWindow.render(self, open, snapshot, localId, builder)` — rebuilds only when its key changes.
- `OfferCard.new(parent)`; `OfferCard.render(self, summary: { give: string, get: string }?)`.
- `HudView` fields used by tests: `gui`, `lobby` (the Lobby view), `actionBar`, `results`, `propertiesPanel`, `tradeWindow`, `offerCard`, `toasts`, `logFeed`, `playerList`. `HudView.destroy(self)` disconnects the heartbeat and destroys the gui. The drawn-card popup keeps today's behaviour, restyled, until plan 2 replaces it.

- [ ] Step 1: append smoke tests to `HudView.spec` using `Snapshot.fromState(GameFixtures.newGame(n))` and `Engine`/fixture helpers to reach each phase: lobby (nil) shows the lobby with `Start game`, `-`, `+` and three setting buttons; Roll shows `Roll dice`, `Properties`, `Trade`; BuyDecision shows `Buy for $60` and `Don't buy`; Auction shows bid buttons and no `Properties`; Debt shows `Pay $…` or `Go bankrupt`; Trade (receiver) shows `Accept`/`Decline` and the offer card; GameOver shows results and no action buttons; nil again hides all in-game frames and clears the log; a spectator id renders every phase with no action buttons; rendering twice keeps the same Properties rows; `notice` shows a toast and does not add a log line. Each test destroys its HUD.
- [ ] Step 2: run `HudView` → new tests fail (fields missing).
- [ ] Step 3: implement views and coordinator.
- [ ] Step 4: run `HudView` then all → green.
- [ ] Step 5: playtest screenshots: lobby, Roll, BuyDecision, Auction, Properties open, Trade window, incoming offer (bots propose), GameOver if reachable; check nothing overlaps the board or another panel at the Studio viewport and long names truncate.
- [ ] Step 6: commit `feat: restyled HUD split into per-screen views`.

### Task 5: Scaling and board clearance

**Files:** Modify `src/client/Hud/HudView.luau` (UIScale + `BottomInset` attribute + narrow mode), `src/client/CameraDirector.luau`; Test `src/tests/HudView.spec.luau`, `src/tests/CameraDirector.spec.luau`.

**Produces:** `HudView.applyViewport(self, viewport: Vector2)` — sets the root `UIScale`, hides the log in narrow mode, sets `gui:SetAttribute("BottomInset", Layout.bottomInset(...))`. `CameraDirector.insetFrom(playerGui: Instance?): number` — the HUD's `BottomInset` attribute if present and a number in [0, 0.4], else 0.16.

- [ ] Step 1: tests — `applyViewport(1280×720)` scale 1 and log visible; `(390×844)` scale 0.55 and log hidden; `BottomInset` set and within (0, 0.4]. `insetFrom(nil)` = 0.16; a folder with a `MonopolyHud` child whose attribute is 0.25 → 0.25; attribute 5 or a string → 0.16.
- [ ] Step 2: run → fail.
- [ ] Step 3: implement; `HudView.new` calls `applyViewport` with the camera's viewport and again when it changes; the director's overhead uses `insetFrom(LocalPlayer.PlayerGui)`.
- [ ] Step 4: run all → green.
- [ ] Step 5: playtest: overhead board clears the bar; screenshot.
- [ ] Step 6: commit `feat: HUD scales to the viewport and tells the camera how much the action bar covers`.
