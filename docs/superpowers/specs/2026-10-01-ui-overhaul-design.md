# UI Overhaul — Design

Date: 2026-10-01. The user asked for "the best UI throughout the game … a top Roblox game", with a better trading UI and a proper card on screen every time a card is drawn, and delegated the design decisions ("take this on your own"). Models (Blender) are a separate, later project.

## Intent

Every screen of the game looks like one finished product: one visual language, motion that explains what just happened, and the three moments that matter most in this game — drawing a card, deciding to buy, and trading — get real, readable, satisfying screens. Rules, server and protocol do not change.

Success: a new player can tell at a glance whose turn it is, what they can do, what a property costs and earns, and what a trade offers; a drawn card is an event, not a text box; nothing overlaps the board's playable area or each other at 16:9, and the HUD stays usable on a phone.

## Constraints

- Client-only. No server, Engine or Protocol changes. `HudModel`, `TradeBuilder`, `CardQueue`, `EventText` keep their existing functions and tests; new pure functions are added beside them.
- `HudView` keeps its public API (`new`, `render`, `showCard`, `log`, `notice`, `send`, `unlock`), so `GameClient` barely changes. `showCard` gains the card id and drawer.
- Built in code (no Studio-authored GUI), no uploaded image or sound assets: shapes come from frames, corners, strokes and gradients; fonts from Roblox's built-in families. Sounds are out of scope (they need uploaded assets) and noted for later.
- `--!strict`, tabs, short "why" comments, existing module patterns. All 320 tests keep passing.
- Button texts produced by `HudModel` stay as they are (tests and tooling rely on them).

## Visual language — "Boardwalk at night"

| Token | Value |
|---|---|
| Panel | deep navy `#141A2A`, 6% transparent, radius 14, 1.5 px white stroke at 88% transparency, soft offset shadow |
| Raised surface | `#1E2740`, radius 10 |
| Accent | gold `#F5C542` (your turn, selection, winner) |
| Primary action | green `#2FBF71` (lip `#1F8A50`) |
| Secondary action | slate `#3A4666` (lip `#283250`) |
| Danger | red `#E5484D` (lip `#A8302F`) |
| Text | `#F4F6FB`; dim `#9AA6C4`; money up `#7EE2A8`; money down `#FF8B8B` |
| Paper (cards, deeds) | cream `#FBF6E9`, ink `#1B1F2A` |
| Display font | Fredoka One: titles, buttons, money |
| Body font | Builder Sans (Medium / Bold): everything else |
| Spacing | 4 / 8 / 12 / 16 |

Buttons are chunky and tactile: a coloured face on a darker lip, lifting 1 px on hover and sinking onto the lip when pressed. Panels pop in (scale 0.92 → 1, fade) and out. Motion is short (0.12–0.35 s) and never blocks input.

**Scaling.** The HUD is designed on a 1280 × 720 canvas and a single `UIScale` on the ScreenGui fits it to the viewport: `clamp(min(w / 1280, h / 720), 0.55, 1.3)`. When the scaled width is under 900 design pixels (portrait phones) the HUD is in **narrow** mode: the log is hidden, the player list shows compact rows, and centre windows take the full width.

**Board clearance.** The HUD publishes the share of the screen its action bar covers as a `BottomInset` attribute on the ScreenGui; `CameraDirector` reads it for the overhead fit instead of the fixed 0.16 (closes a followup: the bar hid the bottom row on short screens).

## Screens

**Lobby.** Centre card: game title, a players stepper with six seat-coloured dots (filled up to the chosen count), three setting rows (Timer, Length, Map — click to cycle, as today), and a large Start button.

**Player list (top left).** One row per player: seat-colour token dot, name, a `YOU` pill, a `JAIL` pill, deed count, money right-aligned. The current player's row is raised with a gold bar. Bankrupt rows are dimmed. Money counts up or down over 0.4 s and a `+$200` / `−$50` floater drifts off the row. The match line (timer preset, round or time left) sits under the rows.

**Action bar (bottom centre).** Status text; two drawn dice that tumble when a roll arrives; a thin timer bar across the bar's top edge that drains with the turn deadline and turns red in the last 5 s (the countdown text stays). The first action is the primary (green) button, the rest are secondary, confirm-style actions are red; Properties and Trade toggles sit at the right.

**Turn banner.** When the turn becomes yours, a gold "YOUR TURN" banner sweeps in under the top edge for about 1.2 s.

**Card reveal.** Every drawn card — yours or anyone's — is shown centre screen: the card appears face down in its deck colour with the deck title, flips, and shows a cream face with the deck title band, "<name> drew", the card text, and an **effect badge** (`+$50`, `−$15`, `→ Boardwalk`, `← 3 spaces`, `Keep this card`, …) coloured good / bad / neutral. It holds, then shrinks away; clicking it dismisses it early. Cards still queue one at a time and never appear before the token reaches the tile.

**Deed card.** During a buy decision and during an auction, the property in question is shown as a deed: colour band and name, price, the rent table (base, full set, 1–4 houses, hotel; railroads by number owned; utilities by dice multiplier), house cost and mortgage value. In the auction it also shows the high bid and bidder. Clicking a property's name in the Properties panel shows its deed too, with the rent line that currently applies highlighted.

**Properties panel (right).** Deeds grouped by colour set with a header per set showing how much of the set you own (`2/3`); each row has the colour bar, name, drawn house/hotel pips, a `MORTGAGED` tag and its action buttons.

**Trade window.** A centre window: partner pills across the top; two columns ("You give" / "You get"), each headed by the player's token dot, name and cash; deeds as selectable chips with their colour band (selected = gold outline and tick; untradable = dim, with the reason); a large cash amount with stepper buttons; a jail-card stepper when the player has any; a footer with the reason it can't be sent, Cancel and Send offer.

**Offer card.** While an offer is waiting, everyone sees it above the action bar as two columns of chips with cash and jail cards, titled from their point of view ("Ana offers you a trade" / "Ana offers Bot 1 a trade"). Accept / Decline stay in the action bar for the receiver.

**Log (top right).** The last 8 lines, newest at the bottom and brightest, with player names in their seat colours.

**Toasts.** A refused action's reason appears as a red-edged toast above the action bar for 3 s instead of as a log line.

**Results.** Centre card with the winner line, ranked rows (gold / silver / bronze rank badges, net worth, `Bankrupt`), a short burst of confetti, and Back to lobby.

## Architecture

`HudView` becomes a thin coordinator; each screen is its own module that builds its instances once and has a `render`/`show` function. Shared look lives in two modules.

- `Hud/Theme.luau` — colours, fonts, radii, spacing, durations. No logic.
- `Hud/Ui.luau` — widget kit: `panel`, `surface`, `label`, `button` (face + lip, hover/press), `pill`, `dot`, `list`, `padding`, `show`/`hide` (pop tween), `countTo` (number tween). Every widget takes its style from `Theme`.
- `Hud/Layout.luau` (pure) — `scale(viewport)`, `isNarrow(viewport)`, `bottomInset(barHeight, margin, scale, viewportHeight)`.
- `Hud/Views/` — `Lobby`, `PlayerList`, `ActionBar`, `Dice`, `TurnBanner`, `CardReveal`, `DeedCard`, `PropertiesPanel`, `TradeWindow`, `OfferCard`, `LogFeed`, `Toasts`, `Results`. Each: `X.new(parent, …callbacks)` and `X.render(self, …)`; none requires another view.
- Pure additions (unit-tested):
  - `HudModel.playerRows(snapshot, localId)`, `HudModel.moneyDeltas(previous, next)`, `HudModel.timerFraction(snapshot, now)`, `HudModel.propertyGroups(rows)`, `HudModel.tradeOffer(snapshot, localId)`, `HudModel.becameMyTurn(previous, next, localId)`.
  - `Hud/CardFace.luau` — `CardFace.of(cardId, drawerName)` → `{ deck, title, drawer, text, badge = { text, tone } }`.
  - `Hud/DeedModel.luau` — `DeedModel.of(position, snapshot?)` → name, colour, price, rent lines (with the applicable one flagged), house cost, mortgage value. Railroad and utility rent figures mirror the server's `Rent` constants; a test pins them equal.
  - `Hud/LogFormat.luau` — `LogFormat.rich(line, players)`: escapes rich-text characters and colours player names.
  - `CardQueue.dismiss(queue, now)`; queue items carry the card face.
  - `Dice.pips(value)` — pip positions for a face.
- `HudView.destroy` disconnects its heartbeat so tests can build and tear down a whole HUD.

Data flow is unchanged: `GameClient` → `hud:render(snapshot, localId)`; views read only what `HudView` hands them. `HudView` keeps the previous snapshot to derive deltas (money, turn start).

## Testing

- Unit tests for every pure addition above.
- `HudView.spec` smoke tests: build the whole HUD in a scratch folder and render fixture snapshots for the lobby and each phase (Roll, BuyDecision, Auction, Debt, Trade, GameOver); assert no errors, the expected action buttons exist by text, the deed card shows in BuyDecision/Auction, the offer card in Trade, results in GameOver, and that returning to the lobby hides everything.
- Playtest screenshots of every screen at the Studio viewport, plus the narrow layout.

## Build order (one plan each)

1. **Foundation** — Theme, Ui kit, Layout/scaling, HudView split into views with every existing screen restyled (same information as today), smoke tests, `BottomInset` → camera, toasts, rich log.
2. **Cards, deeds, dice** — card reveal with flip and effect badge, deed card, drawn dice.
3. **Trade and properties** — trade window chips, offer card for everyone, grouped properties panel.
4. **Juice** — turn banner, money count-up and floaters, timer bar, results with confetti.

## Out of scope

Sounds and music, image icons, 3D models and board dressing (the Blender project), settings/menus that don't exist yet, any rules change.
